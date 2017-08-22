defmodule ExAmi.Reader do
  alias ExAmi.Connection.Record, as: ConnRecord
  alias ExAmi.Client
  alias ExAmi.Message

  require Logger

  def start_link(client, %ConnRecord{} = connection) do
    spawn_link fn ->
      read_salutation(client, connection)
      loop(client, connection, "")
    end
  end

  def read_salutation(client, connection) do
    line = wait_line(connection)
    Client.process_salutation(client, line)
  end

  def loop(client, connection, acc \\ "") do
    new_acc = case wait_line(connection) do
      "\r\n" ->
        unmarshalled = ExAmi.Message.unmarshall(acc)
        dispatch_message(client, unmarshalled,
          Message.is_response(unmarshalled),
          Message.is_event(unmarshalled),
          acc)
        ""
      line ->
        acc <> line # |> IO.inspect(label: "line")
    end
    loop(client, connection, new_acc)
  end

  def dispatch_message(client, response, true, false, _),
    do: Client.process_response(client, {:response, response})
  def dispatch_message(client, response, false, true, _),
    do: Client.process_event(client, {:event, response})
  def dispatch_message(_client, _response, _, _, original),
    do: Logger.error("Unknown message: #{inspect original}")

  def wait_line(%ConnRecord{read_line: read_line} = connection) do
    case read_line.(10) do
      {:ok, line} -> line
      {:error, :timeout} ->
        receive do
          {:close} ->
            :erlang.exit(:shutdown)
          :stop ->
            %ConnRecord{close: close_fn} = connection
            close_fn.()
            :erlang.exit(:normal)
        after 10 ->
          wait_line(connection)
        end
      {:error, reason} ->
        :erlang.error(reason)
    end
  end
end
