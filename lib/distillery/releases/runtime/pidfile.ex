defmodule Distillery.Releases.Runtime.Pidfile do
  @moduledoc """
  This is a kernel process which will maintain a pidfile for the running node
  """

  @doc false
  # Will be called by `:init`
  def start() do
    # We don't need to link to `:init`, it will take care
    # of linking to us, since we're being started as a kernel process
    pid = spawn(__MODULE__, :init, [self(), Process.whereis(:init)])

    receive do
      {:ok, ^pid} = ok ->
        ok

      {:ignore, ^pid} ->
        :ignore

      {:error, ^pid, reason} ->
        {:error, reason}
    end
  end

  @doc false
  def init(starter, parent) do
    me = self()

    case Application.get_env(:kernel, :pidfile, System.get_env("PIDFILE")) do
      nil ->
        # No config, so no need for this process
        send(starter, {:ignore, me})

      path when is_binary(path) or is_list(path) ->
        pid = :os.getpid()
        case :prim_file.write_file(path, List.to_string(pid)) do
          :ok ->
            # We've written the pid, so proceed
            Process.flag(:trap_exit, true)

            # Register
            Process.register(me, __MODULE__)

            # We're started!
            send(starter, {:ok, me})

            # Enter receive loop
            loop(%{pidfile: path}, starter, parent)

          {:error, reason} ->
            send(starter, {:error, me, {:invalid_pidfile, path, reason}})
        end

      path ->
        send(starter, {:error, me, {:invalid_pidfile_config, path}})
    end
  end

  defp loop(%{pidfile: path} = state, starter, parent) do
    receive do
      {:EXIT, pid, reason} when pid in [starter, parent] ->
        # Cleanup pidfile
        _ = :prim_file.delete(path)
        exit(reason)

      _ ->
        loop(state, starter, parent)
    after
      5_000 ->
        if exists?(path) do
          loop(state, starter, parent)
        else
          :init.stop()
        end
    end
  end

  defp exists?(path) do
    case :prim_file.read_file_info(path) do
      {:error, _} ->
        false
      {:ok, _info} ->
        true
    end
  end
end
