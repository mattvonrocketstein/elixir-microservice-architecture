require Logger

defmodule Cluster do
  @moduledoc """
  """

  @max_members 999
  @redis_ttl System.get_env("REDIS_TTL") || "6"
  @redis_host System.get_env("REDIS_HOST") || "redis"
  @redis_port String.to_integer(System.get_env("REDIS_PORT") || "6379")

  def pid(), do: Process.whereis(__MODULE__)

  def summary do
    Functions.report("Node: " <> Functions.red(Atom.to_string(Node.self())))
    Functions.report("Schedulers: #{:erlang.system_info(:schedulers)}")
    Functions.report("Redis host: " <> Functions.red(@redis_host))
    Functions.report("Redis port: " <> Functions.red(@redis_port))
  end

  def start_link do
    {:ok, _conn} = Redix.start_link(
      "redis://#{@redis_host}:#{@redis_port}/", name: __MODULE__,)
  end

  @doc """
  """
  def join() do
   pid = Cluster.pid()
   Functions.report("Sending Heartbeat for #{Node.self|>Atom.to_string}")
   this_name = Node.self() |> Atom.to_string
   Redix.command(pid,
         [ "SETEX", this_name,
           @redis_ttl,
           this_name, ])
  end

  @doc """
  Should not be used in production.. see https://redis.io/commands/keys
  """
  def keys() do
    pid = Cluster.pid()
    case Redix.command(pid, ["KEYS", "*"]) do
     {:error, _ } ->
       []
     {:ok, keys} ->
       Enum.map(keys, &String.to_atom/1)
    end
  end

  @doc """
  """
  def members() do
    index = 0
    count = @max_members
    pid = Cluster.pid()
    case Redix.command(pid, ["SCAN", index, "MATCH", "[^_]*", "COUNT", count]) do
      {:error, _ } ->
        [] #members(cluster)
      {:ok, [_given_index, member_data]} ->
        Enum.map(member_data, &String.to_atom/1)
    end
  end
end
