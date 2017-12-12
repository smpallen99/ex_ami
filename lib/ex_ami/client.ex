defmodule ExAmi.Client do

  use GenStateMachine, callback_mode: :state_functions

  import GenStateMachineHelpers

  alias ExAmi.ServerConfig

  require Logger

  defmodule ClientState do
    defstruct name: "", server_info: "", listeners: [], actions: %{},
              connection: nil, counter: 0, logging: false, worker_name: nil,
              reader: nil
  end

  ###################
  # API

  def start_link(server_name, worker_name, server_info) do
    do_start_link([server_name, worker_name, server_info])
  end

  def start_link(server_name) do
    server_name
    |> get_worker_name
    |> GenStateMachine.call(:next_worker)
    |> do_start_link
  end

  defp do_start_link([_, worker_name | _] = args) do
    GenStateMachine.start_link(__MODULE__, args, name: worker_name)
  end

  def start_child(server_name) do
    # have the supervisor start the new process
    ExAmi.Supervisor.start_child(server_name)
  end

  def process_salutation(client, salutation) do
    GenStateMachine.cast(client, {:salutation, salutation})
  end

  def process_response(client, {:response, response}) do
    # IO.inspect {:response, response}
    GenStateMachine.cast(client, {:response, response})
  end

  def process_event(client, {:event, event}) do
    # IO.inspect {:event, event}
    GenStateMachine.cast(client, {:event, event})
  end

  def register_listener(pid, listener_descriptor) when is_pid(pid),
    do: do_register_listener(pid, listener_descriptor)
  def register_listener(client, listener_descriptor),
    do: do_register_listener(get_worker_name(client), listener_descriptor)
  defp do_register_listener(client, listener_descriptor),
    do: GenStateMachine.cast(client, {:register, listener_descriptor})

  def get_worker_name(server_name) do
    __MODULE__
    |> Module.concat(server_name)
    |> Module.split
    |> Enum.join("_")
    |> String.downcase
    |> String.to_atom
  end

  def send_action(pid, action, callback) when is_pid(pid),
    do: _send_action(pid, action, callback)
  def send_action(client, action, callback),
    do: _send_action(get_worker_name(client), action, callback)
  defp _send_action(client, action, callback),
    do: GenStateMachine.cast(client, {:action, action, callback})

  def stop(pid), do: GenStateMachine.cast(pid, :stop)

  ###################
  # Callbacks

  def init([server_name, worker_name, server_info]) do
    logging = ServerConfig.get(server_info, :logging) || false
    {conn_module, conn_options} = ServerConfig.get server_info, :connection
    {:ok, conn} = :erlang.apply(conn_module, :open, [conn_options])
    reader = ExAmi.Reader.start_link(worker_name, conn)

    {:ok, :wait_saluation,
      %ClientState{
        name: server_name, server_info: server_info, connection: conn,
        worker_name: worker_name, reader: reader, logging: logging
      }}
  end

  ###################
  # States

  def wait_saluation(:cast, {:salutation, salutation}, state) do
    :ok =  validate_salutation(salutation)
    username = ServerConfig.get state.server_info, :username
    secret = ServerConfig.get state.server_info, :secret
    action = ExAmi.Message.new_action("Login", [{"Username", username},
      {"Secret", secret}])
    :ok = state.connection.send.(action)
    next_state state, :wait_login_response
  end

  def wait_saluation(event_type, event_content, data) do
    handle_event(event_type, event_content, data)
  end

  def wait_login_response(:cast, {:response, response}, state) do
    case ExAmi.Message.is_response_success(response) do
      false ->
        :error_logger.error_msg('Cant login: ~p', [response])
        :erlang.error(:cantlogin)
      true ->
        next_state state, :receiving
    end
  end

  def wait_login_response(event_type, event_content, data) do
    handle_event(event_type, event_content, data)
  end

  def receiving(:cast, {:response, response}, %ClientState{actions: actions} = state) do
    if state.logging, do: Logger.debug(ExAmi.Message.format_log(response))

    # Find the correct action information for this response
    {:ok, action_id} = ExAmi.Message.get(response, "ActionID")
    {action, :none, events, callback} = Map.fetch!(actions, action_id)

    # See if we should dispatch this right away or wait for the events needed
    # to complete the response.
    new_actions = cond do
      ExAmi.Message.is_response_error(response) ->
        if callback, do: callback.(response, events)
        actions

      ExAmi.Message.is_response_complete(response) ->
        # Complete response. Dispatch and remove the action from the queue.
        if callback, do: callback.(response, events)
        Map.delete(actions, action_id)

      true ->
        # Save the response so we can receive the associated events to
        # dispatch later.
        Map.put(actions, action_id, {action, response, [], callback})
    end
    struct(state, actions: new_actions)
    |> next_state(:receiving)
  end

  def receiving(:cast, {:event, event}, %ClientState{actions: actions} = state) do
    # IO.inspect event, label: "----------- event"
    case ExAmi.Message.get(event, "ActionID") do
      :notfound ->
        # async event
        dispatch_event(state.name, event, state.listeners)
        next_state state, :receiving
      {:ok, action_id} ->
        # this one belongs to a response
        # IO.inspect {action_id, actions}, label: "^^^^^^^^^^"
        case Map.get(actions, action_id) do
          nil ->
            # IO.insect event, label: "--------- action id not found"
            # ignore: not ours, or stale.
            next_state state, :receiving
          {action, response, events, callback} ->
            # IO.inspect({event, action, response, events}, label: "============ event")
            new_events = [event|events]
            new_actions = case ExAmi.Message.is_event_last_for_response(event) do
              false ->
                # IO.inspect "+++++++= not the end, saving event"
                Map.put(actions, action_id, {action, response, new_events, callback})
              true ->
                # IO.inspect "+++++++= the end, calling callback: #{inspect callback}"
                if callback, do: callback.(response, Enum.reverse(new_events))
                Map.delete state.actions, action_id
            end
            struct(state, actions: new_actions)
            |> next_state(:receiving)
        end
    end
  end

  def receiving(:cast, {:action, action, callback}, state) do
    {:ok, action_id} = ExAmi.Message.get(action, "ActionID")
    new_state = struct(state,
      actions: Map.put(state.actions, action_id, {action, :none, [], callback}))
    :ok = state.connection.send.(action)
    next_state new_state, :receiving
  end

  def receiving(event_type, event_content, data) do
    handle_event(event_type, event_content, data)
  end

  def handle_event(:cast, {:register, listener_descriptor},
      %ClientState{listeners: listeners} = client_state) do
    struct(client_state, listeners: [listener_descriptor | listeners])
    |> keep_state
  end

  def handle_event(:cast, :stop, %{reader: reader} = state) do
    send reader, :stop
    # Give reader a chance to timeout, receive the :stop, and shutdown
    :timer.sleep(100)
    ExAmi.Supervisor.stop_child(self())
    {:stop, :normal, state}
  end

  def handle_event({:call, from}, :next_worker, %{name: name} = state) do
    next = state.counter + 1
    new_worker_name = String.to_atom "#{get_worker_name(name)}_#{next}"

    state
    |> struct(counter: next)
    |> keep_state([{:reply, from, [name, new_worker_name, state.server_info]}])
  end

  def handle_event(_, _, data) do
    keep_state data
  end

  ###################
  # Private Internal

  defp validate_salutation("Asterisk Call Manager/1.1\r\n"), do: :ok
  defp validate_salutation("Asterisk Call Manager/1.0\r\n"), do: :ok
  defp validate_salutation("Asterisk Call Manager/1.2\r\n"), do: :ok
  defp validate_salutation("Asterisk Call Manager/1.3\r\n"), do: :ok
  defp validate_salutation("Asterisk Call Manager/2.10.2\r\n"), do: :ok
  defp validate_salutation(invalid_id) do
    Logger.error "Invalid Salutation #{inspect invalid_id}"
    :unknown_salutation
  end

  defp dispatch_event(server_name, event, listeners) do
    Enum.each(listeners,
      fn({function, predicate}) ->
        case :erlang.apply(predicate, [event]) do
          true -> function.(server_name, event)
          _ -> :ok
        end
      end)
  end
end
