defmodule ExAmi do
  use Application

  def start(_type, _args) do
    {:ok, pid} = ExAmi.Supervisor.start_link([])
    # |> IO.inspect(label: "ExAmi.start return")

    for {name, info} <- Application.get_env(:ex_ami, :servers, []) |> deep_parse() do
      worker_name = ExAmi.Client.get_worker_name(name)
      # |> IO.inspect(label: "worker_name")
      ExAmi.Supervisor.start_child(name, worker_name, info)
      # |> IO.inspect(label: "ExAmi.start start_child return")
    end

    {:ok, pid}
  end

  def deep_parse([]), do: []
  def deep_parse([h | t]), do: [deep_parse(h) | deep_parse(t)]

  def deep_parse({item, list}) when is_list(list) or is_tuple(list),
    do: {deep_parse(item), deep_parse(list)}

  def deep_parse({:port, {:system, env}}),
    do: {:port, (System.get_env(env) || "5038") |> String.to_integer()}

  def deep_parse({:host, {:system, env}}), do: {:host, System.get_env(env) || "127.0.0.1"}
  def deep_parse({item, {:system, env}}), do: {item, System.get_env(env)}
  def deep_parse({:system, env}), do: System.get_env(env)
  def deep_parse({item, item2}), do: {item, item2}
  def deep_parse(item), do: item
end
