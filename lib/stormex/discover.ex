defmodule Stormex.Discover do
  require Logger

  @default_args [
    autostart: true,
    groups: [
      [group: "default"]
    ]
  ]

  def start() do
    Keyword.get(args([]), :groups)
    |> Enum.each(&start_group/1)
  end

  def stop() do
    DynamicSupervisor.stop(Stormex.Discover.Supervisor)
  end

  def beacons() do
    Registry.select(Stormex.Discover.Registry, [{{:_, :"$2", :_}, [], [:"$2"]}])
    |> Enum.map(&gather_beacons/1)
    |> List.flatten()
  end

  def beacons(group) do
    Registry.lookup(Stormex.Discover.Registry, group)
    |> Enum.map(fn {pid, _value} -> pid end)
    |> Enum.map(&gather_beacons/1)
    |> List.flatten()
  end

  def autostart?() do
    Keyword.get(args([]), :autostart)
  end

  defp gather_beacons(pid) do
    GenServer.call(pid, :beacons)
  end

  defp start_group(group_args) do
    DynamicSupervisor.start_child(
      Stormex.Discover.Supervisor,
      {Stormex.Discover.Server, group_args}
    )
  end

  defp args(args) do
    @default_args
    |> Keyword.merge(Application.get_env(:stormex, __MODULE__, []))
    |> Keyword.merge(args)
    |> Keyword.take(Keyword.keys(@default_args))
  end
end
