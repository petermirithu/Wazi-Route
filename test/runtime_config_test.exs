defmodule WaziRoute.RuntimeConfigTest do
  use ExUnit.Case, async: false

  @runtime Path.expand("../config/runtime.exs", __DIR__)
  @environment %{
    "DATABASE_URL" => "postgresql://localhost/wazi_route_config_test",
    "SECRET_KEY_BASE" => String.duplicate("test-only-", 8),
    "PHX_HOST" => nil,
    "RENDER_EXTERNAL_HOSTNAME" => "wazi.example.onrender.com",
    "PHX_SERVER" => "true",
    "PHX_IP" => nil,
    "PORT" => nil,
    "POOL_SIZE" => nil,
    "ECTO_IPV6" => nil,
    "DNS_CLUSTER_QUERY" => nil,
    "MAILGUN_BASE_URL" => "https://api.mailgun.net",
    "MAILGUN_DOMAIN" => "mg.example.org",
    "MAILGUN_API_KEY" => "mailgun-test-key",
    "MAIL_FROM_EMAIL" => "hello@example.org",
    "MAILGUN_FROM_EMAIL" => nil,
    "MAIL_FROM_NAME" => "Wazi Route"
  }

  setup do
    previous = Map.new(@environment, fn {key, _} -> {key, System.get_env(key)} end)
    System.put_env(@environment)
    on_exit(fn -> System.put_env(previous) end)
    :ok
  end

  test "production uses Render's public hostname and listener" do
    config = read_config()
    endpoint = config[:wazi_route][WaziRouteWeb.Endpoint]
    repo = config[:wazi_route][WaziRoute.Repo]
    mailgun = config[:wazi_route][:mailgun]

    assert endpoint[:server]
    assert endpoint[:http][:ip] == {0, 0, 0, 0}
    assert endpoint[:http][:port] == 4020
    assert endpoint[:url] == [host: "wazi.example.onrender.com", port: 443, scheme: "https"]
    assert repo[:url] == @environment["DATABASE_URL"]
    assert repo[:ssl]
    assert repo[:pool_size] == 10
    assert repo[:socket_options] == []
    assert mailgun[:base_url] == "https://api.mailgun.net"
    assert mailgun[:domain] == "mg.example.org"
    assert mailgun[:api_key] == "mailgun-test-key"
    assert config[:wazi_route][:mail_from] == {"Wazi Route", "hello@example.org"}
  end

  test "supports explicit listener, pool, and IPv6 overrides" do
    System.put_env(%{
      "PHX_IP" => "::1",
      "PORT" => "4100",
      "POOL_SIZE" => "5",
      "ECTO_IPV6" => "true",
      "PHX_SERVER" => "false"
    })

    config = read_config()
    endpoint = config[:wazi_route][WaziRouteWeb.Endpoint]
    repo = config[:wazi_route][WaziRoute.Repo]

    refute endpoint[:server]
    assert endpoint[:http][:ip] == {0, 0, 0, 0, 0, 0, 0, 1}
    assert endpoint[:http][:port] == 4100
    assert repo[:pool_size] == 5
    assert repo[:socket_options] == [:inet6]
  end

  test "uses PHX_HOST when a custom domain is configured" do
    System.put_env("PHX_HOST", "wazi.example.org")

    config = read_config()
    endpoint = config[:wazi_route][WaziRouteWeb.Endpoint]

    assert endpoint[:url] == [host: "wazi.example.org", port: 443, scheme: "https"]
  end

  test "uses exported Mailgun settings in development" do
    System.delete_env("MAIL_FROM_EMAIL")
    System.put_env("MAILGUN_FROM_EMAIL", "dev-sender@example.org")

    config = Config.Reader.read!(@runtime, env: :dev, target: :host)

    assert config[:wazi_route][:mailgun] == [
             base_url: "https://api.mailgun.net",
             domain: "mg.example.org",
             api_key: "mailgun-test-key"
           ]

    assert config[:wazi_route][:mail_from] == {"Wazi Route", "dev-sender@example.org"}
  end

  test "fails early when required production environment is missing" do
    for key <-
          ~w(DATABASE_URL SECRET_KEY_BASE MAILGUN_BASE_URL MAILGUN_DOMAIN MAILGUN_API_KEY) do
      System.delete_env(key)

      assert_raise RuntimeError, ~r/environment variable #{key} is missing/, fn ->
        read_config()
      end

      System.put_env(key, Map.fetch!(@environment, key))
    end
  end

  test "rejects an invalid listener address" do
    System.put_env("PHX_IP", "not-an-ip")

    assert_raise RuntimeError, "PHX_IP must be a valid IPv4 or IPv6 address", fn ->
      read_config()
    end
  end

  test "non-production environments do not require production credentials" do
    for key <- ~w(DATABASE_URL SECRET_KEY_BASE PHX_HOST RENDER_EXTERNAL_HOSTNAME PHX_SERVER) do
      System.delete_env(key)
    end

    config = Config.Reader.read!(@runtime, env: :test, target: :host)
    assert config[:wazi_route][WaziRouteWeb.Endpoint][:http][:port] == 4020
    refute config[:wazi_route][WaziRoute.Repo]
  end

  defp read_config do
    Config.Reader.read!(@runtime, env: :prod, target: :host)
  end
end
