defmodule ExAmi.ReaderTest do
  use Pavlov.Case, async: true
  use Pavlov.Mocks
  import Pavlov.Syntax.Expect  
  alias ExAmi.Reader
  alias ExAmi.Client


  describe "salutation" do
    before :each do
      allow(Client) |> to_receive(process_salutation: fn(_, _) -> true end)
      :ok
    end

    let :connection do
      %ExAmi.Connection.Record{read_line: fn(_) -> {:ok, "Asterisk Call Manager/1.1\r\n"} end}
    end

    it "reads the salutation" do
      expect Reader.read_salutation(nil, connection) |> to_eq true
    end

  end
end
