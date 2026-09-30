defmodule LiveDelegate.MixProject do
  use Mix.Project

  def project do
    [
      app: :live_delegate,
      version: "0.1.1",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "Composable event, message, mount, and assign delegation for Phoenix LiveView",
      deps: deps(),
      package: package(),
      source_url: "https://github.com/danielres/live_delegate"
    ]
  end

  def application, do: []

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:phoenix_live_view, "~> 1.2.0"}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/danielres/live_delegate"}
    ]
  end
end
