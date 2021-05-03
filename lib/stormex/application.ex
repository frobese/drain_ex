defmodule Stormex.Application do
  use Application

  def start(_type, _args) do
    DynamicSupervisor.start_link(strategy: :one_for_one, name: Stormex.Supervisor)
  end
end
