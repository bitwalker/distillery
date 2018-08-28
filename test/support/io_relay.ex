defmodule IORelay do
  @moduledoc false
  
  defstruct [:output, :device]

  def new(device) do
    %__MODULE__{output: "", device: device}
  end

  defimpl Collectable do
    def into(relay) do
      collector = fn 
        %{output: output, device: d} = relay, {:cont, content} -> 
          IO.write(d, content)
          %{relay | output: output <> content}
        relay, :done ->
          relay
        _, :halt ->
          :ok
      end
      {relay, collector}
    end
  end
end
