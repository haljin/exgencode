defmodule Exgencode.Mixfile do
  use Mix.Project

  def project do
    [
      app: :exgencode,
      version: "2.2.0",
      elixir: "~> 1.7",
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
      {:ex_doc, "~> 0.20", only: :dev, runtime: false},
      {:credo, "~> 1.0", only: [:dev, :test]},
      {:inch_ex, "~> 2.0", only: :docs},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false}
    ]
  end

  defp description do
    "Library for defining binary protocol messages, that provides a protocol for transforming between binary and Elixir structure representation"
  end

  defp package do
    [
      name: "exgencode",
      files: [
        "lib/exgencode.ex",
        "lib/exgencode/pdu.ex",
        "lib/exgencode/encode_decode.ex",
        "lib/exgencode/sizeof.ex",
        "lib/exgencode/validator.ex",
        "lib/exgencode/offsets.ex",
        "mix.exs",
        "README*",
        "LICENSE*"
      ],
      maintainers: ["Pawel Antemijczuk"],
      licenses: ["MIT License"],
      links: %{"GitHub" => "https://github.com/haljin/exgencode"}
    ]
  end
end
