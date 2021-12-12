defmodule DrainEx.Link do
  use GenServer

  require Logger

  alias DrainEx.{Config, Protocol}

  defstruct [:callback, :config, :socket, handshake: false]

  def start_link(callback) when is_function(callback) do
    GenServer.start_link(__MODULE__, callback, [])
  end

  def start_link(_) do
    :ignore
  end

  @impl true
  def init(callback) do
    config = Config.fetch()

    {:ok, %__MODULE__{callback: callback, config: config},
     {:continue, {:connect, config.retries}}}
  end

  @impl true
  def handle_continue({:connect, retries}, state) when retries > 0 do
    {host, port} = endpoint(state.config.connection)

    case :gen_tcp.connect(host, port, [:binary, packet: 4, active: true]) do
      {:ok, socket} ->
        Logger.debug(fn -> ["Connection established - id: ", inspect(socket)] end)
        :ok = :gen_tcp.send(socket, Protocol.encode(%Protocol.Connect{}))
        Process.send_after(self(), :handshake_timeout, state.config.handshake_timeout)
        {:noreply, %__MODULE__{state | socket: socket}}

      {:error, reason} ->
        Logger.error(["Drain TCP connection failed ", inspect(reason)])
        Process.sleep(state.config.retries_interval)

        {:noreply, %__MODULE__{state | socket: reason}, {:continue, {:connect, retries - 1}}}
    end
  end

  def handle_continue({:connect, _retries}, state) do
    {:stop, state.socket, state}
  end

  # TODO does the cmd come from a registered process ?
  @impl true
  def handle_call(%{__struct__: struct} = cmd, _from, state)
      when struct in [
             Protocol.Pub,
             Protocol.ChkSub,
             Protocol.ChkDup,
             Protocol.Unsub,
             Protocol.Undup,
             Protocol.Sub,
             Protocol.Dup
           ] do
    {:reply, :gen_tcp.send(state.socket, Protocol.encode(cmd)), state}
  end

  @impl true
  def handle_info({:tcp, socket, packet}, state) do
    case Protocol.decode(packet) do
      {:ok, msg, _rest} ->
        # Some special cases...
        state =
          case msg do
            %Protocol.Info{} = info ->
              Logger.debug("Got info from #{info.ver}")
              %__MODULE__{state | handshake: true}

            %Protocol.Ping{} ->
              Logger.debug("Got ping, sending pong")
              packet = Protocol.encode(%Protocol.Pong{})
              :ok = :gen_tcp.send(socket, packet)
              state

            %{} ->
              Logger.debug("Got msg #{inspect(msg)}")
              apply(state.callback, [msg])
              state
          end

        {:noreply, %__MODULE__{state | socket: socket}}

      {:error, reason} ->
        Logger.warn("TCP frame error #{inspect(reason)}")
        {:noreply, %__MODULE__{state | socket: socket}}
    end
  end

  def handle_info({:tcp_error = error, _socket, reason}, state) do
    Logger.error("Connection failure: #{inspect(reason)}")
    {:noreply, %__MODULE__{state | socket: error}, {:continue, {:connect, state.config.retries}}}
  end

  def handle_info({:tcp_closed = error, _socket}, state) do
    Logger.warn("TCP connection closed")
    {:noreply, %__MODULE__{state | socket: error}, {:continue, {:connect, state.config.retries}}}
  end

  def handle_info(:handshake_timeout, %__MODULE__{handshake: false} = state) do
    Logger.error("Handshake timeout.")
    {:stop, :handshake_timeout, state}
  end

  def handle_info(:handshake_timeout, state) do
    {:noreply, state}
  end

  defp endpoint(%Config.Connection{} = conn) do
    {to_charlist(conn.params[:host]), conn.params[:port]}
  end
end
