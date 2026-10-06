defmodule WaziRoute.RuntimeConfigTest do
  use ExUnit.Case, async: false

  @runtime Path.expand("../config/runtime.exs", __DIR__)
  @environment %{
    "DATABASE_URL" => "postgresql://localhost/wazi_route_config_test",
    "SECRET_KEY_BASE" => String.duplicate("test-only-", 8),
    "PHX_HOST" => "wazi.example.org",
    "PHX_SERVER" => "true",
    "PHX_IP" => nil,
    "PORT" => nil,
    "POOL_SIZE" => nil,
    "ECTO_IPV6" => nil,
    "DNS_CLUSTER_QUERY" => nil
  }

  setup do
    previous = Map.new(@environment, fn {key, _} -> {key, System.get_env(key)} end)
    System.put_env(@environment)
    on_exit(fn -> System.put_env(previous) end)
    :ok
  end

  test "production uses a loopback listener behind the public HTTPS proxy" do
    config = read_config()
    endpoint = config[:wazi_route][WaziRouteWeb.Endpoint]
    repo = config[:wazi_route][WaziRoute.Repo]

    assert endpoint[:server]
    assert endpoint[:http][:ip] == {127, 0, 0, 1}
    assert endpoint[:http][:port] == 4020
    assert endpoint[:url] == [host: "wazi.example.org", port: 443, scheme: "https"]
    assert repo[:url] == @environment["DATABASE_URL"]
    assert repo[:pool_size] == 10
    assert repo[:socket_options] == []
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

  test "fails early when required production environment is missing" do
    for key <- ~w(DATABASE_URL SECRET_KEY_BASE PHX_HOST) do
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
    for key <- ~w(DATABASE_URL SECRET_KEY_BASE PHX_HOST PHX_SERVER) do
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
