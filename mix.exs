defmodule S5.MixProject do
  use Mix.Project

  def project do
    [
      app: :s5,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {S5, []},
      extra_applications: [
        :logger,
        :logger_file_backend
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ranch, "~> 1.7"},
      {:logger_file_backend, "~> 0.0.13"}
    ]
  end
end
