defmodule WaziRoute.Routing.Ranker do
  @moduledoc false

  alias WaziRoute.Accounts.Scope
  alias WaziRoute.Roads
  alias WaziRoute.Routing.{Explanation, RouteEvidence, Scorer}
  alias WaziRoute.Vehicles

  def rank(%Scope{} = scope, routes) do
    preferences = WaziRoute.Routing.get_routing_preferences(scope)
    vehicle_profile = Vehicles.get_default_vehicle_profile(scope)
    evidence_by_road = roads_to_evidence(routes)
    shortest_duration_s = routes |> Enum.map(& &1.duration_s) |> Enum.min(fn -> 0 end)
    maximum_duration_s = shortest_duration_s + preferences.max_extra_minutes * 60

    routes
    |> Enum.map(fn route ->
      features = RouteEvidence.build(route, evidence_by_road)
      score = Scorer.score(features, preferences, vehicle_profile)

      %{
        route
        | evidence: features.evidence,
          score: score.total_minutes,
          comfort_penalty_minutes: score.comfort_penalty_minutes,
          score_breakdown: score
      }
    end)
    |> Enum.reject(& &1.evidence.verified_obstruction?)
    |> Enum.filter(&(&1.duration_s <= maximum_duration_s))
    |> Enum.sort_by(&{&1.score, &1.duration_s})
    |> Explanation.annotate_routes(preferences, vehicle_profile)
  end

  defp roads_to_evidence(routes) do
    routes
    |> Enum.flat_map(& &1.via)
    |> Roads.active_condition_evidence_by_road_names()
  end
end
