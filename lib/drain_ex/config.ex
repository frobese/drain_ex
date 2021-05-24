defmodule DrainEx.Config do
  defmodule Connection do
    defstruct [:discover_mode, :params]
  end

  @default_port [
    autostart: false,
    verbose: 0,
    dashboard: "0.0.0.0:8080",
    name: DrainEx.Port,
    exe: nil,
    bind_addr: "0.0.0.0:6986",
    datadir: nil,
    readonly: false,
    snapshot: false,
    peers: []
  ]
  @default_static [host: "localhost", port: 6986]
  @default_discover [
    discover_port: 5670,
    discover_addr: {255, 255, 255, 255},
    discover_interval: 1500
  ]
  @default [
    group: "default_",
    retries: 5,
    retries_interval: 5000,
    handshake_timeout: 5000,
    connection: {:static, @default_static},
    port: @default_port
  ]

  defstruct [:group, :retries, :retries_interval, :handshake_timeout, :connection, :port]

  def fetch() do
    @default
    |> Keyword.merge(Application.get_env(:drain_ex, __MODULE__, []))
    |> Keyword.update(:connection, [], &default_connection/1)
    |> Keyword.update(:port, [], &default_port/1)
    |> (&struct(__MODULE__, &1)).()
  end

  defp default_connection({:static, params}) do
    %Connection{discover_mode: :static, params: default(params, @default_static)}
  end

  defp default_connection({:discover, params}) do
    %Connection{discover_mode: :discover, params: default(params, @default_discover)}
  end

  defp default_connection({discover_mode}) when discover_mode in [:static, :discover] do
    default_connection({discover_mode, []})
  end

  defp default_connection(discover_mode) when discover_mode in [:static, :discover] do
    default_connection({discover_mode, []})
  end

  defp default_connection(_) do
    # default
    default_connection({:static, @default_static})
  end

  defp default_port(args) do
    default(args, @default_port)
  end

  defp default(params, default) do
    default |> Keyword.merge(params) |> Keyword.take(Keyword.keys(default))
  end
end
