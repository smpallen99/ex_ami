defmodule ExAmi.ClientTest do
  use ExUnit.Case, async: true

  alias ExAmi.{Client, Message}

  setup do
    pid = self()

    connection = %{
      send: fn msg ->
        send(pid, {:connection, msg})
        :ok
      end
    }

    {:ok, state: %Client.ClientState{connection: connection}}
  end

  test "handle response invalid action does not raise", %{state: state} do
    message = Message.new_action("test")
    {:next_state, :receiving, new_state} = Client.receiving(:cast, {:response, message}, state)
    assert new_state == state
  end

  test "handle duplicate action", %{state: state} do
    pid = self()
    callback = &send(pid, {:callback, &1, &2})
    action = Message.new_action("QueueStatus")
    action_id = action.attributes["ActionID"]

    {:next_state, :receiving, state} = Client.receiving(:cast, {:action, action, callback}, state)

    assert state.actions == %{
             action_id => {action, :none, [], callback}
           }

    assert_receive {:connection, ^action}

    action_id_alt = action_id <> "_alt"

    {:next_state, :receiving, state} = Client.receiving(:cast, {:action, action, callback}, state)

    action2 = Message.put(action, "ActionID", action_id_alt)

    assert state.actions == %{
             action_id => {action, :none, [], callback},
             action_id_alt => {action2, :none, [], callback}
           }

    assert_receive {:connection, ^action2}
  end

  test "handle QueueStatusResponse", %{state: state} do
    pid = self()
    callback = &send(pid, {:callback, &1, &2})
    action = Message.new_action("QueueStatus")
    action_id = action.attributes["ActionID"]

    {:next_state, :receiving, state} = Client.receiving(:cast, {:action, action, callback}, state)

    assert state.actions == %{
             action_id => {action, :none, [], callback}
           }

    assert_receive {:connection, ^action}

    event1 =
      unmarshall("""
      Response: Success
      ActionID: #{action_id}
      EventList: start
      Message: Queue status will follow

      """)

    {:next_state, :receiving, state} = Client.receiving(:cast, {:event, event1}, state)

    assert state.actions == %{
             action_id => {action, :none, [event1], callback}
           }

    event2 =
      unmarshall("""
      Event: QueueParams
      Queue: 500
      Calls: 0
      ActionID: #{action_id}

      """)

    {:next_state, :receiving, state} = Client.receiving(:cast, {:event, event2}, state)

    assert state.actions == %{
             action_id => {action, :none, [event2, event1], callback}
           }

    event3 =
      unmarshall("""
      Event: QueueMember
      ActionID: #{action_id}
      Queue: 500
      Name: 2000

      """)

    {:next_state, :receiving, state} = Client.receiving(:cast, {:event, event3}, state)

    assert state.actions == %{
             action_id => {action, :none, [event3, event2, event1], callback}
           }

    event4 =
      unmarshall("""
      Event: QueueStatusComplete
      ActionID: #{action_id}
      EventList: Complete
      ListItems: 2

      """)

    {:next_state, :receiving, state} = Client.receiving(:cast, {:event, event4}, state)

    assert state.actions == %{}

    expected = [event1, event2, event3, event4]
    assert_receive {:callback, :none, ^expected}

    refute_receive _, 2
  end

  defp unmarshall(text) do
    text = String.replace(text, "\n", "\r\n")
    Message.unmarshall(text)
  end
end
