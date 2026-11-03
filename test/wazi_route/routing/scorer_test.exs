defmodule WaziRoute.Routing.ScorerTest do
  use ExUnit.Case, async: true

  alias WaziRoute.Routing.Preference
  alias WaziRoute.Routing.Scorer
  alias WaziRoute.Vehicles.VehicleProfile

  test "unknown road condition receives a penalty and is never scored as smooth" do
    preferences = %Preference{unknown_condition_tolerance: "cautious"}

    score =
      Scorer.score(
        %{
          travel_minutes: 20.0,
          rough_km: 0.0,
          unpaved_km: 0.0,
          unknown_condition_km: 3.0,
          uphill_slow_traffic_exposure: 0.0
        },
        preferences
      )

    assert score.unknown_condition_penalty_minutes == 9.0
    assert score.total_minutes == 29.0
  end

  test "a manual vehicle gets a higher uphill slow-traffic penalty" do
    features = %{
      travel_minutes: 20.0,
      rough_km: 0.0,
      unpaved_km: 0.0,
      unknown_condition_km: 0.0,
      uphill_slow_traffic_exposure: 2.0
    }

    preferences = %Preference{}

    manual_score = Scorer.score(features, preferences, %VehicleProfile{transmission: "manual"})

    automatic_score =
      Scorer.score(features, preferences, %VehicleProfile{transmission: "automatic"})

    assert manual_score.uphill_traffic_penalty_minutes == 12.0
    assert automatic_score.uphill_traffic_penalty_minutes == 8.0
  end

  test "hill-start assistance reduces the uphill slow-traffic penalty" do
    features = %{
      travel_minutes: 20.0,
      rough_km: 0.0,
      unpaved_km: 0.0,
      unknown_condition_km: 0.0,
      uphill_slow_traffic_exposure: 2.0
    }

    preferences = %Preference{}
    without_assist = Scorer.score(features, preferences, %VehicleProfile{transmission: "manual"})

    with_assist =
      Scorer.score(features, preferences, %VehicleProfile{
        transmission: "manual",
        hill_start_assist: true
      })

    assert with_assist.uphill_traffic_penalty_minutes <
             without_assist.uphill_traffic_penalty_minutes
  end
end
