defmodule ExAmi.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], [name: :exami_supervisor])
  end

  def start_child(server_name, worker_name, server_info), 
    do: Supervisor.start_child(:exami_supervisor, [server_name, worker_name, server_info])

  def start_child(server_name), 
    do: Supervisor.start_child(:exami_supervisor, [server_name])

  def stop_child(pid) do
    Supervisor.terminate_child(:exami_supervisor, pid)
  end

  def init([]) do
    children = [worker(ExAmi.Client, [])]
    supervise(children, [strategy: :simple_one_for_one])
  end 
end
