use Mix.Config
IO.puts "loading config/sysmon.exs.."
config :logger,
  backends: [:console],
  compile_time_purge_level: :error
