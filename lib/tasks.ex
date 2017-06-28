import Supervisor.Spec
defmodule Mix.Tasks.Start do
  defmodule Shell do
    @moduledoc """
    """
    use Mix.Task
    def run(_) do
      Apex.ap {:starting_app,App.start()}
      IO.puts("task done")
      require IEx
      IEx.pry()
    end
  end
  defmodule Evm do
    @moduledoc """
    """
    use Mix.Task
    def run(_) do
      App.start()
      receive do
        {:waitForever}  -> nil
      end
    end
  end
  defmodule Sysmon do
    @moduledoc """
    """
    use Mix.Task
    def run(_) do
      Application.ensure_all_started(:cluster)
      Application.ensure_all_started(:consolex)
      children = [
         supervisor(Task.Supervisor, [[name: Sysmon.TaskSupervisor, restart: :permanent]]),
      ]
      {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)
      {:ok, _pid} = Task.Supervisor.start_child(Sysmon.TaskSupervisor, &loop/0)
      receive do
        {:waitForever}  -> nil
      end
    end
    defp loop() do
      pid = Process.whereis(Cluster)
      Apex.ap "Cluster registry:"
      Apex.ap(Cluster.members(pid))
      Apex.ap "Cluster members:"
      Apex.ap(Node.list())
      :timer.sleep(2000)
      loop()
    end
  end
end
