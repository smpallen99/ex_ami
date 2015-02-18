defmodule ExAmi.ConnectionTest do
  use Pavlov.Case, async: true
  import Pavlov.Syntax.Expect  
  alias ExAmi.Connection

  it "resolve ip" do 
    {result, _} = Connection.resolve_host("127.0.0.1")
    expect result |> to_eq :ok
  end
  it "resolve hostname" do 
    {result, _} = Connection.resolve_host("localhost")
    expect result |> to_eq :ok
  end
  it "resolved hostname" do 
    {result, _} = Connection.resolve_host("host")
    expect result |> to_eq :error
  end

end
