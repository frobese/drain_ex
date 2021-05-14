defmodule Stormex do
  alias Stormex.Protocol

  def command(cmd, mode \\ :send)

  def command(%Protocol.Sub{} = cmd, mode) do
    subscription_link(cmd.topic, mode)
    |> GenServer.call(cmd)
  end

  def command(%{__struct__: struct} = cmd, mode)
      when struct in [
             Protocol.Pub,
             Protocol.Get,
             Protocol.List,
             Protocol.ChkSub,
             Protocol.ChkDup,
             Protocol.Unsub,
             Protocol.Undup,
             Protocol.Dup
           ] do
    command_link(mode)
    |> GenServer.call(cmd)
  end

  def publish(msg, topic \\ "", mode \\ :send) do
    command_link(mode)
    |> GenServer.call(%Stormex.Protocol.Pub{topic: topic, payload: msg})
  end

  # @spec subscribe(topic :: String.t()) :: :ok | :error
  def subscribe(topic \\ "", mode \\ :send) do
    subscription_link(topic, mode)
    |> GenServer.call(%Stormex.Protocol.Sub{topic: topic})
  end

  def unsubscribe() do
    which_subscriptions(self())
    |> Enum.each(fn {_, pid, _} -> GenServer.stop(pid) end)
  end

  def unsubscribe(topic) do
    which_subscriptions(self())
    |> Enum.filter(fn {_, _, subbed_topic} -> {:sub, topic} == subbed_topic end)
    |> Enum.each(fn {_, pid, _topic} ->
      Registry.unregister(Stormex.Link.Registry, pid)
      GenServer.stop(pid)
    end)
  end

  @spec which_subscriptions :: list(String.t())
  def which_subscriptions() do
    which_links()
    |> Enum.filter(&filter_sub/1)
  end

  @spec which_subscriptions(pid()) :: list(String.t())
  def which_subscriptions(pid) do
    which_links(pid)
    |> Enum.filter(&filter_sub/1)
  end

  def which_links() do
    Registry.select(Stormex.Link.Registry, [
      {{:"$1", :"$2", :"$3"}, [], [{{:"$2", :"$1", :"$3"}}]}
    ])
  end

  def which_links(pid) when is_pid(pid) do
    Registry.select(Stormex.Link.Registry, [
      {{:"$1", :"$2", :"$3"}, [{:==, :"$2", pid}], [{{:"$2", :"$1", :"$3"}}]}
    ])
  end

  def which_links(_) do
    []
  end

  defp command_link(mode) do
    which_links(self())
    |> Enum.filter(&filter_cmd/1)
    |> case do
      [] ->
        {:ok, pid} = Stormex.Link.start_link(callback(mode))
        Registry.register(Stormex.Link.Registry, pid, :cmd)
        pid

      [{_, pid, _} | _] ->
        pid
    end
  end

  defp subscription_link(topic, mode) do
    which_subscriptions(self())
    |> Enum.filter(fn {_, _, subbed_topic} -> {:sub, topic} == subbed_topic end)
    |> case do
      [] ->
        {:ok, pid} = Stormex.Link.start_link(callback(mode))
        Registry.register(Stormex.Link.Registry, pid, {:sub, topic})
        pid

      [{_, pid, _} | _] ->
        pid
    end
  end

  defp filter_sub({_, _, value}) do
    case value do
      {:sub, _} -> true
      _ -> false
    end
  end

  defp filter_cmd({_, _, value}) do
    case value do
      :cmd -> true
      _ -> false
    end
  end

  defp callback(mode) do
    case mode do
      :cast -> &cast_callback/1
      :call -> &call_callback/1
      _ -> &send_callback/1
    end
  end

  defp send_callback(msg) do
    case Registry.lookup(Stormex.Link.Registry, self()) do
      [{pid, _value}] ->
        Process.send(pid, msg, [])
        :ok

      [] ->
        {:error, :callback_failed}
    end
  end

  defp call_callback(msg) do
    case Registry.lookup(Stormex.Link.Registry, self()) do
      [{pid, _value}] ->
        GenServer.call(pid, msg)

      [] ->
        {:error, :callback_failed}
    end
  end

  defp cast_callback(msg) do
    case Registry.lookup(Stormex.Link.Registry, self()) do
      [{pid, _value}] ->
        GenServer.cast(pid, msg)

      [] ->
        {:error, :callback_failed}
    end
  end
end
