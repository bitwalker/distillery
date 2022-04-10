defmodule StandardApp.B do
  def push(item), do: do_call({:push, item})
  def pop, do: do_call(:pop)
  def length, do: do_call(:length)
  def inspect, do: do_call(:state)
  def version do
    case do_call(:state) do
      {v, _} ->
        {:ok, v}
    end
  end

  defp do_call(message) do
    send(__MODULE__, {self(), message})

    receive do
      reply -> reply
    after
      5_000 ->
        {:error, :timeout}
    end
  end

  def start_link() do
    :proc_lib.start_link(__MODULE__, :init, [self()])
  end

  def init(parent) do
    Process.register(self(), __MODULE__)
    Process.flag(:trap_exit, true)
    :proc_lib.init_ack(parent, {:ok, self()})
    debug = :sys.debug_options([])
    loop({1, []}, parent, debug)
  end

  defp loop({v, acc}, parent, debug) do
    receive do
      {from, {:push, item}} ->
        send(from, :ok)
        loop({v, [item | acc]}, parent, debug)

      {from, :pop} ->
        case acc do
          [] ->
            send(from, {:ok, nil})
            loop({v, acc}, parent, debug)

          [h | rest] ->
            send(from, {:ok, h})
            loop({v, rest}, parent, debug)
        end

      {from, :length} ->
        send(from, length(acc))

      {from, :state} ->
        send(from, {v, acc})

      {:system, from, req} ->
        :sys.handle_system_msg(req, from, parent, __MODULE__, debug, {v, acc})

      {:EXIT, ^parent, reason} ->
        exit(reason)

      msg ->
        IO.inspect(msg)
        loop({v, acc}, parent, debug)
    end
  end

  def system_continue(parent, debug, state) do
    loop(state, parent, debug)
  end

  def system_terminate(reason, _parent, _debug, _state) do
    exit(reason)
  end

  def system_get_state(state) do
    {:ok, state}
  end

  def system_replace_state(state_fun, state) do
    new_state = state_fun.(state)
    {:ok, new_state, new_state}
  end

  def system_code_change({v, acc}, _module, {:down, _}, _extra) do
    {:ok, {v - 1, acc}}
  end

  def system_code_change({v, acc}, _module, _oldvsn, _extra) do
    {:ok, {v + 1, acc}}
  end
end
