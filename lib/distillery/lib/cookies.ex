defmodule Distillery.Cookies do
  @moduledoc false

  @doc """
  Returns true if the crypto application is available, otherwise false
  """
  @spec can_generate_secure_cookie?() :: boolean
  def can_generate_secure_cookie?, do: match?({:module, _}, Code.ensure_loaded(:crypto))

  @doc """
  Gets a new cookie for the current project.
  """
  @spec get() :: atom
  def get do
    if can_generate_secure_cookie?() do
      generate()
    else
      # When the :crypto module is unavailable, rather than generating
      # a cookie guessable by a computer, produce this obviously
      # insecure cookie. A warning will be emitted every time
      # it is used (i.e. when vm.args is being generated with it).
      :insecure_cookie_in_distillery_config
    end
  end

  @doc """
  Generates a secure cookie based on `:crypto.strong_rand_bytes/1`.
  """
  @spec generate() :: atom
  def generate do
    Stream.unfold(nil, fn _ -> {:crypto.strong_rand_bytes(1), nil} end)
    |> Stream.filter(fn <<b>> -> b >= ?! && b <= ?~ end)
    # special when erlexec parses vm.args
    |> Stream.reject(fn <<b>> -> b in [?-, ?+, ?', ?\", ?\\, ?\#, ?,] end)
    |> Enum.take(64)
    |> Enum.join()
    |> String.to_atom()
  end
end
