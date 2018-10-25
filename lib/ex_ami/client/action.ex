defmodule ExAmi.Client.Action do
  def hangup(client, channel, callback \\ nil) do
    action = ExAmi.Message.new_action("Hangup", [{"Channel", channel}])
    pid = Process.whereis(client)
    ExAmi.Client.send_action(pid, action, callback)
  end
end
