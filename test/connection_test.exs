defmodule ExAmi.ConnectionTest do
  use ExUnit.Case, async: true
  alias ExAmi.Connection

  test "resolve ip" do
    {result, _} = Connection.resolve_host("127.0.0.1")
    assert result == :ok
  end

  test "resolve hostname" do
    {result, _} = Connection.resolve_host("localhost")
    assert result == :ok
  end
end
