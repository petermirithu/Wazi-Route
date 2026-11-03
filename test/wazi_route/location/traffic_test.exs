defmodule WaziRoute.Location.TrafficTest do
  use WaziRoute.DataCase, async: true

  alias WaziRoute.Location.{CandidateRoute, Traffic}
  alias WaziRoute.Traffic, as: TrafficCache

  test "uses fresh uphill traffic and caches it for later searches" do
    route = candidate_route()

    [enriched_route] = Traffic.enrich_routes([route])

    assert enriched_route.traffic.status == :fresh
    assert enriched_route.traffic.basis == :live
    assert enriched_route.traffic.uphill_slow_traffic_exposure > 0

    point = %{latitude: -1.19, longitude: 36.8}
    point_key = TrafficCache.point_key(point)

    assert %{^point_key => _observation} =
             TrafficCache.fresh_observations("test-traffic", [point])
  end

  test "does not score traffic when no uphill section exists" do
    route = %{
      candidate_route()
      | elevation: %{status: :available, features: %{"uphill_points" => []}}
    }

    [enriched_route] = Traffic.enrich_routes([route])

    assert enriched_route.traffic.status == :not_applicable
    assert enriched_route.traffic.uphill_slow_traffic_exposure == 0.0
  end

  defp candidate_route do
    %CandidateRoute{
      id: "route-1",
      distance_m: 2_000,
      duration_s: 300,
      geometry: %{"type" => "LineString", "coordinates" => [[36.8, -1.2], [36.8, -1.19]]},
      elevation: %{
        status: :available,
        features: %{
          "uphill_distance_m" => 1_000.0,
          "uphill_points" => [%{latitude: -1.19, longitude: 36.8}]
        }
      }
    }
  end
end
