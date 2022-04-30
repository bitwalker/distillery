if System.get_env("VERBOSE_TESTS") do
  IO.puts "Working directory for tests is: #{File.cwd!}"
end
ExUnit.start(exclude: [:skip_2_2, :fail_2_2, :fail_action])
