import Config

config :logger, :console, level: :warn

# config :stormex, Stormex.Config,
#   group: "default_",
#   retries: 5,
#   retries_interval: 5000,
#   handshake_timeout: 5000,
#   port: [
#     autostart: false,
#     name: Stormex.Port,
#     exe: nil,
#     bind_addr: "0.0.0.0:6986",
#     datadir: nil,
#     readonly: false,
#     snapshot: false
#   ]
#   connection: {:static, [port: 6986]}
#   connection:
#     {:discover,
#      [
#        discover_port: 5670,
#        discover_addr: {255, 255, 255, 255},
#        discover_interval: 1500
#      ]}
