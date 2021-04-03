defmodule ExAmi.Supervisor do
  use Supervisor

  @name :exami_supervisor

  def start_link(_) do
    Supervisor.start_link(__MODULE__, [], name: @name)
  end

  def init(_) do
    # children = [worker(ExAmi.Client, [])]
    # supervise(children, strategy: :simple_one_for_one)
    children = [{ExAmi.ClientSupervisor, [[]]}]
    # children = [{ExAmi.Client, []}, {ExAmi.ClientSupervisor, [[]]}]
    # children = [{ExAmi.Client, []}]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
