defmodule ExAmi.SslConnection do
  alias ExAmi.Connection
  alias ExAmi.Message

  def open(options) do
    host = Keyword.get(options, :host)
    port = Keyword.get(options, :port)
    {:ok, %Inet.HostEnt{h_addr_list: addresses}} = Connection.resolve_host(host)
    {:ok, socket} = real_connect(addresses, port)

    {:ok,
     %Connection.Record{
       send: fn data -> __MODULE__.send(socket, data) end,
       read_line: fn timeout -> __MODULE__.read_line(socket, timeout) end,
       close: fn -> __MODULE__.close(socket) end
     }}
  end

  def real_connect([], _port), do: :outofaddresses

  def real_connect([address | tail], port) do
    case :ssl.connect(address, port, active: false, packet: :line) do
      {:ok, socket} -> {:ok, socket}
      _ -> real_connect(tail, port)
    end
  end

  def send(socket, action) do
    :ok = :ssl.send(socket, Message.marshall(action))
  end

  def close(socket) do
    :ok = :ssl.close(socket)
  end

  def read_line(socket, _timeout) do
    :ssl.recv(socket, 0, 100)
  end
end
