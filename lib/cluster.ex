require Logger
import Supervisor.Spec

defmodule App do
  @moduledoc """
  """
  use Application

  def start(_type, _args) do
    App.start()
  end

  def start() do
    Cluster.summary()

    {:ok, redis_pid} = Cluster.start_link()
    children = [
      supervisor(Task.Supervisor, [[name: Cluster.TaskSupervisor, restart: :permanent]]),
    ]
    {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_all)
    {:ok, _pid} = Task.Supervisor.start_child(
      Cluster.TaskSupervisor, fn ->
        Apex.ap "Beginning loop for registration.."
        EVM.registration_loop(redis_pid)
      end)
      {:ok, _pid} = Task.Supervisor.start_child(
        Cluster.TaskSupervisor, fn ->
          Apex.ap "Beginning loop for cluster-join.."
          EVM.connection_loop(redis_pid)
        end)
  end
end
defmodule EVM do

  @heartbeat_delta 3000 # String.to_integer(@redis_ttl*1000) - 2000

  @doc """
  Establish connections between myself and known Elixir VMs
  """
  def connection_loop(cluster) do
    members = Enum.filter(Cluster.members(cluster), fn x -> x != Node.self() end)
    #Logger.info("Connecting to #{members}")
    Enum.each(members, fn m -> Node.connect(m) end)
    :timer.sleep(@heartbeat_delta)
    EVM.connection_loop(cluster)
  end

  @doc """
  Heartbeat.  We write into the registration repeatedly to
  indicate EVM is live, because entries in registration all
  get TTLs
  """
  def registration_loop(cluster) do
    Cluster.join(cluster)
    :timer.sleep(@heartbeat_delta)
    EVM.registration_loop(cluster)
  end
end
defmodule Cluster do
  @moduledoc """
  """

  @redis_ttl System.get_env("REDIS_TTL") || "6"
  @redis_host System.get_env("REDIS_HOST") || "redis"
  @redis_port String.to_integer(System.get_env("REDIS_PORT") || "6379")
  @max_members 999

  def summary do
    Apex.ap "Node: " <> Functions.red(Atom.to_string(Node.self()))
    Apex.ap "Redis host: " <> Functions.red(@redis_host)
    Apex.ap "Redis port: " <> Functions.red(@redis_port)
  end

  def start_link do
    {:ok, conn} = Redix.start_link(
      host: @redis_host,
      port: @redis_port)
   Agent.start_link(fn -> conn end, name: __MODULE__)
 end

 @doc """
 """
 def join(cluster) do
   Logger.info "Sending Heartbeat for #{Node.self|>Atom.to_string}"
    Agent.get(cluster, fn conn ->
      this_name = Node.self() |> Atom.to_string
      Redix.command(conn,
        [ "SETEX", this_name,
          @redis_ttl,
          this_name, ]) end)
  end

  @doc """
  """
  def members(cluster) do
    index = 0
    count = @max_members
    Agent.get(cluster, fn conn ->
      case Redix.command(conn, ["SCAN", index, "COUNT", count]) do
        {:error, _ } ->
          :timer.sleep(1000)
          [] #members(cluster)
        {:ok, [_given_index, member_data]} ->
          Enum.map(member_data, &String.to_atom/1)
      end
    end)
  end
end
