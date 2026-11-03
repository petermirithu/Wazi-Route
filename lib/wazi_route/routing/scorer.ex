defmodule WaziRoute.Routing.Scorer do
  @moduledoc """
  Deterministic route scoring expressed in equivalent minutes, not an ETA.
  """

  alias WaziRoute.Routing.Preference
  alias WaziRoute.Vehicles.VehicleProfile

  def score(features, %Preference{} = preferences, vehicle_profile \\ nil) do
    rough_penalty = rough_penalty(features, preferences, vehicle_profile)
    unknown_penalty = unknown_penalty(features, preferences)
    uphill_traffic_penalty = uphill_traffic_penalty(features, preferences, vehicle_profile)
    travel_minutes = features.travel_minutes

    penalty_minutes = rough_penalty + unknown_penalty + uphill_traffic_penalty

    %{
      total_minutes: Float.round(travel_minutes + penalty_minutes, 1),
      travel_minutes: Float.round(travel_minutes, 1),
      comfort_penalty_minutes: Float.round(penalty_minutes, 1),
      rough_road_penalty_minutes: Float.round(rough_penalty, 1),
      unknown_condition_penalty_minutes: Float.round(unknown_penalty, 1),
      uphill_traffic_penalty_minutes: Float.round(uphill_traffic_penalty, 1)
    }
  end

  defp rough_penalty(_features, %Preference{avoid_rough_roads: false}, _vehicle_profile), do: 0.0

  defp rough_penalty(features, _preferences, vehicle_profile) do
    clearance_weight =
      case vehicle_profile do
        %VehicleProfile{clearance_class: "low"} -> 8.0
        %VehicleProfile{clearance_class: "normal"} -> 5.0
        %VehicleProfile{clearance_class: "high"} -> 2.5
        _ -> 4.0
      end

    features.rough_km * clearance_weight + features.unpaved_km * clearance_weight * 1.25
  end

  defp unknown_penalty(_features, %Preference{prefer_verified_conditions: false}), do: 0.0

  defp unknown_penalty(features, %Preference{unknown_condition_tolerance: tolerance}) do
    weight =
      case tolerance do
        "cautious" -> 3.0
        "balanced" -> 1.5
        "open" -> 0.5
      end

    features.unknown_condition_km * weight
  end

  defp uphill_traffic_penalty(
         _features,
         %Preference{avoid_congested_uphill: false},
         _vehicle_profile
       ),
       do: 0.0

  defp uphill_traffic_penalty(features, _preferences, vehicle_profile) do
    transmission_weight =
      case vehicle_profile do
        %VehicleProfile{transmission: "manual"} -> 6.0
        _ -> 4.0
      end

    hill_start_factor =
      case vehicle_profile do
        %VehicleProfile{hill_start_assist: true} -> 0.65
        _ -> 1.0
      end

    features.uphill_slow_traffic_exposure * transmission_weight * hill_start_factor
  end
end
