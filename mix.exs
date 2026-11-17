defmodule ExAmi.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ex_ami,
      version: "1.3.0",
      elixir: "~> 1.20",
      package: package(),
      name: "ExAmi",
      description: """
      An Elixir Asterisk AMI Client Library.
      """,
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ]
    ]
  end

  def application do
    [mod: {ExAmi, []}, extra_applications: [:logger, :gen_state_machine, :ssl]]
  end

  defp deps do
    [
      {:gen_state_machine, "~> 3.0"},
      {:gen_state_machine_helpers, "~> 0.1"},
      {:mix_test_watch, "~> 1.4", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18.5", only: :test}
    ]
  end

  defp package do
    [
      maintainers: ["Ian Sinclair", "Stephen Pallen"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/smpallen99/ex_ami"},
      files: ~w(lib README.md mix.exs LICENSE)
    ]
  end
end
