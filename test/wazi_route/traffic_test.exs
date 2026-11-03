defmodule WaziRoute.TrafficTest do
  use WaziRoute.DataCase, async: true

  alias WaziRoute.Traffic

  test "returns only unexpired traffic observations" do
    now = DateTime.utc_now(:second)
    point = %{latitude: -1.2044, longitude: 36.7784}

    assert {:ok, _observation} =
             Traffic.cache_observation(%{
               provider: "test",
               point_key: Traffic.point_key(point),
               latitude: point.latitude,
               longitude: point.longitude,
               current_speed_kph: 12,
               free_flow_speed_kph: 40,
               confidence: "0.90",
               road_closure: false,
               observed_at: now,
               expires_at: DateTime.add(now, 5, :minute)
             })

    expired_point = %{latitude: -1.2054, longitude: 36.7784}

    assert {:ok, _observation} =
             Traffic.cache_observation(%{
               provider: "test",
               point_key: Traffic.point_key(expired_point),
               latitude: expired_point.latitude,
               longitude: expired_point.longitude,
               current_speed_kph: 12,
               free_flow_speed_kph: 40,
               confidence: "0.90",
               road_closure: false,
               observed_at: now,
               expires_at: DateTime.add(now, -1, :second)
             })

    fresh = Traffic.fresh_observations("test", [point, expired_point], now)
    point_key = Traffic.point_key(point)

    assert %{^point_key => %{current_speed_kph: 12.0}} = fresh
    refute Map.has_key?(fresh, Traffic.point_key(expired_point))
  end
end
