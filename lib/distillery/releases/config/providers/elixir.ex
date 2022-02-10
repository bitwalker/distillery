defmodule Distillery.Releases.Config.Providers.Elixir do
  @moduledoc """
  Provides support for `Mix.Config` config scripts, e.g. `config.exs`

  This provider expects a path to a config file to load during boot as an argument:

      set config_providers: [
        {Distillery.Releases.Config.Providers.Elixir, ["${RELEASE_ROOT_DIR}/config.exs"]}
      ]

  The above configuration goes in a `release` or `environment` definition in `rel/config.exs`,
  and will result in the given path being expanded during boot, and evaluated using `Mix.Config`.

  ## Caveats

  Because much of Mix assumes it is operating in a Mix project context, there are some things you
  need to be aware of when using `Mix.Config` in releases:

    * `Mix` APIs, other than `Mix.Config` itself, are not guaranteed to work, and most do not. This
      provider starts Mix when the provider runs, so you can call `Mix.env`, but it is an exception
      to the rule. Other functions are unlikely to work, so you should not rely on them being available.
    * `Mix.env` always returns `:prod`, unless `MIX_ENV` is exported in the environment, in which case
      that value is used instead.
    * The Mix project context is unavailable, as is your build environment, so Mix configs which invoke
      `git` or otherwise depend on that context, are not going to work. You need to use configs which are
      pared down to only reference the target environment (in general configs should be small anyway).
  """

  use Distillery.Releases.Config.Provider

  @impl Provider
  def init([path]) do
    # Start Mix if not started to allow calling Mix APIs
    started? = List.keymember?(Application.started_applications(), :mix, 0)

    unless started? do
      :ok = Application.start(:mix)
      # Always set MIX_ENV to :prod, unless otherwise given
      env = System.get_env("MIX_ENV") || "prod"
      System.put_env("MIX_ENV", env)
      Mix.env(String.to_atom(env))
    end

    try do
      with {:ok, path} <- Provider.expand_path(path) do
        path
        |> eval!()
        |> merge_config()
        |> Application.put_all_env()
      else
        {:error, reason} ->
          exit(reason)
      end
    else
      _ ->
        :ok
    after
      unless started? do
        # Do not leave Mix started if it was started here
        # The boot script needs to be able to start it
        :ok = Application.stop(:mix)
      end
    end
  end

  def merge_config(runtime_config) do
    Enum.flat_map(runtime_config, fn {app, app_config} ->
      all_env = Application.get_all_env(app)
      Config.Reader.merge([{app, all_env}], [{app, app_config}])
    end)
  end

  @doc false
  def eval!(path, imported_paths \\ [])

  Code.ensure_loaded(Mix.Config)

  if function_exported?(Mix.Config, :eval!, 2) do
    def eval!(path, imported_paths) do
      {config, _} = Config.Reader.read_imports!(path, imported_paths)
      config
    end
  else
    def eval!(path, imported_paths), do: Mix.Config.read!(path, imported_paths)
  end
end
