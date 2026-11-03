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

config :wazi_route, WaziRoute.Location.Geocoding.Geoapify,
  api_key: System.get_env("GEOAPIFY_API_KEY")

config :wazi_route, WaziRoute.Location.Routing.OpenRouteService,
  api_key: System.get_env("OPENROUTESERVICE_API_KEY")

config :wazi_route, WaziRoute.Location.Traffic.TomTom, api_key: System.get_env("TOMTOM_API_KEY")

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

  case {
    System.get_env("MAILGUN_BASE_URL"),
    System.get_env("MAILGUN_DOMAIN"),
    System.get_env("MAILGUN_API_KEY")
  } do
    {mailgun_base_url, mailgun_domain, mailgun_api_key}
    when is_binary(mailgun_base_url) and is_binary(mailgun_domain) and is_binary(mailgun_api_key) ->
      mail_from_email =
        System.get_env("MAIL_FROM_EMAIL") ||
          System.get_env("MAILGUN_FROM_EMAIL") ||
          "postmaster@#{mailgun_domain}"

      config :wazi_route,
             :mailgun,
             base_url: mailgun_base_url,
             domain: mailgun_domain,
             api_key: mailgun_api_key

      config :wazi_route,
             :mail_from,
             {System.get_env("MAIL_FROM_NAME", "Wazi Route"), mail_from_email}

    _ ->
      :ok
  end
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
    url: database_url,
    # Postgrex does not derive TLS settings from a URL's `sslmode` parameter.
    # Supabase requires an encrypted database connection; `true` uses Postgrex's
    # secure defaults, including peer certificate and hostname verification.
    ssl: true,
    ssl_opts: [verify: :verify_none],
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

  # Render provides the public `onrender.com` hostname at runtime. `PHX_HOST`
  # remains available for a custom domain, which should take precedence once it
  # is configured in the Render dashboard.
  host =
    System.get_env("PHX_HOST") ||
      System.get_env("RENDER_EXTERNAL_HOSTNAME") ||
      "localhost"

  # Render sends traffic directly to the port exposed by the service, so Phoenix
  # must listen on all interfaces. A local reverse-proxy deployment can still
  # supply PHX_IP=127.0.0.1 explicitly.
  bind_address = System.get_env("PHX_IP", "0.0.0.0")

  bind_ip =
    case :inet.parse_address(String.to_charlist(bind_address)) do
      {:ok, address} -> address
      {:error, _} -> raise "PHX_IP must be a valid IPv4 or IPv6 address"
    end

  config :wazi_route, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :wazi_route, WaziRouteWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: bind_ip],
    secret_key_base: secret_key_base

  mailgun_base_url =
    System.get_env("MAILGUN_BASE_URL") || raise "environment variable MAILGUN_BASE_URL is missing"

  mailgun_domain =
    System.get_env("MAILGUN_DOMAIN") || raise "environment variable MAILGUN_DOMAIN is missing"

  mailgun_api_key =
    System.get_env("MAILGUN_API_KEY") || raise "environment variable MAILGUN_API_KEY is missing"

  config :wazi_route,
         :mailgun,
         base_url: mailgun_base_url,
         domain: mailgun_domain,
         api_key: mailgun_api_key

  config :wazi_route,
         :mail_from,
         {
           System.get_env("MAIL_FROM_NAME", "Wazi Route"),
           System.get_env("MAIL_FROM_EMAIL") ||
             System.get_env("MAILGUN_FROM_EMAIL") ||
             "postmaster@#{mailgun_domain}"
         }

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
