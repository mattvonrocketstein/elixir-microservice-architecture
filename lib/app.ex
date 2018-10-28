
defmodule App do
  @moduledoc """
  """
  use Application

  def start(_type, _args) do
    App.start()
  end

  def start() do
    Cluster.summary()
    Application.ensure_all_started(:sidetask)
    SideTask.add_resource(:registration_loop, 1)
    SideTask.add_resource(:join_loop, 1)
    SideTask.add_resource(:worker_loop, 1)

    {:ok, _pid} = Cluster.start_link()
    SideTask.start_child(:worker_loop, &Worker.worker_loop/0)
    SideTask.start_child(:registration_loop, &Worker.registration_loop/0)
    SideTask.start_child(:join_loop, &Worker.connection_loop/0)
  end
end
