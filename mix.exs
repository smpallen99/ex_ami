defmodule ExAmi.Mixfile do
  use Mix.Project

  def project do
    [app: :ex_ami,
     version: "0.0.2",
     elixir: "~> 1.0-0",
     deps: deps]
  end

  def application do
    [ mod: {ExAmi, []},
      applications: [:logger]]
  end

  defp deps do
    [
      {:pavlov, "~> 0.1.2", only: :test},
      {:ex_ami, github: "smpallen99/gen_fsm"}
    ]
  end
end
