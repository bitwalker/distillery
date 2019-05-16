defmodule Distillery.Releases.BootScript do
  @moduledoc false

  alias Distillery.Releases.Release
  alias Distillery.Releases.Shell
  alias Distillery.Releases.Utils

  defstruct [
    :name,
    :options,
    :output_dir,
    :header,
    :instructions,
    :kernel_procs
  ]

  @type t :: %__MODULE__{
          name: charlist,
          options: [atom | {atom, term}],
          output_dir: String.t(),
          header: term,
          instructions: [term],
          kernel_procs: [term]
        }

  @doc """
  Create a new boot script from a Release
  """
  @spec new(Release.t()) :: {:ok, t} | {:error, term}
  def new(%Release{} = release) do
    rel_dir =
      release
      |> Release.version_path()

    rel_dir_cl = String.to_charlist(rel_dir)

    erts_lib_dir = erts_lib_dir(release)

    options = [
      {:path, [rel_dir_cl | Release.get_code_paths(release)]},
      {:outdir, rel_dir_cl},
      {:variables, [{'ERTS_LIB_DIR', erts_lib_dir}]},
      :no_warn_sasl,
      :no_module_tests,
      :silent
    ]

    options =
      if release.profile.no_dot_erlang do
        [:no_dot_erlang | options]
      else
        options
      end

    boot = %__MODULE__{
      name: Atom.to_charlist(release.name),
      options: options,
      output_dir: rel_dir,
      instructions: [],
      kernel_procs: []
    }

    create(boot)
  end

  @doc """
  Removes any application start instructions for apps other than those in the provided list
  """
  def start_only(%__MODULE__{instructions: ixns} = boot, apps) do
    new_ixns =
      Enum.reject(ixns, fn
        {:apply, {:application, :start_boot, [app | _]}} ->
          not Enum.member?(apps, app)

        _ ->
          false
      end)

    %__MODULE__{boot | instructions: new_ixns}
  end

  @doc """
  Add instructions after some application has been started
  """
  def after_started(%__MODULE__{instructions: ixns} = boot, app, instructions) do
    {before, [app_start | after_app]} =
      Enum.split_while(ixns, fn
        {:apply, {:application, :start_boot, [^app | _]}} ->
          false

        _ ->
          true
      end)

    %__MODULE__{boot | instructions: before ++ [app_start | instructions] ++ after_app}
  end

  @doc """
  Add a kernel process to be started as part of this boot script.
  """
  def add_kernel_proc(%__MODULE__{kernel_procs: kps} = boot, {m, _, _} = mfa, name \\ nil) do
    name =
      if is_nil(name) do
        m
      else
        name
      end

    %__MODULE__{boot | kernel_procs: [{:kernelProcess, name, mfa} | kps]}
  end

  @doc """
  Persists the boot script to disk in .script and .boot forms
  """
  @spec write(t) :: :ok | {:error, {:assembler, {:make_boot_script, term}}}
  @spec write(t, name :: atom) :: :ok | {:error, {:assembler, {:make_boot_script, term}}}
  def write(%__MODULE__{output_dir: output_dir} = boot, name \\ nil) do
    # Allow overriding name
    name =
      if is_nil(name) do
        boot.name
      else
        name
      end

    script_path = Path.join(output_dir, "#{name}.script")
    boot_path = Path.join(output_dir, "#{name}.boot")
    # Put script back together
    ixns = boot.instructions
    kernel_procs = Enum.reverse(boot.kernel_procs)

    with {before_app_ctrl, after_app_ctrl} <-
           Enum.split_while(ixns, fn
             {:progress, :init_kernel_started} ->
               false

             _ ->
               true
           end),
         script = {:script, boot.header, before_app_ctrl ++ kernel_procs ++ after_app_ctrl},
         # Write script to .script file
         :ok <- Utils.write_term(script_path, script),
         # Write binary script to .boot file
         :ok <- File.write(boot_path, :erlang.term_to_binary(script)) do
      :ok
    else
      {:error, reason} ->
        {:error, {:assembler, {:make_boot_script, reason}}}
    end
  end

  # Uses systools to generate the boot script data
  defp create(%__MODULE__{name: name, options: options} = boot) do
    case :systools.make_script(name, options) do
      :ok ->
        on_create(boot)

      {:ok, _, []} ->
        on_create(boot)

      {:ok, mod, warnings} ->
        Shell.warn(Utils.format_systools_warning(mod, warnings))
        on_create(boot)

      {:error, mod, errors} ->
        error = Utils.format_systools_error(mod, errors)
        {:error, {:assembler, {:make_boot_script, error}}}
    end
  end

  # Handle successful creation of the boot script
  defp on_create(%__MODULE__{output_dir: output_dir} = boot) do
    script_path = Path.join(output_dir, "#{boot.name}.script")
    boot_path = Path.join(output_dir, "#{boot.name}.boot")

    with {:ok, [{:script, {_relname, _relvsn} = header, ixns}]} <- Utils.read_terms(script_path),
         :ok = File.rm(script_path),
         :ok = File.rm(boot_path) do
      {:ok, %__MODULE__{boot | header: header, instructions: ixns}}
    else
      {:error, reason} ->
        {:error, {:assembler, {:make_boot_script, reason}}}
    end
  end

  defp erts_lib_dir(release) do
    case release.profile.include_erts do
      false ->
        :code.lib_dir()

      true ->
        :code.lib_dir()

      p ->
        String.to_charlist(Path.expand(Path.join(p, "lib")))
    end
  end
end
