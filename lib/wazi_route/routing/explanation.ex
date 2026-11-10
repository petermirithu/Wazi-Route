defmodule WaziRoute.Routing.Explanation do
  @moduledoc """
  Generates deterministic, evidence-backed route explanations citing only verified facts
  actually present in candidate route features.

  Follows core product rules:
  - An explanation cannot claim evidence absent from route features.
  - Unknown condition is never claimed as smooth road.
  - Scores and comfort penalties are explained in equivalent minutes, separate from ETA.
  """

  alias WaziRoute.Vehicles.VehicleProfile

  @type factor :: %{
          category: :road_condition | :traffic_elevation | :travel_time | :data_coverage,
          label: String.t(),
          text: String.t(),
          sentiment: :positive | :negative | :warning | :neutral,
          evidence_cited: [String.t()]
        }

  @type explanation :: %{
          headline: String.t(),
          summary: String.t(),
          recommendation_type: atom(),
          cited_factors: [factor()],
          tradeoff: map() | nil,
          cautions: [String.t()],
          vehicle_summary: String.t(),
          score_summary: map()
        }

  @doc """
  Annotates a list of ranked candidate routes with recommendation metadata and explanations.
  The first route in the list is marked as `:recommended`.
  """
  def annotate_routes([], _preferences, _vehicle_profile), do: []

  def annotate_routes(routes, preferences, vehicle_profile) do
    fastest_duration_s = routes |> Enum.map(& &1.duration_s) |> Enum.min(fn -> 0 end)

    routes
    |> Enum.with_index()
    |> Enum.map(fn {route, index} ->
      recommended? = index == 0

      explanation =
        build_explanation(
          route,
          recommended?,
          routes,
          fastest_duration_s,
          preferences,
          vehicle_profile
        )

      label =
        determine_label(route, recommended?, fastest_duration_s, preferences, vehicle_profile)

      %{
        route
        | recommended: recommended?,
          recommendation_label: label,
          explanation: explanation
      }
    end)
  end

  defp build_explanation(
         route,
         recommended?,
         all_routes,
         fastest_duration_s,
         preferences,
         vehicle_profile
       ) do
    factors = collect_factors(route, preferences, vehicle_profile)
    cautions = collect_cautions(route)
    tradeoff = build_tradeoff(route, all_routes, fastest_duration_s)
    vehicle_summary = vehicle_profile_summary(vehicle_profile)

    headline =
      build_headline(route, recommended?, fastest_duration_s, preferences, vehicle_profile)

    summary = build_summary(route, recommended?, tradeoff, preferences, vehicle_profile)

    %{
      headline: headline,
      summary: summary,
      recommendation_type: recommendation_type(route, recommended?, fastest_duration_s),
      cited_factors: factors,
      tradeoff: tradeoff,
      cautions: cautions,
      vehicle_summary: vehicle_summary,
      score_summary: route.score_breakdown || %{}
    }
  end

  defp determine_label(_route, true, fastest_duration_s, _preferences, _vehicle_profile)
       when fastest_duration_s > 0 do
    "Recommended"
  end

  defp determine_label(route, false, fastest_duration_s, _preferences, _vehicle_profile) do
    if route.duration_s <= fastest_duration_s do
      "Quickest route"
    else
      "Alternative route"
    end
  end

  defp recommendation_type(_route, true, fastest_duration_s) when fastest_duration_s > 0,
    do: :best_match

  defp recommendation_type(route, false, fastest_duration_s)
       when route.duration_s <= fastest_duration_s, do: :quickest

  defp recommendation_type(_route, false, _fastest_duration_s), do: :alternative

  defp build_headline(_route, true, _fastest_duration_s, _preferences, vehicle_profile) do
    clearance = vehicle_clearance(vehicle_profile)
    transmission = vehicle_transmission(vehicle_profile)

    cond do
      clearance == "low" ->
        "Recommended for your low-clearance vehicle"

      transmission == "manual" ->
        "Recommended for your manual vehicle"

      true ->
        "Best overall match for your driving preferences"
    end
  end

  defp build_headline(route, false, fastest_duration_s, _preferences, _vehicle_profile) do
    if route.duration_s <= fastest_duration_s do
      "Quickest estimated travel time"
    else
      "Alternative option"
    end
  end

  defp build_summary(route, true, tradeoff, preferences, vehicle_profile) do
    breakdown = route.score_breakdown || %{}
    rough_penalty = Map.get(breakdown, :rough_road_penalty_minutes, 0.0)
    uphill_penalty = Map.get(breakdown, :uphill_traffic_penalty_minutes, 0.0)
    clearance = vehicle_clearance(vehicle_profile)

    cond do
      rough_penalty == 0.0 and tradeoff != nil and tradeoff.extra_minutes > 0 ->
        "Adds #{tradeoff.extra_minutes} min travel time over #{tradeoff.fastest_via}, but avoids rough road penalties on your #{clearance}-clearance vehicle."

      uphill_penalty == 0.0 and tradeoff != nil and tradeoff.extra_minutes > 0 and
          preferences.avoid_congested_uphill ->
        "Adds #{tradeoff.extra_minutes} min travel time over #{tradeoff.fastest_via}, but avoids hill-congestion exposure for your #{vehicle_transmission(vehicle_profile)} vehicle."

      tradeoff != nil and tradeoff.extra_minutes == 0 ->
        "Quickest available route with minimal comfort penalties for your #{clearance}-clearance vehicle."

      true ->
        "Lowest overall preference score (#{format_minutes(route.score)} equivalent minutes) considering road conditions, gradient, and traffic."
    end
  end

  defp build_summary(route, false, tradeoff, _preferences, vehicle_profile) do
    breakdown = route.score_breakdown || %{}
    rough_penalty = Map.get(breakdown, :rough_road_penalty_minutes, 0.0)
    uphill_penalty = Map.get(breakdown, :uphill_traffic_penalty_minutes, 0.0)
    clearance = vehicle_clearance(vehicle_profile)

    cond do
      rough_penalty > 0.0 ->
        "Applies a #{format_minutes(rough_penalty)} min rough-road penalty for #{clearance} clearance."

      uphill_penalty > 0.0 ->
        "Applies a #{format_minutes(uphill_penalty)} min hill-traffic penalty on steep gradients."

      tradeoff != nil and tradeoff.extra_minutes > 0 ->
        "About #{tradeoff.extra_minutes} min slower than the fastest route."

      true ->
        "Alternative candidate route with #{format_duration(route.duration_s)} travel time."
    end
  end

  defp collect_factors(route, _preferences, vehicle_profile) do
    evidence = route.evidence || %{}
    known = Map.get(evidence, :known_condition_roads, [])
    unknown = Map.get(evidence, :unknown_condition_roads, [])
    breakdown = route.score_breakdown || %{}

    smooth_roads = Enum.filter(known, &(&1.condition == "smooth"))
    rough_roads = Enum.filter(known, &(&1.condition == "rough"))
    unpaved_roads = Enum.filter(known, &(&1.condition == "unpaved"))

    factors = []

    # 1. Verified smooth roads
    factors =
      if smooth_roads != [] do
        road_names = Enum.map(smooth_roads, & &1.road_name)

        [
          %{
            category: :road_condition,
            label: "Verified smooth road",
            text: "Recently verified smooth surface on #{format_road_list(road_names)}.",
            sentiment: :positive,
            evidence_cited: road_names
          }
          | factors
        ]
      else
        factors
      end

    # 2. Rough roads
    factors =
      if rough_roads != [] do
        road_names = Enum.map(rough_roads, & &1.road_name)
        rough_penalty = Map.get(breakdown, :rough_road_penalty_minutes, 0.0)
        clearance = vehicle_clearance(vehicle_profile)

        text =
          if rough_penalty > 0 do
            "Rough road detected on #{format_road_list(road_names)} (+#{format_minutes(rough_penalty)} min penalty for #{clearance} clearance)."
          else
            "Rough road detected on #{format_road_list(road_names)}."
          end

        [
          %{
            category: :road_condition,
            label: "Rough road section",
            text: text,
            sentiment: :negative,
            evidence_cited: road_names
          }
          | factors
        ]
      else
        factors
      end

    # 3. Unpaved roads
    factors =
      if unpaved_roads != [] do
        road_names = Enum.map(unpaved_roads, & &1.road_name)

        [
          %{
            category: :road_condition,
            label: "Unpaved road section",
            text: "Unpaved surface on #{format_road_list(road_names)}.",
            sentiment: :negative,
            evidence_cited: road_names
          }
          | factors
        ]
      else
        factors
      end

    # 4. Unknown conditions
    factors =
      if unknown != [] do
        unknown_penalty = Map.get(breakdown, :unknown_condition_penalty_minutes, 0.0)

        text =
          if unknown_penalty > 0 do
            "Road condition unknown on #{format_road_list(unknown)} (+#{format_minutes(unknown_penalty)} min caution penalty)."
          else
            "Road condition is unknown on #{format_road_list(unknown)}."
          end

        [
          %{
            category: :data_coverage,
            label: "Unknown condition",
            text: text,
            sentiment: :warning,
            evidence_cited: unknown
          }
          | factors
        ]
      else
        factors
      end

    # 5. Elevation & Traffic
    elevation = Map.get(evidence, :elevation, %{})
    traffic = Map.get(evidence, :traffic, %{})

    factors =
      case Map.get(traffic, :status) do
        :fresh ->
          exposure = Map.get(traffic, :uphill_slow_traffic_exposure, 0.0)
          uphill_penalty = Map.get(breakdown, :uphill_traffic_penalty_minutes, 0.0)

          if exposure > 0 do
            [
              %{
                category: :traffic_elevation,
                label: "Uphill traffic congestion",
                text:
                  "Slow traffic detected on uphill section (+#{format_minutes(uphill_penalty)} min penalty for #{vehicle_transmission(vehicle_profile)} transmission).",
                sentiment: :negative,
                evidence_cited: ["Live TomTom traffic", "Directional elevation"]
              }
              | factors
            ]
          else
            [
              %{
                category: :traffic_elevation,
                label: "Clear uphill traffic",
                text: "Live traffic confirms clear uphill flow along this route.",
                sentiment: :positive,
                evidence_cited: ["Live TomTom traffic"]
              }
              | factors
            ]
          end

        _other ->
          if Map.get(elevation, :status) == :available do
            features = Map.get(elevation, :features, %{})
            ascent = Map.get(features, "total_ascent_m", Map.get(features, :total_ascent_m, 0.0))

            grade =
              Map.get(
                features,
                "max_uphill_grade_percent",
                Map.get(features, :max_uphill_grade_percent, 0.0)
              )

            [
              %{
                category: :traffic_elevation,
                label: "Terrain elevation",
                text:
                  "#{Float.round(ascent * 1.0, 0)} m total ascent with maximum uphill gradient of #{Float.round(grade * 1.0, 1)}%.",
                sentiment: :neutral,
                evidence_cited: ["OpenTopoData elevation"]
              }
              | factors
            ]
          else
            factors
          end
      end

    # 6. Travel time factor
    factors = [
      %{
        category: :travel_time,
        label: "Estimated duration",
        text:
          "#{format_duration(route.duration_s)} (#{Float.round(route.distance_m / 1000, 1)} km).",
        sentiment: :neutral,
        evidence_cited: []
      }
      | factors
    ]

    Enum.reverse(factors)
  end

  defp collect_cautions(route) do
    evidence = route.evidence || %{}
    unknown = Map.get(evidence, :unknown_condition_roads, [])
    traffic = Map.get(evidence, :traffic, %{})
    elevation = Map.get(evidence, :elevation, %{})

    cautions = []

    cautions =
      if unknown != [] do
        ["Road condition is unknown for part of this route; never assumed smooth." | cautions]
      else
        cautions
      end

    cautions =
      if Map.get(traffic, :status) in [:unavailable, :stale, :not_configured] do
        ["Live traffic is currently unavailable for this corridor." | cautions]
      else
        cautions
      end

    cautions =
      if Map.get(elevation, :status) != :available do
        ["Elevation profile is unavailable for this corridor." | cautions]
      else
        cautions
      end

    Enum.reverse(cautions)
  end

  defp build_tradeoff(route, all_routes, fastest_duration_s) do
    fastest_route = Enum.find(all_routes, &(&1.duration_s == fastest_duration_s))

    if fastest_route != nil and route.id != fastest_route.id and
         route.duration_s > fastest_duration_s do
      extra_seconds = route.duration_s - fastest_duration_s
      extra_minutes = extra_seconds |> Kernel./(60) |> Float.ceil() |> trunc()

      fastest_via =
        case fastest_route.via do
          [] -> "fastest route"
          roads -> Enum.join(roads, " · ")
        end

      %{
        extra_minutes: extra_minutes,
        fastest_duration_s: fastest_duration_s,
        fastest_via: fastest_via,
        score_difference: Float.round((route.score || 0.0) - (fastest_route.score || 0.0), 1)
      }
    else
      %{
        extra_minutes: 0,
        fastest_duration_s: fastest_duration_s,
        fastest_via: "this route",
        score_difference: 0.0
      }
    end
  end

  defp vehicle_profile_summary(nil), do: "Default vehicle settings"

  defp vehicle_profile_summary(%VehicleProfile{} = profile) do
    clearance = String.capitalize(profile.clearance_class || "normal")
    transmission = String.capitalize(profile.transmission || "manual")

    hill_assist =
      if profile.hill_start_assist, do: "with hill-start assist", else: "no hill-start assist"

    "#{clearance} clearance · #{transmission} (#{hill_assist})"
  end

  defp vehicle_clearance(%VehicleProfile{clearance_class: clearance}) when is_binary(clearance),
    do: clearance

  defp vehicle_clearance(_profile), do: "normal"

  defp vehicle_transmission(%VehicleProfile{transmission: trans}) when is_binary(trans), do: trans
  defp vehicle_transmission(_profile), do: "manual"

  defp format_road_list([]), do: "unnamed roads"
  defp format_road_list([road]), do: road
  defp format_road_list([r1, r2]), do: "#{r1} and #{r2}"

  defp format_road_list(roads),
    do: Enum.join(Enum.slice(roads, 0..-2//1), ", ") <> ", and " <> List.last(roads)

  defp format_duration(duration_s) when is_number(duration_s) do
    minutes = duration_s |> Kernel./(60) |> Float.ceil() |> trunc()

    case div(minutes, 60) do
      0 -> "#{minutes} min"
      hours -> "#{hours} hr #{rem(minutes, 60)} min"
    end
  end

  defp format_duration(_), do: "Unknown duration"

  defp format_minutes(minutes) when is_number(minutes), do: "#{Float.round(minutes * 1.0, 1)}"
  defp format_minutes(_), do: "0.0"
end
