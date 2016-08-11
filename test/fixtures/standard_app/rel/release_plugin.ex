defmodule SampleApp.ReleasePlugin do
  use Mix.Releases.Plugin

  def before_assembly(_), do: info("Release Plugin - before_assembly") && nil
  def after_assembly(_), do: info("Release Plugin - after_assembly") && nil

  def before_package(_), do: info("Release Plugin - before_package") && nil
  def after_package(_), do: info("Release Plugin - after_package") && nil
 def after_cleanup(_), do: info("Release Plugin - after_cleanup") && nil
end
