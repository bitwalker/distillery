defmodule SampleApp.AnotherReleasePlugin do
  use Mix.Releases.Plugin

  def before_assembly(_, _), do: info("Another Release Plugin - before_assembly") && nil
  def after_assembly(_, _), do: info("Another Release Plugin - after_assembly") && nil

  def before_package(_, _), do: info("Another Release Plugin - before_package") && nil
  def after_package(_, _), do: info("Another Release Plugin - after_package") && nil
  def after_cleanup(_, _), do: info("Another Release Plugin - after_cleanup") && nil
end
