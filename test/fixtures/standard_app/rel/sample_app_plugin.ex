defmodule SampleApp.ProdPlugin do
  use Mix.Releases.Plugin

  def before_assembly(_), do: info("Prod Plugin - before_assembly") && nil
  def after_assembly(_), do: info("Prod Plugin - after_assembly") && nil

  def before_package(_), do: info("Prod Plugin - before_package") && nil
  def after_package(_), do: info("Prod Plugin - after_package") && nil
  def after_cleanup(_), do: info("Prod Plugin - after_cleanup") && nil
end
