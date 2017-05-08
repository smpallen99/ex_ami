defmodule ExAmi.MessageTest do
  use ExUnit.Case, async: true
  alias ExAmi.Message

  describe "setters" do
    test "sets all" do
      expected = %Message.Message{attributes:
        Enum.into([{"one", "two"}, {"three", "four"}], %{})}
      assert Message.new_message
      |> Message.set_all([{"one", "two"}, {"three", "four"}]) == expected
    end

    test "sets all variables" do
      expected = %Message.Message{variables:
        Enum.into([{"one", "two"}, {"three", "four"}], %{})}
      assert Message.new_message()
      |> Message.set_all_variables([{"one", "two"}, {"three", "four"}]) == expected
    end
  end
  describe "marshall" do
    test "handles key value" do
      assert Message.marshall("key", "value") == "key: value\r\n"
    end
    test "handles key value acc" do
      assert Message.marshall("key", "value")
        |> Message.marshall("key2", "value2")
        == "key: value\r\nkey2: value2\r\n"
    end
    test "handles variable" do
      assert Message.marshall_variable("name", "value") == "Variable: name=value\r\n"
    end
    test "handles variable with acc" do
      assert Message.marshall("key", "value")
        |> Message.marshall_variable("name", "val")
        == "key: value\r\nVariable: name=val\r\n"
    end

    test "handles simple Message" do
      message = %Message.Message{attributes: Enum.into([{"one", "two"}], %{})}
      assert Message.marshall(message) == "one: two\r\n\r\n"
    end
  end

  describe "misc" do
    test "explodes"  do
      assert Message.explode_lines("var: name\r\n") == ["var: name"]
      assert Message.explode_lines("var: name\r\nVariable: name=val\r\n") == ["var: name", "Variable: name=val"]
    end
  end

  describe "unmarshall" do
    test "handles an attribute" do
      expected = %Message.Message{attributes: Enum.into([{"var", "name"}], %{})}
      assert Message.unmarshall("var: name\r\n") == expected
    end
    test "handles 2 attributes" do
      expected = %Message.Message{attributes: Enum.into(
        [{"var", "name"}, {"var2", "name2"}], %{})}
      assert Message.unmarshall("var: name\r\nvar2: name2\r\n") == expected
    end
    test "handles a success response" do
      message = "Response: Success\r\nActionID: 1423701662161185\r\nMessage: Authentication accepted\r\n"
      expected = Message.set("Response", "Success")
      |> Message.set("ActionID", "1423701662161185")
      |> Message.set("Message", "Authentication accepted")
      unmarshalled = Message.unmarshall(message)
      assert unmarshalled == expected
      assert Message.is_response(unmarshalled) == true
    end
  end

  describe "queries" do
    test "finds a response" do
      assert Message.set("Response", "something") |> Message.is_response == true
    end
    test "does not find response" do
      assert Message.set("something", "other") |> Message.is_response == false
    end
    test "find an event" do
      assert Message.set("Event", "something") |> Message.is_event == true
    end
    test "does not find an event" do
      assert Message.set("something", "other") |> Message.is_event == false
    end
    test "finds a success response" do
      assert Message.set("Response", "Success") |> Message.is_response_success == true
    end
    test "does not find a success response" do
      assert Message.set("Response", "Failure") |> Message.is_response_success == false
    end
    test "does not find a complete response" do
      assert Message.set("Message", "follows") |> Message.is_response_complete == false
    end
    test "finds a complete response" do
      assert Message.set("other", "Failure") |> Message.is_response_complete == true
    end
    test "finds a complete response again" do
      assert Message.set("Message", "more here") |> Message.is_response_complete == true
    end
    test "finds last event for a response" do
      assert Message.set("EventList", "Complete") |> Message.is_event_last_for_response == true
    end
    test "does not find a last event for a response" do
      assert Message.set("Eventlist", "something") |> Message.is_event_last_for_response == false
    end
    test "does not find a last event for a response again" do
      assert Message.set("Message", "more here") |> Message.is_event_last_for_response == false
    end
  end
end
