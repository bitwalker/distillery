defmodule StandardApp.A do
  use GenServer

  def push(item), do: GenServer.call(__MODULE__, {:push, item})
  def pop, do: GenServer.call(__MODULE__, :pop)
  def length, do: GenServer.call(__MODULE__, :length)
  def inspect, do: GenServer.call(__MODULE__, :state)
  def version do
    case GenServer.call(__MODULE__, :state) do
      {v, _} ->
        {:ok, v}
    end
  end

  def start_link(), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    {:ok, {1, []}}
  end

  def handle_call({:push, item}, _from, {v, state}) do
    {:reply, :ok, {v, [item | state]}}
  end

  def handle_call(:pop, _from, {_, []} = state) do
    {:reply, {:ok, nil}, state}
  end

  def handle_call(:pop, _from, {v, [h | rest]}) do
    {:reply, {:ok, h}, {v, rest}}
  end

  def handle_call(:length, _from, {v, state}) do
    {:reply, length(state), {v, state}}
  end
  
  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  def code_change({:down, _oldvsn}, {v, acc}, _extra) do
    {:ok, {v - 1, acc}}
  end

  def code_change(_oldvsn, {v, acc}, _extra) do
    {:ok, {v + 1, acc}}
  end
end
