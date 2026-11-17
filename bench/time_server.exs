defmodule TimeServer do
  @moduledoc """
  Test module to allow time testing of alternatives for generating an Action ID.
  The start function takes a number of iterations and the algorithm number, and
  spawns a task for each (hard-coded) number of cpus to generate that many IDs.
  Each task sends the results to the TimeServer.
  The compute function determines the number of duplicate IDs generated and displays
  the total count and the unique count.
  The display function shows the duplicated values and the CPU process they appear in.
  """

  use GenServer

  defstruct agents: %{},
            results: %{},
            values: [],
            doubles: []

  @name __MODULE__
  @num_cores 2

  def child_spec(args) do
    %{
      id: "#{@name}",
      start: {__MODULE__, :start_link, args},
      restart: :transient,
      shutdown: 60,
      type: :worker
    }
  end

  @spec start_link(any) :: no_return
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  def status() do
    GenServer.call(@name, :status)
  end

  def reset() do
    GenServer.cast(@name, :reset)
  end

  def display() do
    GenServer.cast(@name, :display)
  end

  def compute() do
    GenServer.call(@name, :compute, 20000)
  end

  def start(number \\ 100, type \\ 0) do
    if Process.whereis(@name),
      do: GenServer.cast(@name, {:start, number, type}),
      else: IO.puts("#{@name} not running")
  end

  @impl true
  def init(_) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def terminate(reason, _state) do
    IO.puts("#{__MODULE__} terminating with reason: #{inspect(reason)}")
    :ok
  end

  @impl true
  def handle_info({:result, task, times}, state) do
    {:noreply, %{state | results: Map.put(state.results, task, times)}}
  end

  @impl true
  def handle_cast({:start, number, type}, state) do
    self = self()
    start_time = String.to_integer(type(1))
    start_tick = type(0)

    send_results = fn core ->
      spawn(fn ->
        results = for _ <- 1..number, do: type(type)
        send(self, {:result, core, results})
      end)
    end

    state =
      for i <- 1..@num_cores, reduce: state do
        state -> %{state | agents: Map.put(state.agents, i, send_results.(i))}
      end

    end_time = String.to_integer(type(1))
    end_tick = type(0)
    IO.inspect({end_time - start_time, end_tick - start_tick}, label: "run time")
    {:noreply, state}
  end

  def handle_cast(:reset, state) do
    {:noreply,
     state
     |> Map.put(:results, %{})
     |> Map.put(:values, [])
     |> Map.put(:doubles, [])}
  end

  def handle_cast(:display, state) do
    Enum.each(state.doubles, fn value ->
      for i <- 1..@num_cores do
        if value in state.results[i], do: IO.inspect({value, i})
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:compute, _from, state) do
    {total, unique, state} = do_compute(state)
    {:reply, {length(total), length(unique)}, state}
  end

  defp do_compute(state) do
    all =
      state.results
      |> Map.values()
      |> List.flatten()

    uniq = all |> Enum.uniq()

    state =
      state
      |> Map.put(:values, all)
      |> Map.put(:doubles, all -- uniq)

    {all, uniq, state}
  end

  @compile {:inline, type: 1}
  defp type(0), do: :erlang.monotonic_time()
  defp type(1), do: :os.timestamp() |> Tuple.to_list() |> Enum.join("")
  defp type(2), do: to_string(:erlang.monotonic_time()) <> to_string(:rand.uniform(1000))
end
