defmodule Exgencode.Mixfile do
  use Mix.Project

  def project do
    [
      app: :exgencode,
      version: "1.1.0",
      elixir: "~> 1.5-rc",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      package: package(),
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
      {:ex_doc, "~> 0.14", only: :dev, runtime: false},
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
