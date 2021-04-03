defmodule ExAmi.ClientSupervisor do
  use DynamicSupervisor

  alias ExAmi.Client

  @name __MODULE__

  def start_link do
    DynamicSupervisor.start_link(__MODULE__, [], name: @name)
  end

  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args, name: @name)
  end

  def start_child(server_name, worker_name, server_info),
    do: DynamicSupervisor.start_child(@name, {Client, [server_name, worker_name, server_info]})

  def start_child(server_name),
    do: DynamicSupervisor.start_child(@name, {Client, [server_name]})

  def stop_child(pid) do
    DynamicSupervisor.terminate_child(@name, pid)
  end

  ############
  # Callbacks

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
