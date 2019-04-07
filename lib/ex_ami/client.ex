defmodule ExAmi.Client do
  use GenStateMachine, callback_mode: :state_functions
  use ExAmi.Logger

  import GenStateMachineHelpers

  alias ExAmi.ServerConfig

  defmodule ClientState do
    defstruct name: "",
              server_info: "",
              listeners: [],
              actions: %{},
              connection: nil,
              counter: 0,
              logging: false,
              worker_name: nil,
              reader: nil,
              online: false
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

  def online?(pid) when is_pid(pid) do
    GenStateMachine.call(pid, :online)
  end

  def online?(client) do
    GenStateMachine.call(get_worker_name(client), :online)
  end

  def process_salutation(client, salutation) do
    GenStateMachine.cast(client, {:salutation, salutation})
  end

  def process_response(client, {:response, response}) do
    GenStateMachine.cast(client, {:response, response})
  end

  def process_event(client, {:event, event}) do
    GenStateMachine.cast(client, {:event, event})
  end

  def socket_close(client) do
    Logger.debug(fn -> "socket_close client: " <> inspect(client) end)
    GenStateMachine.call(client, :socket_close)
  end

  def restart!(pid) when is_pid(pid) do
    GenStateMachine.cast(pid, :restart)
  end

  def restart!(client) do
    GenStateMachine.cast(get_worker_name(client), :restart)
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
    |> Module.split()
    |> Enum.join("_")
    |> String.downcase()
    |> String.to_atom()
  end

  def send_action(pid, action, callback) when is_pid(pid), do: _send_action(pid, action, callback)

  def send_action(client, action, callback),
    do: _send_action(get_worker_name(client), action, callback)

  defp _send_action(client, action, callback),
    do: GenStateMachine.cast(client, {:action, action, callback})

  def status(pid) when is_pid(pid), do: GenStateMachine.call(pid, :status)

  def status(client), do: GenStateMachine.call(get_worker_name(client), :status)

  def stop(pid), do: GenStateMachine.cast(pid, :stop)

  ###################
  # Callbacks

  def init([server_name, worker_name, server_info]) do
    # :erlang.process_flag(:trap_exit, true)

    logging = ServerConfig.get(server_info, :logging) || false

    send(self(), {:timeout, :connecting, 0, ServerConfig.get(server_info, :connection)})

    {:ok, :connecting,
     %ClientState{
       name: server_name,
       server_info: server_info,
       worker_name: worker_name,
       logging: logging
     }}
  end

  ###################
  # States

  def connecting(
        _event_type,
        {:timeout, :connecting, cnt, {conn_module, conn_options}} = ev,
        data
      ) do
    case :erlang.apply(conn_module, :open, [conn_options]) do
      {:ok, conn} ->
        reader = ExAmi.Reader.start_link(data.worker_name, conn)

        next_state(
          %ClientState{data | connection: conn, reader: reader, online: true},
          :wait_saluation
        )

      _error ->
        Process.send_after(self(), put_elem(ev, 2, cnt + 1), connecting_timer(cnt))
        next_state(%ClientState{data | online: false}, :connecting)
    end
  end

  def connecting(event_type, event_content, data) do
    handle_event(event_type, event_content, data)
  end

  def wait_saluation(:cast, {:salutation, salutation}, state) do
    :ok = validate_salutation(salutation)
    username = ServerConfig.get(state.server_info, :username)
    secret = ServerConfig.get(state.server_info, :secret)
    action = ExAmi.Message.new_action("Login", [{"Username", username}, {"Secret", secret}])

    :ok = state.connection.send.(action)

    next_state(state, :wait_login_response)
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
        next_state(state, :receiving)
    end
  end

  def wait_login_response(event_type, event_content, data) do
    handle_event(event_type, event_content, data)
  end

  def receiving(:cast, {:response, response}, %ClientState{actions: actions} = state) do
    # Logger.info "response: " <> inspect(response)
    pong = response.attributes["Ping"] == "Pong"
    if state.logging and !pong, do: Logger.debug(ExAmi.Message.format_log(response))

    # Find the correct action information for this response
    {:ok, action_id} = ExAmi.Message.get(response, "ActionID")
    {action, :none, events, callback} = Map.fetch!(actions, action_id)

    # See if we should dispatch this right away or wait for the events needed
    # to complete the response.
    new_actions =
      cond do
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

    state
    |> struct(actions: new_actions)
    |> next_state(:receiving)
  end

  def receiving(:cast, {:event, event}, %ClientState{actions: actions} = state) do
    case ExAmi.Message.get(event, "ActionID") do
      :notfound ->
        # async event
        dispatch_event(state.name, event, state.listeners)
        next_state(state, :receiving)

      {:ok, action_id} ->
        # this one belongs to a response
        case Map.get(actions, action_id) do
          nil ->
            # ignore: not ours, or stale.
            next_state(state, :receiving)

          {action, response, events, callback} ->
            new_events = [event | events]

            new_actions =
              case ExAmi.Message.is_event_last_for_response(event) do
                false ->
                  Map.put(actions, action_id, {action, response, new_events, callback})

                true ->
                  if callback, do: callback.(response, Enum.reverse(new_events))
                  Map.delete(state.actions, action_id)
              end

            state
            |> struct(actions: new_actions)
            |> next_state(:receiving)
        end
    end
  end

  def receiving(:cast, {:action, action, callback}, state) do
    {:ok, action_id} = ExAmi.Message.get(action, "ActionID")

    new_state =
      struct(state, actions: Map.put(state.actions, action_id, {action, :none, [], callback}))

    :ok = state.connection.send.(action)
    next_state(new_state, :receiving)
  end

  def receiving(event_type, event_content, data) do
    handle_event(event_type, event_content, data)
  end

  def handle_event(
        :cast,
        {:register, listener_descriptor},
        %ClientState{listeners: listeners} = client_state
      ) do
    # ignore duplicate entries
    if listener_descriptor in listeners do
      client_state
    else
      struct(client_state, listeners: [listener_descriptor | listeners])
    end
    |> keep_state
  end

  def handle_event(:cast, :restart, %{reader: reader} = state) do
    send(reader, :stop)
    {:stop, :restart, state}
  end

  def handle_event(:cast, :stop, %{reader: reader} = state) do
    send(reader, :stop)
    # Give reader a chance to timeout, receive the :stop, and shutdown
    Process.sleep(100)
    ExAmi.Supervisor.stop_child(self())
    {:stop, :normal, state}
  end

  def handle_event({:call, from}, :next_worker, %{name: name} = state) do
    next = state.counter + 1
    new_worker_name = String.to_atom("#{get_worker_name(name)}_#{next}")

    state
    |> struct(counter: next)
    |> keep_state([{:reply, from, [name, new_worker_name, state.server_info]}])
  end

  def handle_event({:call, from}, :socket_close, state) do
    dispatch_event(state.name, "Shutdown", state.listeners)
    keep_state(state, [{:reply, from, :ok}])
  end

  def handle_event({:call, from}, :online, state) do
    keep_state(state, [{:reply, from, state.online}])
  end

  def handle_event({:call, from}, :status, state) do
    keep_state(state, [{:reply, from, state}])
  end

  def handle_event(_ev, _evd, data) do
    keep_state(data)
  end

  ###################
  # Private Internal

  defp connecting_timer(cnt) when cnt < 5, do: 2_000
  defp connecting_timer(cnt) when cnt < 10, do: 10_000
  defp connecting_timer(cnt) when cnt < 20, do: 30_000
  defp connecting_timer(_), do: 60_000

  defp validate_salutation("Asterisk Call Manager/1.1\r\n"), do: :ok
  defp validate_salutation("Asterisk Call Manager/1.0\r\n"), do: :ok
  defp validate_salutation("Asterisk Call Manager/1.2\r\n"), do: :ok
  defp validate_salutation("Asterisk Call Manager/1.3\r\n"), do: :ok

  defp validate_salutation(saluation = "Asterisk Call Manager/2.10." <> minor) do
    if Regex.match?(~r/\d+\r\n/, minor) do
      :ok
    else
      saluation_error(saluation)
    end
  end

  defp validate_salutation(invalid_id) do
    saluation_error(invalid_id)
  end

  defp saluation_error(invalid_id) do
    Logger.error("Invalid Salutation #{inspect(invalid_id)}")
    :unknown_salutation
  end

  defp dispatch_event(server_name, event, listeners) do
    Enum.each(listeners, fn
      {function, predicate} when predicate in [false, nil, :none] ->
        apply_fun(function, [server_name, event])

      {function, predicate} ->
        case apply_fun(predicate, [event]) do
          true -> apply_fun(function, [server_name, event])
          _ -> :ok
        end
    end)
  end

  def apply_fun({mod, fun}, args) do
    apply(mod, fun, args)
  end

  def apply_fun(fun, args) when is_function(fun, 1) do
    fun.(hd(args))
  end

  def apply_fun(fun, args) when is_function(fun, 2) do
    [arg1, arg2] = args
    fun.(arg1, arg2)
  end

  def apply_fun(fun, args) do
    Logger.error("Invalid function #{inspect(fun)} with args: #{inspect(args)}")
    false
  end
end
