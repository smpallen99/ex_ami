defmodule ExAmi.MessageTest do
  use ExUnit.Case, async: true
  alias ExAmi.Message

  describe "setters" do
    test "sets all" do
      expected = %Message.Message{attributes: Enum.into([{"one", "two"}, {"three", "four"}], %{})}

      assert Message.new_message()
             |> Message.set_all([{"one", "two"}, {"three", "four"}]) == expected
    end

    test "sets all variables" do
      expected = %Message.Message{variables: Enum.into([{"one", "two"}, {"three", "four"}], %{})}

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
             |> Message.marshall("key2", "value2") == "key: value\r\nkey2: value2\r\n"
    end

    test "handles variable" do
      assert Message.marshall_variable("name", "value") == "Variable: name=value\r\n"
    end

    test "handles variable with acc" do
      assert Message.marshall("key", "value")
             |> Message.marshall_variable("name", "val") == "key: value\r\nVariable: name=val\r\n"
    end

    test "handles simple Message" do
      message = %Message.Message{attributes: Enum.into([{"one", "two"}], %{})}
      assert Message.marshall(message) == "one: two\r\n\r\n"
    end
  end

  describe "misc" do
    test "explodes" do
      assert Message.explode_lines("var: name\r\n") == ["var: name"]

      assert Message.explode_lines("var: name\r\nVariable: name=val\r\n") == [
               "var: name",
               "Variable: name=val"
             ]
    end
  end

  describe "unmarshall" do
    test "handles an attribute" do
      expected = %Message.Message{attributes: Enum.into([{"var", "name"}], %{})}
      assert Message.unmarshall("var: name\r\n") == expected
    end

    test "handles 2 attributes" do
      expected = %Message.Message{
        attributes: Enum.into([{"var", "name"}, {"var2", "name2"}], %{})
      }

      assert Message.unmarshall("var: name\r\nvar2: name2\r\n") == expected
    end

    test "handles a success response" do
      message =
        "Response: Success\r\nActionID: 1423701662161185\r\nMessage: Authentication accepted\r\n"

      expected =
        Message.set("Response", "Success")
        |> Message.set("ActionID", "1423701662161185")
        |> Message.set("Message", "Authentication accepted")

      unmarshalled = Message.unmarshall(message)
      assert unmarshalled == expected
      assert Message.is_response(unmarshalled) == true
    end

    test "handles all key/value pairs" do
      %Message.Message{attributes: attributes} = Message.unmarshall(all_key_value_pairs())
      assert attributes["Event"] == "SuccessfulAuth"
      assert attributes["Privilege"] == "security,all"
      assert attributes["SessionID"] == "0x7f0c50000910"
    end

    test "response follows ResponseData" do
      %Message.Message{attributes: attributes} = Message.unmarshall(response_follows_message())
      assert attributes["Response"] == "Follows"
      assert attributes["Privilege"] == "Command"
      assert attributes["ActionID"] == "1530285340189277"
      [one, two, three, four] = attributes["ResponseData"] |> String.split("\n", trim: true)

      assert String.match?(
               one,
               ~r/Name\/username\s+Host\s+Dyn Forcerport Comedia    ACL Port     Status      Description/
             )

      assert String.match?(two, ~r/200\s+\(Unspecified\)\s+D  No\s+No\s+A  0\s+UNKNOWN/)

      assert three ==
               "1 sip peers [Monitored: 0 online, 1 offline Unmonitored: 0 online, 0 offline]"

      assert four == "--END COMMAND--"
    end
  end

  describe "queries" do
    test "finds a response" do
      assert Message.set("Response", "something") |> Message.is_response() == true
    end

    test "does not find response" do
      assert Message.set("something", "other") |> Message.is_response() == false
    end

    test "find an event" do
      assert Message.set("Event", "something") |> Message.is_event() == true
    end

    test "does not find an event" do
      assert Message.set("something", "other") |> Message.is_event() == false
    end

    test "finds a success response" do
      assert Message.set("Response", "Success") |> Message.is_response_success() == true
    end

    test "does not find a success response" do
      assert Message.set("Response", "Failure") |> Message.is_response_success() == false
    end

    test "does not find a complete response" do
      assert Message.set("Message", "follows") |> Message.is_response_complete() == false
    end

    test "finds a complete response" do
      assert Message.set("other", "Failure") |> Message.is_response_complete() == true
    end

    test "finds a complete response again" do
      assert Message.set("Message", "more here") |> Message.is_response_complete() == true
    end

    test "finds last event for a response" do
      assert Message.set("EventList", "Complete") |> Message.is_event_last_for_response() == true
    end

    test "does not find a last event for a response" do
      assert Message.set("Eventlist", "something") |> Message.is_event_last_for_response() ==
               false
    end

    test "does not find a last event for a response again" do
      assert Message.set("Message", "more here") |> Message.is_event_last_for_response() == false
    end
  end

  defp convert_newlines(text) do
    text
    |> String.split("\n", trim: true)
    |> Enum.join("\r\n")
  end

  defp all_key_value_pairs,
    do:
      """
      Event: SuccessfulAuth
      Privilege: security,all
      EventTV: 2018-06-29T10:20:05.681-0500
      Severity: Informational
      Service: AMI
      EventVersion: 1
      AccountID: infinity_one
      SessionID: 0x7f0c50000910
      LocalAddress: IPV4/TCP/0.0.0.0/5038
      RemoteAddress: IPV4/TCP/10.30.50.10/42465
      UsingPassword: 0
      SessionTV: 2018-06-29T10:20:05.681-0500
      """
      |> convert_newlines()

  defp response_follows_message,
    do:
      """
      Response: Follows
      Privilege: Command
      ActionID: 1530285340189277
      Name/username             Host                                    Dyn Forcerport Comedia    ACL Port     Status      Description
      200                       (Unspecified)                            D  No         No          A  0        UNKNOWN
      1 sip peers [Monitored: 0 online, 1 offline Unmonitored: 0 online, 0 offline]
      --END COMMAND--
      """
      |> convert_newlines()
end
