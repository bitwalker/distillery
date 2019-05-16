defmodule Distillery.Releases.Checks.Cookie do
  @moduledoc """
  Runs some basic validation of the distribution cookie configuration
  """
  use Distillery.Releases.Checks

  alias Distillery.Releases.Release
  alias Distillery.Releases.Profile

  def run(%Release{profile: %Profile{cookie: nil}}) do
    warning =
      "Attention! You did not provide a cookie for the erlang distribution protocol in rel/config.exs\n" <>
        "    For backwards compatibility, the release name will be used as a cookie, which is potentially a security risk!\n" <>
        "    Please generate a secure cookie and use it with `set cookie: <cookie>` in rel/config.exs.\n" <>
        "    This will be an error in a future release."

    {:ok, warning}
  end

  def run(%Release{profile: %Profile{cookie: cookie}}) when is_atom(cookie) do
    if String.contains?(Atom.to_string(cookie), "insecure") do
      warning =
        "Attention! You have an insecure cookie for the erlang distribution protocol in rel/config.exs\n" <>
          "    This is probably because a secure cookie could not be auto-generated.\n" <>
          "    Please generate a secure cookie and use it with `set cookie: <cookie>` in rel/config.exs."

      {:ok, warning}
    else
      :ok
    end
  end
end
