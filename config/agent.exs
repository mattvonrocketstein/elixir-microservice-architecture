use Mix.Config
IO.puts "loading config/node.exs.."
config :logger,
  backends: [:console], # default, support for additional log sinks
  level: :info,
  compile_time_purge_level: :info, # purges logs with lower level than this
  format: "zzzzz$time $node $metadata[$level] $levelpad$message\n"
