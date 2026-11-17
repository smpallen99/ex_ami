defmodule ExAmi.TcpClientTest do
  use ExUnit.Case, async: true

  alias ExAmi.{Client, Message, TcpConnection}

  test "client logs in, dispatches events, and completes actions over TCP" do
    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, ip: {127, 0, 0, 1}, active: false, packet: :line])

    {:ok, {{127, 0, 0, 1}, port}} = :inet.sockname(listener)
    on_exit(fn -> :gen_tcp.close(listener) end)

    client =
      start_supervised!(
        {Client,
         [
           :tcp_upgrade_test,
           :ex_ami_tcp_upgrade_test,
           [
             connection: {TcpConnection, [host: "127.0.0.1", port: port]},
             username: "test-user",
             secret: "test-secret"
           ]
         ]}
      )

    {:ok, socket} = :gen_tcp.accept(listener, 1_000)
    on_exit(fn -> :gen_tcp.close(socket) end)
    :ok = :gen_tcp.send(socket, "Asterisk Call Manager/9.0.0\r\n")

    login = receive_message(socket)
    assert login.attributes["Action"] == "Login"
    assert login.attributes["Username"] == "test-user"
    assert login.attributes["Secret"] == "test-secret"

    parent = self()

    Client.register_listener(
      client,
      {fn name, event -> send(parent, {:event, name, event}) end, nil}
    )

    assert Client.status(client).reader |> is_pid()

    :ok =
      :gen_tcp.send(socket, [
        "Response: Success\r\nActionID: ",
        login.attributes["ActionID"],
        "\r\n\r\nEvent: FullyBooted\r\n\r\n"
      ])

    assert_receive {:event, :tcp_upgrade_test, event}, 1_000
    assert event.attributes["Event"] == "FullyBooted"
    assert Client.online?(client)

    action = Message.new_action("Ping")

    Client.send_action(client, action, fn response, events ->
      send(parent, {:response, response, events})
    end)

    assert receive_message(socket) == action

    :ok =
      :gen_tcp.send(socket, [
        "Response: Success\r\nPing: Pong\r\nActionID: ",
        action.attributes["ActionID"],
        "\r\n\r\n"
      ])

    assert_receive {:response, response, []}, 1_000
    assert response.attributes["Ping"] == "Pong"
    assert Client.status(client).actions == %{}
  end

  defp receive_message(socket, lines \\ []) do
    case :gen_tcp.recv(socket, 0, 1_000) do
      {:ok, "\r\n"} -> lines |> Enum.reverse() |> IO.iodata_to_binary() |> Message.unmarshall()
      {:ok, line} -> receive_message(socket, [line | lines])
      other -> flunk("Expected an AMI message, got: #{inspect(other)}")
    end
  end
end
