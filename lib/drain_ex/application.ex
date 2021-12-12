defmodule DrainEx.Application do
  use Application

  def start(_type, _args) do
    children = [
      {DrainEx.Discover, []},
      {Registry, keys: :unique, name: DrainEx.Link.Registry}
    ]

    opts = [strategy: :one_for_one, name: DrainEx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
