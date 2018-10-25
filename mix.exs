defmodule ExAmi.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ex_ami,
      version: "0.4.1",
      elixir: "~> 1.5",
      package: package(),
      name: "ExAmi",
      description: """
      An Elixir Asterisk AMI Client Library.
      """,
      deps: deps()
    ]
  end

  def application do
    [mod: {ExAmi, []}, applications: [:logger, :gen_state_machine]]
  end

  defp deps do
    [
      {:gen_state_machine, "~> 2.0"},
      {:gen_state_machine_helpers, "~> 0.1"}
    ]
  end

  defp package do
    [
      maintainers: ["Stephen Pallen"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/smpallen99/ex_ami"},
      files: ~w(lib README.md mix.exs LICENSE)
    ]
  end
end
