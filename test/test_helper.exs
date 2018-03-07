if System.get_env("VERBOSE_TESTS") do
  IO.puts "Working directory for tests is: #{File.cwd!}"
end
ExUnit.start()
