defmodule DrainEx.MixProject do
  use Mix.Project

  @version "0.1.4"

  def project do
    [
      app: :drain_ex,
      version: @version,
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "DrainEx",
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {DrainEx.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:cbor, "~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, "~> 1.5", only: [:dev, :test]},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp description() do
    "Lean elixir-based API for the distributed, federated message-store 'drain'"
  end

  defp docs do
    [
      main: "DrainEx",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/drain_ex",
      source_url: "https://github.com/frobese/drain_ex"
    ]
  end

  defp package() do
    [
      name: "drain_ex",
      maintainers: ["Christoph Ehlts, Hans Gödeke"],
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/frobese/drain_ex"}
    ]
  end
end
