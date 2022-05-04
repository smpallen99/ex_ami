defmodule ExAmi.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ex_ami,
      version: "1.1.0",
      elixir: "~> 1.12",
      package: package(),
      name: "ExAmi",
      description: """
      An Elixir Asterisk AMI Client Library.
      """,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [mod: {ExAmi, []}, extra_applications: [:logger, :gen_state_machine, :ssl]]
  end

  defp deps do
    [
      {:gen_state_machine, "~> 2.1"},
      {:gen_state_machine_helpers, "~> 0.1"},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.10", only: :test}
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
