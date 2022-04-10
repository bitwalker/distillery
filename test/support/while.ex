defmodule LanguageExtensions.While do
  @moduledoc """
  Adds support for `while` to Elixir.

  See the docs for `#{__MODULE__}.while/2` for more information.

  ## Example

      use #{__MODULE__}

      ...

      while n = 1, n < 5 do n ->
        if n == 4 do
          break
        end
        :timer.sleep(1_000)
        n + 1
      after
        5_000 ->
          :timeout
      end
  """

  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
    end
  end

  @doc """
  Intended for use within `while`, this will break out of iteration,
  returning the last accumulator value as the result of the `while` expression.

      iex> while true do break end
      :ok
  end
  """
  defmacro break do
    quote do
      throw({unquote(__MODULE__), :break})
    end
  end

  @doc """
  A looping construct, looks like so:

      # Simple infinite loop (never terminates)
      while true do
        :ok
      end

      # Loop with accumulator
      iex> while n = 1, n < 5 do n -> n + 1 end
      5

      # Loop with timeout condition
      iex> while true do
      ...>   :ok
      ...> after
      ...>   1_000 ->
      ...>     :timeout
      ...> end
      :timeout

      # Loop with timeout and accumulator
      iex> while n = 1, n < 5 do
      ...>   if n == 4 do
      ...>     break
      ...>   end
      ...>   :timer.sleep(1_000)
      ...>    n + 1
      ...> after
      ...>   5_000 ->
      ...>     :timeout
      ...> end
      4

      # Loop with timeout condition but no body (exits with :timeout)
      iex> while true do after 1_000 -> :timeout end
      :timeout
  """
  # A simple while loop
  defmacro while(predicate, do: block) do
    quote location: :keep do
      while(_ = :ok, unquote(predicate), do: unquote(block), after: nil)
    end
  end

  # A loop + timeout block
  defmacro while(predicate, do: block, after: after_block) do
    quote location: :keep do
      while(_ = :ok, unquote(predicate), do: unquote(block), after: unquote(after_block))
    end
  end

  # An accumulator loop
  defmacro while(init, predicate, do: block) do
    quote location: :keep do
      while(unquote(init), unquote(predicate), do: unquote(block), after: nil)
    end
  end

  # An accumulator loop + timeout block
  defmacro while(init, predicate, do: block, after: after_block) do
    # Validate initializer
    {init_name, init_expr} =
      case init do
        {:=, env, [init_name | init_expr]} ->
          {init_name, {:__block__, env, init_expr}}

        {_, env, _} ->
          raise CompileError,
            description:
              "expected an initializer of the form `n = <expr>`, got: #{Macro.to_string(init)}",
            file: Keyword.get(env, :file, __ENV__.file),
            line: Keyword.get(env, :line, __ENV__.line)
      end

    # Validate and extract timeout/after body
    # Timeout must be a positive integer
    # After body only allows one timeout clause
    {timeout, after_block} =
      case after_block do
        [{:->, _, [[timeout], after_body]}] when is_integer(timeout) and timeout >= 0 ->
          {timeout, after_body}

        [{:->, env, [[_], _after_body]}] ->
          raise CompileError,
            description: "expected a positive integer timeout in `after`",
            file: Keyword.get(env, :file, __ENV__.file),
            line: Keyword.get(env, :line, __ENV__.line)

        [{:->, env, _}, _ | _] ->
          raise CompileError,
            description: "multiple timeouts are not supported in `after`",
            file: Keyword.get(env, :file, __ENV__.file),
            line: Keyword.get(env, :line, __ENV__.line)

        [{_, env, _} | _] ->
          raise CompileError,
            description: "multiple timeouts are not supported in `after`",
            file: Keyword.get(env, :file, __ENV__.file),
            line: Keyword.get(env, :line, __ENV__.line)

        nil ->
          {nil, :ok}
      end

    # Determine the type of while block we're building
    {block_type, block} =
      case block do
        # Empty block, i.e. `while true do after ... end`
        {:__block__, _, []} ->
          {:empty, :ok}

        # Has one or more accumulator patterns
        [{:->, _, [[_binding], _body]} | _] = blk ->
          {:acc, blk}

        # No accumulator
        _other ->
          {:noacc, block}
      end

    timeout_calc =
      if is_nil(timeout) do
        quote location: :keep, generated: true do
          now = start_time
        end
      else
        quote location: :keep, generated: true do
          now = System.monotonic_time(:millisecond)
          elapsed = now - start_time
          after_time = after_time - elapsed
        end
      end

    # Construct the body of the function
    body =
      case block_type do
        # If there is no `do` body, then skip it entirely
        :empty ->
          quote location: :keep, generated: true do
            if unquote(predicate) do
              import unquote(__MODULE__), only: [break: 0]
              unquote(timeout_calc)
              f.(after_time, now, :ok, f)
            else
              :ok
            end
          end

        # If we're not accumulating, skip the unnecessary pattern match
        # we need when managing the accumulator
        :noacc ->
          quote location: :keep, generated: true do
            if unquote(predicate) do
              import unquote(__MODULE__), only: [break: 0]
              acc2 = unquote(block)
              unquote(timeout_calc)
              f.(after_time, now, acc2, f)
            else
              acc
            end
          end

        # If we're managing an accumulator, we need to use the case
        # statement to
        :acc ->
          quote location: :keep, generated: true do
            unquote(init_name) = acc

            if unquote(predicate) do
              import unquote(__MODULE__), only: [break: 0]

              acc2 =
                case unquote(init_name) do
                  unquote(block)
                end

              unquote(timeout_calc)
              f.(after_time, now, acc2, f)
            else
              acc
            end
          end
      end

    # Construct the actual function, tag the quoted AST with
    # generated: true to make sure unused bindings and such are
    # not warned
    quote location: :keep, generated: true do
      fun = fn
        # Since nil is always > 0 due to Erlang sort order
        # We can use this to represent both infinite timeouts, and
        # finite timeouts which haven't expired
        after_time, start_time, acc, f when after_time > 0 ->
          try do
            unquote(body)
          catch
            :throw, {unquote(__MODULE__), :break} ->
              acc
          end

        _after_time, _start_time, acc, _f ->
          try do
            unquote(after_block)
          catch
            :throw, {unquote(__MODULE__), :break} ->
              acc
          end
      end

      now = System.monotonic_time(:millisecond)
      fun.(unquote(timeout), now, unquote(init_expr), fun)
    end
  end
end
