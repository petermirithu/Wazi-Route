defmodule WaziRoute.Location.ElevationTest do
  use WaziRoute.DataCase, async: true

  alias WaziRoute.Elevations
  alias WaziRoute.Location.{CandidateRoute, Elevation}

  test "enriches an uncached route and reuses its persisted elevation profile" do
    route = candidate_route()
    geometry_hash = Elevation.geometry_hash(route.geometry)

    [enriched_route] = Elevation.enrich_routes([route])

    assert enriched_route.elevation.status == :available
    assert enriched_route.elevation.features["uphill_distance_m"] > 0
    assert cached_profile = Elevations.get_route_profile(geometry_hash, "test-elevation")
    assert cached_profile.sample_count > 1

    [cached_route] = Elevation.enrich_routes([route])

    assert cached_route.elevation.source == :cache
    assert cached_route.elevation.features == cached_profile.features
  end

  defp candidate_route do
    %CandidateRoute{
      id: "route-1",
      distance_m: 2_000,
      duration_s: 300,
      via: ["Test Road"],
      geometry: %{
        "type" => "LineString",
        "coordinates" => [[36.8000, -1.2000], [36.8000, -1.1900]]
      }
    }
  end
end
