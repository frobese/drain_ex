defmodule Stormex do
  # @spec subscribe(topic :: String.t()) :: :ok | :error
  def subscribe(_topic \\ "") do
    Stormex.Link.start_link(%Stormex.Link.Target{pid: self(), mode: :send})
  end

  def unsubscribe() do
    Registry.lookup(Stormex.Link.Registry, self())
    |> Enum.each(fn {pid, _topic} -> GenServer.stop(pid) end)
  end

  def unsubscribe(topic) do
    Registry.lookup(Stormex.Link.Registry, self())
    |> Enum.filter(fn {_, subbed_topic} -> topic == subbed_topic end)
    |> Enum.each(fn {pid, _topic} -> GenServer.stop(pid) end)
  end

  @spec which_subscriptions :: list(String.t())
  def which_subscriptions() do
    Registry.select(Stormex.Link.Registry, [{{:_, :_, :"$3"}, [], [:"$3"]}])
  end

  @spec which_subscriptions(pid()) :: list(String.t())
  def which_subscriptions(pid) when is_pid(pid) do
    Registry.lookup(Stormex.Link.Registry, pid)
    |> Enum.map(fn {_pid, topic} -> topic end)
  end

  def which_subscriptions(_pid) do
    raise ArgumentError
  end
end
