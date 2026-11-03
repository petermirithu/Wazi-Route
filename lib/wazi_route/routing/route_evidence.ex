defmodule WaziRoute.Routing.RouteEvidence do
  @moduledoc """
  Turns time-valid, verified road-condition records into explicit route features.

  Candidate routes currently expose representative road names, so coverage is
  indicative rather than segment-precise. Missing evidence remains unknown.
  """

  alias WaziRoute.Location.CandidateRoute
  alias WaziRoute.Roads.ConditionEvidence

  def build(%CandidateRoute{} = route, evidence_by_road) do
    road_names = route.via |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
    road_count = max(length(road_names), 1)
    represented_distance_km = route.distance_m / 1000 / road_count

    {known, unknown} =
      Enum.reduce(road_names, {[], []}, fn road_name, {known, unknown} ->
        case Map.get(evidence_by_road, ConditionEvidence.road_key(road_name)) do
          nil -> {known, [road_name | unknown]}
          evidence -> {[{road_name, evidence} | known], unknown}
        end
      end)

    known = Enum.reverse(known)
    unknown = if road_names == [], do: ["Unnamed road segments"], else: Enum.reverse(unknown)

    conditions = Enum.map(known, fn {_road_name, evidence} -> evidence.condition end)

    %{
      travel_minutes: route.duration_s / 60,
      rough_km: Enum.count(conditions, &(&1 == "rough")) * represented_distance_km,
      unpaved_km: Enum.count(conditions, &(&1 == "unpaved")) * represented_distance_km,
      unknown_condition_km: length(unknown) * represented_distance_km,
      uphill_slow_traffic_exposure: Map.get(route.traffic, :uphill_slow_traffic_exposure, 0.0),
      verified_obstruction?:
        "obstruction" in conditions or Map.get(route.traffic, :road_closure?, false),
      evidence: %{
        coverage: coverage(known, road_names),
        known_condition_roads: Enum.map(known, &evidence_summary/1),
        unknown_condition_roads: unknown,
        verified_obstruction?:
          "obstruction" in conditions or Map.get(route.traffic, :road_closure?, false),
        traffic_basis: Map.get(route.traffic, :basis, :none),
        traffic: route.traffic,
        elevation: route.elevation
      }
    }
  end

  defp coverage(_known, []), do: :unknown

  defp coverage(known, road_names) when length(known) == length(road_names), do: :full
  defp coverage([], _road_names), do: :unknown
  defp coverage(_known, _road_names), do: :partial

  defp evidence_summary({road_name, evidence}) do
    %{
      road_name: road_name,
      condition: evidence.condition,
      observed_at: evidence.observed_at,
      source_type: evidence.source_type,
      confidence: evidence.confidence
    }
  end
end
