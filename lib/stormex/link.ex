defmodule Stormex.Link do
  use GenServer

  require Logger

  alias Stormex.Protocol

  defstruct [:args, :target, :socket, handshake: false]

  @handshake_timeout 5_000

  @default_args [
    discover: true,
    # static_fallback: false,
    host: "localhost",
    port: 6986,
    group: "default",
    retries: 5
  ]

  def start(args \\ []) do
    merged_args = args(args)
    GenServer.start(__MODULE__, merged_args, Keyword.take(args, [:name]))
  end

  def start_link(args \\ []) do
    merged_args = args(args)
    GenServer.start_link(__MODULE__, merged_args, Keyword.take(args, [:name]))
  end

  defp args(args) do
    args =
      @default_args
      |> Keyword.merge(Application.get_all_env(:drain))
      |> Keyword.merge(args)
      |> Keyword.take(Keyword.keys(@default_args))

    Logger.warn("Link Keyword.merge #{inspect(args)}")
    args
  end

  @impl true
  def init(args) do
    {host, port} = endpoint = endpoint(args)

    retries = args[:retries]
    unless is_integer(retries), do: raise("The retries option must be an integer")

    Logger.info(["Connecting to ", host, ?:, Integer.to_string(port)])

    {:ok, %__MODULE__{target: args[:target], args: args},
     {:continue, {:connect, endpoint, retries}}}
  end

  @impl true
  def handle_continue({:connect, {host, port} = endpoint, retries}, %__MODULE__{} = state)
      when is_integer(retries) and retries > 0 do
    case :gen_tcp.connect(host, port, [:binary, packet: 4, active: true]) do
      {:ok, socket} ->
        Logger.debug(fn -> ["Connection established - id: ", inspect(socket)] end)
        Process.send_after(self(), :handshake_timeout, @handshake_timeout)
        {:noreply, %__MODULE__{state | socket: socket}}

      {:error, reason} ->
        Logger.error(["Drain TCP connection failed ", inspect(reason)])
        :timer.sleep(1000)

        {:noreply, %__MODULE__{state | socket: reason},
         {:continue, {:connect, endpoint, retries - 1}}}
    end
  end

  def handle_continue({:connect, _endpoint, _retries}, state) do
    {:stop, state.socket, state}
  end

  # Processes the incoming TCP frames
  @impl true
  def handle_info({:tcp, socket, packet}, state) do
    case Protocol.decode(packet) do
      {:ok, msg, _rest} ->
        # Some special cases...
        state =
          case msg do
            %Protocol.Hello{} = hello ->
              Logger.debug("Got hello from #{hello.ver}")
              %__MODULE__{state | handshake: true}

            %Protocol.Ping{} ->
              Logger.debug("Got ping, sending pong")
              packet = Protocol.encode(%Protocol.Pong{})
              :ok = :gen_tcp.send(socket, packet)
              state

            %{} ->
              Logger.debug("Got msg #{inspect(msg)}")
              state
          end

        # invoke_callback({:recv, msg}, state)
        {:noreply, %__MODULE__{state | socket: socket}}

      {:error, reason} ->
        Logger.warn("TCP frame error #{inspect(reason)}")
        {:noreply, %__MODULE__{state | socket: socket}}
    end
  end

  def handle_info({:tcp_error = error, _socket, reason}, state) do
    Logger.error("Connection failure: #{inspect(reason)}")
    reconnect(error, state)
  end

  def handle_info({:tcp_closed = error, _socket}, state) do
    Logger.warn("TCP connection closed")
    reconnect(error, state)
  end

  def handle_info(:handshake_timeout, %__MODULE__{handshake: false} = state) do
    Logger.error("Handshake timeout.")
    {:stop, :handshake_timeout, state}
  end

  def handle_info(:handshake_timeout, state) do
    {:noreply, state}
  end

  defp reconnect(error, state) do
    state = %__MODULE__{state | socket: error}

    {host, port} = endpoint = endpoint(state.args)
    retries = state.args[:retries]

    Logger.warn(["Reconnecting to ", host, ?:, Integer.to_string(port)])

    {:noreply, state, {:continue, {:connect, endpoint, retries}}}
  end

  defp endpoint(args) do
    with true <- args[:discover],
         {:ok, hostport} <- Stormex.Discover.discover() do
      hostport
    else
      _ ->
        {to_charlist(args[:host]), args[:port]}
    end
  end
end
