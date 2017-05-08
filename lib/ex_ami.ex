defmodule ExAmi do
  use Application
  require Logger

  def start(_type, _args) do
    {:ok, pid} = ExAmi.Supervisor.start_link()
    for {name, info} <- Application.get_env(:ex_ami, :servers, []) do
      worker_name = ExAmi.Client.get_worker_name(name)
      ExAmi.Supervisor.start_child(name, worker_name, info)
    end
    {:ok, pid}
  end

end
