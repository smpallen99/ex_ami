defmodule ExAmi.TcpConnection do
  alias ExAmi.Connection
  alias ExAmi.Message
  require Logger

  def open(options) do
    host = Keyword.get(options, :host)
    port = Keyword.get(options, :port)

    with {:ok, %Inet.HostEnt{h_addr_list: addresses}} <- Connection.resolve_host(host),
         {:ok, socket} <- real_connect(addresses, port) do
      {:ok,
       %Connection.Record{
         send: fn data -> __MODULE__.send(socket, data) end,
         read_line: fn timeout -> __MODULE__.read_line(socket, timeout) end,
         close: fn -> __MODULE__.close(socket) end,
         parent: self()
       }}
    else
      error ->
        error
    end
  end

  def real_connect([], _port), do: :outofaddresses

  def real_connect([address | tail], port) do
    case :gen_tcp.connect(
           address,
           port,
           [:binary] ++ [reuseaddr: true, active: false, packet: :line]
         ) do
      {:ok, socket} -> {:ok, socket}
      _error -> real_connect(tail, port)
    end
  end

  def send(socket, action) do
    :ok = :gen_tcp.send(socket, Message.marshall(action))
  end

  def close(socket) do
    :ok = :gen_tcp.close(socket)
  end

  def read_line(socket, timeout) do
    :gen_tcp.recv(socket, 0, timeout)
  end
end
