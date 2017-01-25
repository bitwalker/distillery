defmodule Mix.Releases.Config.LoadError do
  defexception [:file, :error]

  @spec message(%__MODULE__{}) :: String.t
  def message(%__MODULE__{file: file, error: error}) do
    "could not load release config #{Path.relative_to_cwd(file)}\n    " <>
      "#{Exception.format_banner(:error, error)}"
  end
end
