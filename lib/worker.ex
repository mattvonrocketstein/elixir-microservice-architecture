require Logger

defmodule Worker do

  @heartbeat_delta 3000 # String.to_integer(@redis_ttl*1000) - 2000
  @worker_delta 3000
  @max_workers 100

  @doc """
  Establish connections between myself and known Elixir VMs
  """
  def connection_loop() do
    members = Enum.filter(Cluster.members(), fn x -> x != Node.self() end)
    #Functions.report("Connecting to #{members}")
    Enum.each(members, fn m -> Node.connect(m) end)
    :timer.sleep(@heartbeat_delta)
    connection_loop()
  end

  @doc """
  Heartbeat.  We write into the registration repeatedly to
  indicate Worker is live, because entries in registration all
  get TTLs
  """
  def registration_loop() do
    Cluster.join()
    :timer.sleep(@heartbeat_delta)
    registration_loop()
  end

  @doc """
  """
  def worker_loop() do
    pid = Cluster.pid()
    {:ok, [_next_cursor, keys]} = Redix.command(
      pid,
      [ "SCAN", "0", "MATCH", "[_]*", "COUNT", @max_workers+1])
    Functions.report("Keys that represent work", keys)
    keys = Enum.drop_while(keys, fn k->
        # extremely inefficient, maybe use another redis
        #  instance or explore the redis-native hash type
        {:ok, data_string} = Redix.command(pid, ["GET", k])
        {:ok, data} = JSX.decode(data_string)
        # Functions.report("Key/Data: #{k} #{data}")
        # cannot use data.status here after deserializing!
        not String.equivalent?(data["status"], "pending")
      end)
    if Enum.empty?(keys) do
      Functions.report("No work found (or all available work is already in progress).")
    else
      key = Enum.at(keys, 0)
      value = Callback.get_data(key)
      Callback.write(key, "working", value)
      Functions.report("working", [key, value])
      :timer.sleep(1000)
      Callback.write(key, "worked", %{})
    end
    :timer.sleep(@worker_delta)
    worker_loop()
  end
end
