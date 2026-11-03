defmodule WaziRoute.Routing.RankerTest do
  use WaziRoute.DataCase, async: true

  alias WaziRoute.Accounts.Scope
  alias WaziRoute.Location.CandidateRoute
  alias WaziRoute.Roads
  alias WaziRoute.Routing
  alias WaziRoute.Routing.{Ranker, RouteEvidence}
  alias WaziRoute.Vehicles

  import WaziRoute.AccountsFixtures

  test "ranks verified smooth evidence ahead of a shorter rough alternative for a low-clearance vehicle" do
    scope = user_fixture() |> Scope.for_user()
    now = DateTime.utc_now(:second)

    {:ok, _profile} =
      Vehicles.create_vehicle_profile(scope, %{
        name: "Low daily car",
        transmission: "manual",
        clearance_class: "low"
      })

    {:ok, _preferences} =
      Routing.save_routing_preferences(scope, %{
        avoid_rough_roads: true,
        prefer_verified_conditions: true,
        max_extra_minutes: 10,
        unknown_condition_tolerance: "cautious"
      })

    {:ok, _evidence} =
      Roads.record_condition_evidence(%{
        road_name: "Rough Road",
        condition: "rough",
        source_type: "survey",
        source_reference: "pilot-rough-road",
        observed_at: now,
        retrieved_at: now,
        confidence: "0.90",
        verification_status: "verified",
        verified_at: now
      })

    {:ok, _evidence} =
      Roads.record_condition_evidence(%{
        road_name: "Smooth Road",
        condition: "smooth",
        source_type: "survey",
        source_reference: "pilot-smooth-road",
        observed_at: now,
        retrieved_at: now,
        confidence: "0.90",
        verification_status: "verified",
        verified_at: now
      })

    routes = [
      candidate("route-1", 10_000, 1_200, ["Rough Road"]),
      candidate("route-2", 11_000, 1_320, ["Smooth Road"])
    ]

    [best_route, other_route] = Ranker.rank(scope, routes)

    assert best_route.id == "route-2"
    assert best_route.evidence.coverage == :full
    assert other_route.evidence.known_condition_roads |> hd() |> Map.fetch!(:condition) == "rough"
  end

  test "removes a route with verified obstruction evidence" do
    scope = user_fixture() |> Scope.for_user()
    now = DateTime.utc_now(:second)

    {:ok, _evidence} =
      Roads.record_condition_evidence(%{
        road_name: "Closed Road",
        condition: "obstruction",
        source_type: "survey",
        source_reference: "pilot-closure",
        observed_at: now,
        retrieved_at: now,
        confidence: "0.90",
        verification_status: "verified",
        verified_at: now
      })

    assert [route] =
             Ranker.rank(scope, [
               candidate("blocked", 10_000, 1_200, ["Closed Road"]),
               candidate("open", 11_000, 1_300, ["Open Road"])
             ])

    assert route.id == "open"
    assert route.evidence.coverage == :unknown
  end

  test "leaves a road with no evidence explicitly unknown" do
    route = candidate("unknown", 10_000, 1_200, ["No evidence road"])

    features = RouteEvidence.build(route, %{})

    assert features.evidence.coverage == :unknown
    assert features.evidence.unknown_condition_roads == ["No evidence road"]
    assert features.unknown_condition_km == 10.0
    assert features.rough_km == 0.0
  end

  test "enforces the maximum additional travel time before scoring" do
    scope = user_fixture() |> Scope.for_user()

    {:ok, _preferences} =
      Routing.save_routing_preferences(scope, %{
        max_extra_minutes: 0,
        prefer_verified_conditions: false
      })

    assert [route] =
             Ranker.rank(scope, [
               candidate("fast", 10_000, 1_200, ["Fast Road"]),
               candidate("slow", 10_000, 1_260, ["Slow Road"])
             ])

    assert route.id == "fast"
  end

  defp candidate(id, distance_m, duration_s, via) do
    %CandidateRoute{
      id: id,
      distance_m: distance_m,
      duration_s: duration_s,
      via: via,
      geometry: %{"type" => "LineString", "coordinates" => [[36.8, -1.2], [36.7, -1.3]]}
    }
  end
end
