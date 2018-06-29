defmodule CtrlApp.Worker do
  use GenServer

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)
  def init(_), do: {:ok, nil}

  def terminate(reason, _state) do
    IO.puts("Terminating #{__MODULE__} with reason: #{inspect(reason)}")
  end
end
