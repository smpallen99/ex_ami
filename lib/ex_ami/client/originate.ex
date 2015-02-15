defmodule ExAmi.Client.Originate do
  require Logger
  alias ExAmi.Client
 
  def dial(sever_name, channel, other, variables \\ [], callback \\ nil)
  def dial(server_name, channel, {context, extension, priority}, variables, callback) do
    action_params = %{
      server_name: server_name, channel: channel, context: context,
      extension: extension, priority: priority, variables: variables,
      callback: callback
    }

    {:ok, client_pid} = ExAmi.Client.start_child(server_name)

    Client.register_listener(client_pid, { 
      &(event_listener(client_pid, &1, &2, action_params)),
      &(Dict.get(&1.attributes, "Event") in ~w(FullyBooted Hangup))
    })
    {:ok, client_pid}
  end
  def dial(server_name, channel, extension, variables, callback), do:
    dial(server_name, channel, {"from-internal", extension, "1"}, variables, callback)
        
  # For testing purposes
  # TODO: Remove
  def dial(ch, extension), do: dial(:asterisk, "UCX/#{ch}@#{ch}", "#{extension}")

  
  #####################
  # Listener
 
  def event_listener(client_pid, _server_name, 
      %{attributes: attributes}, action_params) do
    case Dict.get(attributes, "Event") do
      "FullyBooted" -> 
        send_action(client_pid, action_params)
      "Hangup" -> 
        %{channel: orig_channel} = action_params
        event_channel = Dict.get(attributes, "Channel")
        if String.match? event_channel, ~r/#{orig_channel}/ do
          Client.stop client_pid
        end
      _ -> :ok
    end
  end

  def send_action(client_pid, %{
      channel: channel, context: context, extension: extension, 
      priority: priority, variables: variables, callback: callback }) do

    action = ExAmi.Message.new_action(
        "Originate",
        [
            {"Channel", channel}, {"Exten", extension},
            {"Context", context}, {"Priority", priority}
        ],
        variables
      )
    ExAmi.Client.send_action(client_pid, action, callback)
  end
end
