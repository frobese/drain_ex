defmodule Stormex.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Stormex.Discover, []},
      {Registry, keys: :unique, name: Stormex.Link.Registry}
    ]

    opts = [strategy: :one_for_one, name: Stormex.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
