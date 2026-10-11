import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/wazi_route start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") in ~w(true 1) do
  config :wazi_route, WaziRouteWeb.Endpoint, server: true
end

config :wazi_route, WaziRouteWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4020"))]

if config_env() == :dev do
  # Reload browser tabs when matching files change.
  config :wazi_route, WaziRouteWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        # Static assets, except user uploads
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
        # Gettext translations
        ~r"priv/gettext/.*\.po$"E,
        # Router, Controllers, LiveViews and LiveComponents
        ~r"lib/wazi_route_web/router\.ex$"E,
        ~r"lib/wazi_route_web/(controllers|live|components)/.*\.(ex|heex)$"E
      ]
    ]

  config :swoosh, :api_client, true
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :wazi_route, WaziRoute.Repo,
    # PostgreSQL is on this server's loopback interface; no database TLS is required.
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host =
    System.get_env("PHX_HOST") ||
      raise "environment variable PHX_HOST is missing. Set it to the public domain without https://."

  bind_address = System.get_env("PHX_IP", "127.0.0.1")

  bind_ip =
    case :inet.parse_address(String.to_charlist(bind_address)) do
      {:ok, address} -> address
      {:error, _} -> raise "PHX_IP must be a valid IPv4 or IPv6 address"
    end

  config :wazi_route, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :wazi_route, WaziRouteWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Only the same-server HTTPS proxy should reach Phoenix directly.
      ip: bind_ip
    ],
    secret_key_base: secret_key_base

  config :swoosh, :api_client, false

  smtp_relay =
    System.get_env("SMTP_RELAY") ||
      raise "environment variable SMTP_RELAY is missing"

  smtp_username =
    System.get_env("SMTP_USERNAME") ||
      raise "environment variable SMTP_USERNAME is missing"

  smtp_password =
    System.get_env("SMTP_PASSWORD") ||
      raise "environment variable SMTP_PASSWORD is missing"

  from_email =
    System.get_env("SMTP_FROM_EMAIL") ||
      raise "environment variable SMTP_FROM_EMAIL is missing"

  smtp_port = String.to_integer(System.get_env("SMTP_PORT", "587"))

  config :wazi_route, :mail_from, {System.get_env("SMTP_FROM_NAME", "Wazi Route"), from_email}

  config :wazi_route, WaziRoute.Mailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: smtp_relay,
    username: smtp_username,
    password: smtp_password,
    port: smtp_port,
    auth: :always,
    ssl: false,
    tls: :always,
    tls_options: [
      versions: [:"tlsv1.2", :"tlsv1.3"],
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      server_name_indication: String.to_charlist(smtp_relay),
      depth: 4,
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ]
    ]

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :wazi_route, WaziRouteWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://plug.hexdocs.pm/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :wazi_route, WaziRouteWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
