defmodule ExAmi.Client.Originate do
  require Logger

  alias ExAmi.{Message, Client}

  def dial(sever_name, channel, other, variables \\ [], callback \\ nil, opts \\ [])

  def dial(server_name, channel, {context, extension, priority}, variables, callback, opts) do
    action_params = %{
      server_name: server_name,
      channel: channel,
      context: context,
      extension: extension,
      priority: priority,
      variables: variables,
      callback: callback,
      other: opts
    }

    {:ok, client_pid} = Client.start_child(server_name)

    Client.register_listener(client_pid, {
      &event_listener(client_pid, &1, &2, action_params),
      &(Map.get(&1.attributes, "Event") in ~w(FullyBooted Hangup))
    })

    {:ok, client_pid}
  end

  def dial(server_name, channel, extension, variables, callback, opts),
    do: dial(server_name, channel, {"from-internal", extension, "1"}, variables, callback, opts)

  #####################
  # Listener

  def event_listener(client_pid, _server_name, %{attributes: attributes}, action_params) do
    case Map.get(attributes, "Event") do
      "FullyBooted" ->
        send_action(client_pid, action_params)

      "Hangup" ->
        %{channel: orig_channel} = action_params
        event_channel = Map.get(attributes, "Channel")

        if String.match?(event_channel, ~r/#{orig_channel}/) do
          Client.stop(client_pid)
        end
    end
  end

  def send_action(client_pid, %{
        channel: channel,
        context: context,
        extension: extension,
        priority: priority,
        variables: variables,
        callback: callback,
        other: opts
      }) do
    action =
      Message.new_action(
        "Originate",
        [
          {"Channel", channel},
          {"Exten", extension},
          {"Context", context},
          {"Priority", priority}
        ] ++ opts,
        variables
      )

    Client.send_action(client_pid, action, callback)
  end
end
