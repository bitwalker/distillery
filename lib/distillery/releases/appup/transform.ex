defmodule Distillery.Releases.Appup.Transform do
  @moduledoc """
  A transform is an appup compilation pass which receives a list of appup instructions,
  along with metadata about those instructions, such as the source application,
  the source and target versions involved, and an optional list of configuration options
  for the transform.

  The job of a transform is to, well, apply a transformation to the instruction set, in
  order to accomplish some objective that one desires to be automated. A trivial example
  of one such transform would be a transform which ensures the purge mode is set to `:soft_purge`
  for all `:update` instructions. To see an example of such a transform, look in `test/support/purge_transform.ex`
  """
  alias Distillery.Releases.Appup
  alias Distillery.Releases.Appup.Utils
  alias Distillery.Releases.Appup.TransformError

  @type app :: Appup.app()
  @type version :: Appup.appup_ver()
  @type options :: [term]
  @type instruction :: Appup.instruction()
  @type transform :: module | {module, options}

  @callback up(app, version, version, [instruction], options) :: [instruction]
  @callback down(app, version, version, [instruction], options) :: [instruction]

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)

      @impl unquote(__MODULE__)
      def up(_app, _v1, _v2, instructions, _opts) do
        instructions
      end

      @impl unquote(__MODULE__)
      def down(_app, _v1, _v2, instructions, _opts) do
        instructions
      end

      defoverridable up: 5, down: 5
    end
  end

  @doc """
  Applies all transforms against the current upgrade instruction.

  Additional information required as arguments and passed to transforms are
  the app the instruction applies to, and the source and target versions involved.
  """
  @spec up([instruction], app, version, version, [transform]) :: [instruction]
  def up(instructions, _app, _v1, _v2, []) do
    instructions
  end

  def up(instructions, app, v1, v2, [mod | rest]) when is_atom(mod) do
    up(instructions, app, v1, v2, [{mod, []} | rest])
  end

  def up(instructions, app, v1, v2, [{mod, opts} | rest]) when is_atom(mod) and is_list(opts) do
    case mod.up(app, v1, v2, instructions, opts) do
      ixs when is_list(ixs) ->
        # Validate
        validate_instructions!(mod, :up, ixs)
        up(ixs, app, v1, v2, rest)

      invalid ->
        # Invalid return value
        raise TransformError, module: mod, callback: :up, error: {:invalid_return, invalid}
    end
  end

  @doc """
  Applies all transforms against the current downgrade instruction.

  Additional information required as arguments and passed to transforms are
  the app the instruction applies to, and the source and target versions involved.
  """
  @spec down([instruction], app, version, version, [transform]) :: [instruction]
  def down(instructions, _app, _v1, _v2, []) do
    instructions
  end

  def down(instructions, app, v1, v2, [mod | rest]) when is_atom(mod) do
    down(instructions, app, v1, v2, [{mod, []} | rest])
  end

  def down(instructions, app, v1, v2, [{mod, opts} | rest]) do
    case mod.down(app, v1, v2, instructions, opts) do
      ixs when is_list(ixs) ->
        # Validate
        validate_instructions!(mod, :down, ixs)
        down(ixs, app, v1, v2, rest)

      invalid ->
        # Invalid return value
        raise TransformError, module: mod, callback: :down, error: {:invalid_return, invalid}
    end
  end

  defp validate_instructions!(mod, type, ixs) do
    case Utils.validate_instructions(ixs) do
      :ok ->
        :ok

      {:invalid, i} ->
        raise TransformError, module: mod, callback: type, error: {:invalid_instruction, i}
    end
  end
end
