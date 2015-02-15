defmodule ExAmi.MessageTest do
  use Pavlov.Case, async: true
  import Pavlov.Syntax.Expect  
  alias ExAmi.Message

  describe "setters" do
    it "sets all" do
      expected = %Message.Message{attributes: 
        Enum.into([{"one", "two"}, {"three", "four"}], HashDict.new)} 
      expect Message.new_message 
      |> Message.set_all([{"one", "two"}, {"three", "four"}])
      |> to_eq expected
    end

    it "sets all variables" do
      expected = %Message.Message{variables: 
        Enum.into([{"one", "two"}, {"three", "four"}], HashDict.new)} 
      expect Message.new_message 
      |> Message.set_all_variables([{"one", "two"}, {"three", "four"}])
      |> to_eq expected

    end
  end
  describe "marshall" do
    it "handles key value" do
      expect Message.marshall("key", "value") |> to_eq "key: value\r\n"
    end
    it "handles key value acc" do
      expect Message.marshall("key", "value") 
        |> Message.marshall("key2", "value2")
        |> to_eq "key: value\r\nkey2: value2\r\n"
    end
    it "handles variable" do
      expect Message.marshall_variable("name", "value") |> to_eq "Variable: name=value\r\n"
    end
    it "handles variable with acc" do
      expect Message.marshall("key", "value")
        |> Message.marshall_variable("name", "val")
        |> to_eq "key: value\r\nVariable: name=val\r\n"
    end

    it "handles simple Message" do
      message = %Message.Message{attributes: Enum.into([{"one", "two"}], HashDict.new)}
      expect Message.marshall(message) |> to_eq "one: two\r\n\r\n"
    end
  end

  describe "misc" do
    it "explodes"  do
      expect Message.explode_lines("var: name\r\n") |> to_eq ["var: name"]
      expect Message.explode_lines("var: name\r\nVariable: name=val\r\n") |> to_eq ["var: name", "Variable: name=val"]
    end
  end

  describe "unmarshall" do
    it "handles an attribute" do
      expected = %Message.Message{attributes: Enum.into([{"var", "name"}], HashDict.new)}
      expect Message.unmarshall("var: name\r\n") |> to_eq expected
    end
    it "handles 2 attributes" do
      expected = %Message.Message{attributes: Enum.into(
        [{"var", "name"}, {"var2", "name2"}], HashDict.new)}
      expect Message.unmarshall("var: name\r\nvar2: name2\r\n") |> to_eq expected
    end
    it "handles a success response" do
      message = "Response: Success\r\nActionID: 1423701662161185\r\nMessage: Authentication accepted\r\n"
      expected = Message.set("Response", "Success") 
      |> Message.set("ActionID", "1423701662161185")
      |> Message.set("Message", "Authentication accepted")
      unmarshalled = Message.unmarshall(message)
      expect unmarshalled |> to_eq expected
      expect Message.is_response(unmarshalled) |> to_eq true
    end
  end

  describe "queries" do
    it "finds a response" do
      expect Message.set("Response", "something") |> Message.is_response |> to_eq true
    end
    it "does not find response" do
      expect Message.set("something", "other") |> Message.is_response |> to_eq false
    end
    it "find an event" do
      expect Message.set("Event", "something") |> Message.is_event |> to_eq true
    end
    it "does not find an event" do
      expect Message.set("something", "other") |> Message.is_event |> to_eq false
    end
    it "finds a success response" do
      expect Message.set("Response", "Success") |> Message.is_response_success |> to_eq true
    end
    it "does not find a success response" do
      expect Message.set("Response", "Failure") |> Message.is_response_success |> to_eq false
    end
    it "does not find a complete response" do
      expect Message.set("Message", "follows") |> Message.is_response_complete |> to_eq false
    end
    it "finds a complete response" do
      expect Message.set("other", "Failure") |> Message.is_response_complete |> to_eq true
    end
    it "finds a complete response again" do
      expect Message.set("Message", "more here") |> Message.is_response_complete |> to_eq true
    end
    it "finds last event for a response" do
      expect Message.set("EventList", "Complete") |> Message.is_event_last_for_response |> to_eq true
    end
    it "does not find a last event for a response" do
      expect Message.set("Eventlist", "something") |> Message.is_event_last_for_response |> to_eq false
    end
    it "does not find a last event for a response again" do
      expect Message.set("Message", "more here") |> Message.is_event_last_for_response |> to_eq false
    end
  end
end
