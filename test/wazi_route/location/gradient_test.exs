defmodule WaziRoute.Location.GradientTest do
  use ExUnit.Case, async: true

  alias WaziRoute.Location.{Gradient, RouteSampler}

  test "samples a route at a bounded interval" do
    geometry = %{
      "type" => "LineString",
      "coordinates" => [[36.8000, -1.2000], [36.8000, -1.1900]]
    }

    assert {:ok, sample} =
             RouteSampler.sample(geometry, sampling_interval_m: 50, maximum_samples: 10)

    assert length(sample.points) == 10
    assert sample.route_distance_m > 1_000
    assert sample.sampling_interval_m > 100
  end

  test "reversing the journey reverses directional uphill interpretation" do
    northbound_points = [
      %{latitude: -1.20, longitude: 36.80, elevation_m: 1_000.0},
      %{latitude: -1.19, longitude: 36.80, elevation_m: 1_040.0}
    ]

    southbound_points = Enum.reverse(northbound_points)

    northbound = Gradient.features(northbound_points)
    southbound = Gradient.features(southbound_points)

    assert northbound["uphill_distance_m"] > 0
    assert northbound["max_uphill_grade_percent"] > 0
    assert southbound["uphill_distance_m"] == 0.0
    assert southbound["max_uphill_grade_percent"] == 0.0
  end
end
