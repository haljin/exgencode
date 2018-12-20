defmodule Exgencode.Mixfile do
  use Mix.Project

  def project do
    [
      app: :exgencode,
      version: "1.2.0",
      elixir: "~> 1.5-rc",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: [extras: ["README.md"], main: "readme"],
      description: description()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.19.1", only: :dev, runtime: false},
      {:credo, "~> 1.0", only: [:dev, :test]},
      {:inch_ex, only: :docs},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false}
    ]
  end

  defp description do
    "Library for defining binary protocol messages, that provides a protocol for transforming between binary and Elixir structure representation"
  end

  defp package do
    [
      name: "exgencode",
      files: ["lib/exgencode.ex", "lib/pdu.ex", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Pawel Antemijczuk"],
      licenses: ["MIT License"],
      links: %{"GitHub" => "https://github.com/haljin/exgencode"}
    ]
  end
end
