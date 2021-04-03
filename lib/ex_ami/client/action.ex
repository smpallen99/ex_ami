defmodule ExAmi.Client.Action do
  alias ExAmi.{Client, Message}

  def hangup(client, channel, callback \\ nil) do
    Client.send_action(
      Process.whereis(client),
      Message.new_action("Hangup", [{"Channel", channel}]),
      callback
    )
  end
end
