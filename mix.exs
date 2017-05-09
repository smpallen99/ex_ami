defmodule ExAmi.Mixfile do
  use Mix.Project

  def project do
    [app: :ex_ami,
     version: "0.2.0",
     elixir: "~> 1.3",
     package: package(),
     name: "ExAmi",
     description: """
     An Elixir Asterisk AMI Client Library.
     """,
     deps: deps()]
  end

  def application do
    [ mod: {ExAmi, []},
      applications: [:logger, :gen_fsm]]
  end

  defp deps do
    [
      # {:gen_fsm, github: "smpallen99/gen_fsm"}
      {:gen_fsm, "~> 0.1"}
    ]
  end
  defp package do
    [ maintainers: ["Stephen Pallen"],
      licenses: ["MIT"],
      links: %{ "Github" => "https://github.com/smpallen99/ex_ami"},
      files: ~w(lib README.md mix.exs LICENSE)]
  end
end
