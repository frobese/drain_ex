defmodule Stormex.Application do
  use Application

  def start(_type, _args) do
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: Stormex.Discover.Supervisor},
      {Registry, keys: :unique, name: Stormex.Discover.Registry}
    ]

    opts = [strategy: :one_for_one, name: Stormex.Supervisor]
    Supervisor.start_link(children, opts)
  after
    if(Stormex.Discover.autostart?(), do: Stormex.Discover.start())
  end
end
