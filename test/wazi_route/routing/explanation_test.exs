defmodule WaziRoute.Routing.ExplanationTest do
  use ExUnit.Case, async: true

  alias WaziRoute.Location.CandidateRoute
  alias WaziRoute.Routing.Explanation
  alias WaziRoute.Routing.Preference
  alias WaziRoute.Vehicles.VehicleProfile

  test "marks the top-ranked route as recommended and sets appropriate labels" do
    route1 = %CandidateRoute{
      id: "route-1",
      distance_m: 12_000,
      duration_s: 1_200,
      geometry: %{},
      via: ["Red Hill Road"],
      score: 20.0,
      comfort_penalty_minutes: 0.0,
      evidence: %{
        known_condition_roads: [
          %{
            road_name: "Red Hill Road",
            condition: "smooth",
            observed_at: ~U[2026-05-22 06:33:19Z],
            confidence: 0.7
          }
        ],
        unknown_condition_roads: []
      }
    }

    route2 = %CandidateRoute{
      id: "route-2",
      distance_m: 13_000,
      duration_s: 1_380,
      geometry: %{},
      via: ["Limuru Road"],
      score: 35.0,
      comfort_penalty_minutes: 12.0,
      evidence: %{
        known_condition_roads: [
          %{
            road_name: "Limuru Road",
            condition: "rough",
            observed_at: ~U[2026-07-10 14:22:05Z],
            confidence: 0.75
          }
        ],
        unknown_condition_roads: []
      }
    }

    preferences = %Preference{avoid_rough_roads: true, avoid_congested_uphill: true}
    vehicle = %VehicleProfile{clearance_class: "low", transmission: "manual"}

    [annotated1, annotated2] = Explanation.annotate_routes([route1, route2], preferences, vehicle)

    assert annotated1.recommended == true
    assert annotated1.recommendation_label == "Recommended"
    assert annotated1.explanation.recommendation_type == :best_match
    assert annotated1.explanation.headline =~ "Recommended for your low-clearance vehicle"

    assert annotated2.recommended == false
    assert annotated2.recommendation_label == "Alternative route"
    assert annotated2.explanation.recommendation_type == :alternative
  end

  test "explanation cannot claim evidence absent from route features" do
    route = %CandidateRoute{
      id: "route-1",
      distance_m: 10_000,
      duration_s: 1_000,
      geometry: %{},
      via: ["Unverified Path"],
      score: 25.0,
      comfort_penalty_minutes: 8.0,
      evidence: %{
        known_condition_roads: [],
        unknown_condition_roads: ["Unverified Path"],
        traffic: %{status: :unavailable},
        elevation: %{status: :unavailable}
      }
    }

    preferences = %Preference{avoid_rough_roads: true, prefer_verified_conditions: true}
    vehicle = %VehicleProfile{clearance_class: "normal", transmission: "manual"}

    [annotated] = Explanation.annotate_routes([route], preferences, vehicle)
    explanation = annotated.explanation

    # Never claims smooth road
    refute explanation.summary =~ "smooth"

    refute Enum.any?(
             explanation.cited_factors,
             &(&1.category == :road_condition and &1.label =~ "smooth")
           )

    # Explicitly warns that condition is unknown
    assert Enum.any?(
             explanation.cited_factors,
             &(&1.category == :data_coverage and &1.text =~ "Unverified Path")
           )

    assert Enum.any?(
             explanation.cautions,
             &(&1 =~ "unknown for part of this route; never assumed smooth")
           )

    assert Enum.any?(explanation.cautions, &(&1 =~ "traffic is currently unavailable"))
    assert Enum.any?(explanation.cautions, &(&1 =~ "Elevation profile is unavailable"))
  end

  test "cites verified smooth roads and explains detour tradeoffs against the fastest route" do
    fastest_rough = %CandidateRoute{
      id: "fastest",
      distance_m: 10_000,
      # 15 min
      duration_s: 900,
      geometry: %{},
      via: ["Limuru Road"],
      score: 50.0,
      comfort_penalty_minutes: 35.0,
      score_breakdown: %{rough_road_penalty_minutes: 35.0},
      evidence: %{
        known_condition_roads: [%{road_name: "Limuru Road", condition: "rough"}],
        unknown_condition_roads: []
      }
    }

    longer_smooth = %CandidateRoute{
      id: "smooth-detour",
      distance_m: 12_000,
      # 18 min (+3 min)
      duration_s: 1_080,
      geometry: %{},
      via: ["Red Hill Link Road", "Waiyaki Way"],
      score: 18.0,
      comfort_penalty_minutes: 0.0,
      score_breakdown: %{rough_road_penalty_minutes: 0.0},
      evidence: %{
        known_condition_roads: [
          %{road_name: "Red Hill Link Road", condition: "smooth"},
          %{road_name: "Waiyaki Way", condition: "smooth"}
        ],
        unknown_condition_roads: []
      }
    }

    preferences = %Preference{avoid_rough_roads: true}
    vehicle = %VehicleProfile{clearance_class: "low", transmission: "manual"}

    [recommended, other] =
      Explanation.annotate_routes([longer_smooth, fastest_rough], preferences, vehicle)

    assert recommended.recommended == true
    assert recommended.explanation.tradeoff.extra_minutes == 3
    assert recommended.explanation.summary =~ "Adds 3 min travel time"
    assert recommended.explanation.summary =~ "avoids rough road penalties"

    assert other.recommended == false
    assert other.explanation.summary =~ "rough-road penalty"
    assert other.recommendation_label == "Quickest route"
  end

  test "cites live uphill traffic when present" do
    route = %CandidateRoute{
      id: "uphill-traffic",
      distance_m: 10_000,
      duration_s: 1_200,
      geometry: %{},
      via: ["Waiyaki Way"],
      score: 40.0,
      comfort_penalty_minutes: 20.0,
      score_breakdown: %{uphill_traffic_penalty_minutes: 20.0},
      evidence: %{
        known_condition_roads: [%{road_name: "Waiyaki Way", condition: "smooth"}],
        unknown_condition_roads: [],
        traffic: %{
          status: :fresh,
          uphill_slow_traffic_exposure: 0.65
        }
      }
    }

    preferences = %Preference{avoid_congested_uphill: true}
    vehicle = %VehicleProfile{clearance_class: "normal", transmission: "manual"}

    [annotated] = Explanation.annotate_routes([route], preferences, vehicle)

    assert Enum.any?(annotated.explanation.cited_factors, fn factor ->
             factor.category == :traffic_elevation and
               factor.label =~ "Uphill traffic" and
               factor.text =~ "+20.0 min penalty"
           end)
  end
end
