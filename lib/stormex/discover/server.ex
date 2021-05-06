defmodule Stormex.Discover.Server do
  use GenServer

  require Logger

  alias Stormex.Discover.Beacon

  @default_args [
    group: "default",
    broadcast_port: 5670,
    broadcast_addr: {255, 255, 255, 255},
    broadcast_interval: 1500,
    retries_max: 10,
    retries_intervall: 5000
  ]

  defstruct [:args, :socket, :retries, :retries_max, :beacons]

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args(args), [])
  end

  @impl true
  def init(args) do
    case Registry.register(Stormex.Discover.Registry, args[:group], nil) do
      {:ok, _} ->
        {:ok,
         %__MODULE__{
           args: args,
           retries: 0,
           retries_max: args[:retries_max],
           beacons: %{}
         }, {:continue, :init}}

      {:error, _} ->
        Logger.warn("Discovery is already running for group: #{inspect(args[:group])}")

        :ignore
    end
  end

  @impl true
  def handle_continue(:init, %__MODULE__{retries: retries, retries_max: retries_max} = state)
      when retries >= retries_max do
    Logger.error("Couldn't open an udp-port...terminating discovery")
    {:stop, :udp_error, state}
  end

  @impl true
  def handle_continue(:init, %__MODULE__{args: args, retries: retries} = state) do
    case :gen_udp.open(0, [:binary, {:active, true}, {:broadcast, true}]) do
      {:ok, socket} ->
        {:noreply, %__MODULE__{state | socket: socket, retries: 0}, {:continue, :discover}}

      {:error, reason} ->
        Logger.error("UDP-discovery failed with: #{inspect(reason)}")
        Process.sleep(args[:retries_intervall])
        {:noreply, %__MODULE__{state | socket: nil, retries: retries + 1}, {:continue, :init}}
    end
  end

  @impl true
  def handle_continue(:discover, %__MODULE__{args: args, socket: socket} = state) do
    case :gen_udp.send(
           socket,
           args[:broadcast_addr],
           args[:broadcast_port],
           Beacon.locator(args[:group])
         ) do
      :ok ->
        Process.send_after(self(), :discover, state.args[:broadcast_interval])
        {:noreply, state}

      {:error, reason} ->
        Logger.error("UDP-discovery failed with: #{inspect(reason)}")
        :gen_udp.close(socket)
        {:noreply, %__MODULE__{state | socket: nil}, {:continue, :init}}
    end
  end

  @impl true
  def handle_call(:beacons, _, state) do
    {:reply, Map.values(state.beacons), state}
  end

  @impl true
  def handle_call(msg, from, state) do
    Logger.warn("Ignored message #{inspect(msg)} from #{inspect(from)}")
    {:noreply, state}
  end

  @impl true
  def handle_info(:discover, state) do
    {:noreply, state, {:continue, :discover}}
  end

  @impl true
  def handle_info({:udp, _socket, _addr, _in_port, _packet} = udp, state) do
    beacon = Beacon.parse_udp_msg!(udp)
    now = :os.system_time()

    new_map =
      if Map.has_key?(state.beacons, beacon.iid) do
        {_, return} =
          Map.get_and_update!(state.beacons, beacon.iid, fn %Beacon{} = old ->
            {old, %Beacon{old | last_seen: now, addr: beacon.addr, port: beacon.port}}
          end)

        return
      else
        Map.put(state.beacons, beacon.iid, %Beacon{beacon | first_seen: now, last_seen: now})
      end

    {:noreply, %__MODULE__{state | beacons: new_map}}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.info("#{inspect(msg)}")
    {:noreply, state}
  end

  defp args(args) do
    @default_args
    |> Keyword.merge(args)
    |> Keyword.take(Keyword.keys(@default_args))
  end
end
