defmodule Kirimify.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/narakarya/kirimify_ex"

  def project do
    [
      app: :kirimify,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Elixir client + webhook verifier for the Kirimify WhatsApp API",
      package: package(),
      source_url: @source_url,
      docs: [main: "Kirimify", extras: ["README.md"]]
    ]
  end

  def application do
    [extra_applications: [:logger, :crypto]]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      # `plug` brings `plug_crypto` for constant-time signature comparison and
      # the Plug behaviour used by Kirimify.Plug.
      {:plug, "~> 1.14"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Narakarya"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end
end
