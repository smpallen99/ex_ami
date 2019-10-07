defmodule ExAmi.ClientTest do
  use ExUnit.Case, async: true

  alias ExAmi.{Client, Message}

  setup do
    {:ok, state: %Client.ClientState{}}
  end

  test "handle response invalid action does not raise", %{state: state} do
    message = Message.new_action("test")
    {:next_state, :receiving, new_state} = Client.receiving(:cast, {:response, message}, state)
    assert new_state == state
  end
end
