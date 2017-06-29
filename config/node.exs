use Mix.Config
IO.puts "loading config/node.exs.."

# FIXME: logger config is completely ignored.  wtf?
config :logger,
  backends: [:console], # default, support for additional log sinks
  level: :info,
  compile_time_purge_level: :info, # purges logs with lower level than this
  format: "zzzzz$time $node $metadata[$level] $levelpad$message\n"
