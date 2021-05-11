defmodule Stormex.Discover do
  use GenServer

  require Logger

  alias Stormex.Config

  defmodule Beacon do
    defstruct [:host, :port, :iid, :group, :first_seen, :last_seen]
  end

  defstruct [:config, :socket, :beacons]

  def beacons() do
    GenServer.call(__MODULE__, :beacons)
  end

  def start_link(_args) do
    GenServer.start_link(__MODULE__, Config.get(), name: __MODULE__)
  end

  def init(%Config{connection: %Config.Connection{discover_mode: :static}}) do
    :ignore
  end

  @impl true
  def init(config) do
    case :gen_udp.open(0, [:binary, {:active, true}, {:broadcast, true}]) do
      {:ok, socket} ->
        {:ok, %__MODULE__{socket: socket, config: config, beacons: %{}}, {:continue, :discover}}

      {:error, reason} ->
        Logger.error(":gen_udp.open failed with: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_continue(:discover, state) do
    case :gen_udp.send(
           state.socket,
           state.config.connection.params[:discover_addr],
           state.config.connection.params[:discover_port],
           locator(state.config.group)
         ) do
      :ok ->
        Process.send_after(self(), :discover, state.config.connection.params[:discover_interval])
        {:noreply, state}

      {:error, reason} ->
        Logger.error(":gen_udp.send failed with: #{inspect(reason)}")
        :gen_udp.close(state.socket)
        {:stop, reason}
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
    beacon = parse_udp_msg!(udp)
    now = :os.system_time()

    new_map =
      if Map.has_key?(state.beacons, beacon.iid) do
        {_, return} =
          Map.get_and_update!(state.beacons, beacon.iid, fn %Beacon{} = old ->
            {old, %Beacon{old | last_seen: now, host: beacon.host, port: beacon.port}}
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

  defp parse_udp_msg!(
         {:udp, _socket, host, _bport,
          <<"DRA", 1, group::binary-size(8), iid::binary-size(8), port::16>>}
       ) do
    %Beacon{host: host, port: port, iid: iid, group: group}
  end

  defp parse_udp_msg!(_) do
    raise(ArgumentError, "Can't parse udp_message into a beacon")
  end

  defp locator(group) do
    [
      <<"DRA", 1>>,
      format_group(group),
      # iid 0
      <<0::64>>,
      # port 0
      <<0::16>>
    ]
  end

  defp format_group(group) do
    group
    |> to_string()
    |> String.pad_trailing(8, "_")
    |> String.slice(0, 8)
  end
end
