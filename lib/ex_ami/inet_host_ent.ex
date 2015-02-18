defmodule Inet.HostEnt do
  require Record
  record = Record.extract(:hostent, from_lib: "kernel/include/inet.hrl")

  keys   = :lists.map(&elem(&1, 0), record)
  vals   = :lists.map(&{&1, [], nil}, keys)
  pairs  = :lists.zip(keys, vals)

  defstruct keys
  @type t :: %__MODULE__{}

  @doc """
  Converts a `Inet.HostEnt` struct to a `:hostent` record.
  """
  def to_record(%__MODULE__{unquote_splicing(pairs)}) do
    {:hostent, unquote_splicing(vals)}
  end

  @doc """
  Converts a `:hostent` record into a `Inet.HostEnt`.
  """
  def from_record({:hostent, unquote_splicing(vals)}) do
    %__MODULE__{unquote_splicing(pairs)}
  end
end
