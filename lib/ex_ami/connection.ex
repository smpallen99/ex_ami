defmodule ExAmi.Connection do
  defmodule Record do
    defstruct read_line: &ExAmi.Connection.Record.read_line_not_implemented/1,
              send: &__MODULE__.send_not_implemented/1,
              close: &__MODULE__.close_not_implemented/1

    def new(), do: %__MODULE__{} 
    def new(opts), do: struct(new, opts)

    def read_line_not_implemented(_), do: :erlang.error('Not implemented')
    def send_not_implemented(_), do: :erlang.error('Not implemented')
    def close_not_implemented(_), do: :erlang.error('Not implemented')
  end

  def behaviour_info(:callbacks), 
    do: [open: 1, read_line: 2, send: 2, close: 1]
  def behaviour_info(_), do: :undefined

  def resolve_host(host) do
    host_list = String.to_char_list(host)
    case :inet.gethostbyaddr(host_list) do
      {:ok, resolved} -> {:ok, Inet.HostEnt.from_record(resolved)}
      _ -> resolve_host_name(host_list)
    end
  end
  def resolve_host_name(host) do
    case :inet.gethostbyname(host) do
      {:ok, resolved} -> {:ok, Inet.HostEnt.from_record(resolved)}
      other -> other
    end
  end
  
end
