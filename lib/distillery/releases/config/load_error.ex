defmodule Distillery.Releases.Config.LoadError do
  @moduledoc false
  defexception [:file, :error]

  def message(%__MODULE__{file: file, error: error}) do
    "could not load release config #{Path.relative_to_cwd(file)}\n    " <>
      "#{Exception.format_banner(:error, error)}"
  end
end
