defmodule SampleApp.EnvLoggerPlugin do
  use Distillery.Releases.Plugin
  
  def before_assembly(release, opts), do: log(release, opts, elem(__ENV__.function, 0))
  def after_assembly(release, opts), do: log(release, opts, elem(__ENV__.function, 0))
  def before_package(release, opts), do: log(release, opts, elem(__ENV__.function, 0))
  def after_package(release, opts), do: log(release, opts, elem(__ENV__.function, 0))
  def after_cleanup(release, opts), do: log(release, opts, elem(__ENV__.function, 0))
  
  defp log(%Distillery.Releases.Release{env: env}, opts, callback) do
    name = Keyword.get(opts, :name, __MODULE__)
    info("#{name} in #{env} executing #{callback}")
    nil
  end
end
