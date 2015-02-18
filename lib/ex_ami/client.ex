defmodule ExAmi.Client do

  use GenFSM
  require Logger
  alias ExAmi.ServerConfig

  defmodule ClientState do
    defstruct name: "", server_info: "", listeners: [], actions: HashDict.new, 
              connection: nil, counter: 0, logging: false, worker_name: nil, 
              reader: nil
  end 

  ###################
  # API

  def start_link(server_name, worker_name, server_info), 
    do: _start_link([server_name, worker_name, server_info])

  def start_link(server_name) do
    :gen_fsm.sync_send_all_state_event(get_worker_name(server_name), :next_worker)
    |> _start_link
  end

  defp _start_link([_, worker_name | _] = args) do
    :gen_fsm.start_link({:local, worker_name}, __MODULE__, args, [])
  end

  def start_child(server_name) do
    # have the supervisor start the new process
    ExAmi.Supervisor.start_child(server_name)
  end

  def process_salutation(client, salutation), 
    do: :gen_fsm.send_event(client, {:salutation, salutation})

  def process_response(client, {:response, response}), 
    do: :gen_fsm.send_event(client, {:response, response})
    
  def process_event(client, {:event, event}), 
    do: :gen_fsm.send_event(client, {:event, event})

  def register_listener(pid, listener_descriptor) when is_pid(pid), 
    do: _register_listener(pid, listener_descriptor)
  def register_listener(client, listener_descriptor), 
    do: _register_listener(get_worker_name(client), listener_descriptor)
  defp _register_listener(client, listener_descriptor), 
    do: :gen_fsm.send_all_state_event(client, {:register, listener_descriptor})

  def get_worker_name(asterisk_server_name) when is_atom(asterisk_server_name) do 
    Atom.to_string(asterisk_server_name)
    |> get_worker_name
  end
  def get_worker_name(asterisk_server_name) when is_binary(asterisk_server_name) do
    (Atom.to_string(__MODULE__) <> "_" <> asterisk_server_name)
    |> String.replace("Elixir.", "")
    |> String.replace(".", "_")
    |> String.downcase
    |> String.to_atom
  end

  def send_action(pid, action, callback) when is_pid(pid), 
    do: _send_action(pid, action, callback)
  def send_action(client, action, callback), 
    do: _send_action(get_worker_name(client), action, callback)
  defp _send_action(client, action, callback), 
    do: :gen_fsm.send_event(client, {:action, action, callback}) 

  def stop(pid), do: :gen_fsm.send_all_state_event(pid, :stop)
  
  ###################
  # Callbacks

  def init([server_name, worker_name, server_info]) do
    {conn_module, conn_options} = ServerConfig.get server_info, :connection
    {:ok, conn} = :erlang.apply(conn_module, :open, [conn_options]) 
    reader = ExAmi.Reader.start_link(worker_name, conn)
    {:ok, :wait_saluation, 
      %ClientState{
        name: server_name, server_info: server_info, connection: conn, 
        worker_name: worker_name, reader: reader
      }}
  end
  
  ###################
  # States

  def wait_saluation({:salutation, salutation}, state) do
    :ok =  validate_salutation(salutation)
    username = ServerConfig.get state.server_info, :username
    secret = ServerConfig.get state.server_info, :secret
    action = ExAmi.Message.new_action("Login", [{"Username", username},
      {"Secret", secret}])
    :ok = state.connection.send.(action)
    next_state state, :wait_login_response
  end

  def wait_login_response({:response, response}, state) do
    case ExAmi.Message.is_response_success(response) do
      false ->
        :error_logger.error_msg('Cant login: ~p', [response])
        :erlang.error(:cantlogin)
      true -> 
        # if state.respond_to, 
        #   do: send(state.respond_to, :connected)
        next_state state, :receiving
    end
  end
  
  def receiving({:response, response}, %ClientState{actions: actions} = state) do
    if state.logging, do: Logger.debug(ExAmi.Message.format_log(response))

    # Find the correct action information for this response
    {:ok, action_id} = ExAmi.Message.get(response, "ActionID")
    {action, :none, events, callback} = Dict.fetch!(actions, action_id)
    # See if we should dispatch this right away or wait for the events needed
    # to complete the response.
    new_actions = case ExAmi.Message.is_response_complete(response) do 
      true ->
        # Complete response. Dispatch and remove the action from the queue.
        if callback, do: callback.(response, events)
        Dict.delete(actions, action_id)
      false ->
        # Save the response so we can receive the associated events to
        # dispatch later.
        Dict.put(actions, action_id, {action, response, [], callback})
    end
    struct(state, actions: new_actions)
    |> next_state(:receiving)
  end

  def receiving({:event, event}, %ClientState{actions: actions} = state) do
    case ExAmi.Message.get(event, "ActionID") do
      :notfound ->
        # async event
        dispatch_event(state.name, event, state.listeners)
        next_state state, :receiving
      {:ok, action_id} ->
        # this one belongs to a response
        case Dict.get(actions, action_id) do
          nil ->
            # ignore: not ours, or stale.
            next_state state, :receiving
          {action, response, events, callback} ->
            new_events = [event|events]
            new_actions = case ExAmi.Message.is_event_last_for_response(event) do
              false ->
                Dict.put(actions, action_id, {action, response, new_events, callback})
              true ->
                if callback, do: callback.(response, new_events)
                Dict.delete state.actions, action_id
            end
            struct(state, actions: new_actions)
            |> next_state(:receiving)
        end
    end
  end

  def receiving({:action, action, callback}, state) do
    {:ok, action_id} = ExAmi.Message.get(action, "ActionID")
    new_state = struct(state, 
      actions: Dict.put(state.actions, action_id, {action, :none, [], callback}))
    :ok = state.connection.send.(action)
    next_state new_state, :receiving
  end

  def handle_event({:register, listener_descriptor}, state_name, 
      %ClientState{listeners: listeners} = client_state) do
    struct(client_state, listeners: [listener_descriptor | listeners])
    |> next_state(state_name)
  end

  def handle_event(:stop, _state_name, %{reader: reader} = state) do
    send reader, :stop
    # Give reader a chance to timeout, receive the :stop, and shutdown
    :timer.sleep(100)
    ExAmi.Supervisor.stop_child(self)
    {:stop, :normal, state}
  end

  def handle_event(_event, state_name, state), 
    do: next_state(state, state_name)

  def handle_sync_event(:next_worker, _from, state_name, %{name: name} = state) do
    next = state.counter + 1
    new_worker_name = String.to_atom "#{get_worker_name(name)}_#{next}" 
    struct(state, counter: next)
    |> reply([name, new_worker_name, state.server_info], state_name)
  end
  def handle_sync_event(_event, _from, state_name, state), 
    do: reply(state, :ok, state_name)
    
  def handle_info(_info, state_name, state), 
    do: next_state(state, state_name)

  ###################
  # Private Internal

  defp validate_salutation("Asterisk Call Manager/1.1\r\n"), do: :ok
  defp validate_salutation("Asterisk Call Manager/1.0\r\n"), do: :ok
  defp validate_salutation("Asterisk Call Manager/1.2\r\n"), do: :ok
  defp validate_salutation("Asterisk Call Manager/1.3\r\n"), do: :ok
  defp validate_salutation(invalid_id) do 
    Logger.error "Invalid Salutation #{inspect invalid_id}"
    :unknown_salutation
  end

  defp dispatch_event(server_name, event, listeners) do
    Enum.each(listeners,  
      fn({function, predicate}) ->
        spawn(fn ->
          case :erlang.apply(predicate, [event]) do 
            true ->
              function.(server_name, event)
            _ -> :ok
          end
        end)
      end)
  end
end
