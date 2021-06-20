defmodule ExAmi.Supervisor do
  use DynamicSupervisor

  def child_spec(args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, args},
      restart: :permanent,
      type: :supervisor
    }
  end

  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args, name: :exami_supervisor)
  end

  def start_child(server_name, worker_name, server_info),
    do: DynamicSupervisor.start_child(:exami_supervisor, {ExAmi.Client, [server_name, worker_name, server_info]})

  def start_child(server_name),
    do: DynamicSupervisor.start_child(:exami_supervisor, {ExAmi.Client, [server_name]})

  def stop_child(pid) do
    DynamicSupervisor.terminate_child(:exami_supervisor, pid)
  end

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
