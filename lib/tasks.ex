#import Supervisor.Spec
defmodule Mix.Tasks.Start do

  defmodule Node do
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
end

defmodule Mix.Tasks.Start.Api do
  @moduledoc """
  """
  use Mix.Task
  def run(_) do
    Application.ensure_all_started(:ranch)
    Application.ensure_all_started(:cowboy)
    API.Server.start()
    receive do
      {:waitForever}  -> nil
    end
  end
end

defmodule Mix.Tasks.Start.Sysmon do
  @moduledoc """
  """
  use Mix.Task

  def run(_) do
    Application.ensure_all_started(:cluster)
    SideTask.add_resource(:sysmon_loop, 1)
    {:ok, _pid} = SideTask.start_child(:sysmon_loop, &loop/0)
    receive do
      {:waitForever} -> nil
    end
  end

  defp loop() do
    Apex.ap "Cluster registry:"
    Apex.ap(Cluster.members())
    Apex.ap "Cluster members:"
    Apex.ap(Node.list())
    :timer.sleep(2000)
    loop()
  end
end
