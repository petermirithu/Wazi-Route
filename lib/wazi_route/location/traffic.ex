defmodule WaziRoute.Location.Traffic do
  @moduledoc false

  alias WaziRoute.Location.CandidateRoute
  alias WaziRoute.Traffic, as: TrafficCache

  @maximum_points_per_route 2
  @default_cache_ttl_seconds 300
  @default_max_concurrency 2

  def enrich_routes(routes) do
    provider = Application.fetch_env!(:wazi_route, :traffic_provider)

    if provider.available?() do
      provider_name = provider.provider_name()
      point_routes = Enum.map(routes, &%{route: &1, points: uphill_points(&1)})

      points =
        point_routes |> Enum.flat_map(& &1.points) |> Enum.uniq_by(&TrafficCache.point_key/1)

      fresh_observations = TrafficCache.fresh_observations(provider_name, points)

      missing_points =
        Enum.reject(points, &Map.has_key?(fresh_observations, TrafficCache.point_key(&1)))

      observations =
        Map.merge(fresh_observations, fetch_missing(provider, provider_name, missing_points))

      Enum.map(point_routes, fn %{route: route, points: route_points} ->
        attach_traffic(route, route_points, observations)
      end)
    else
      Enum.map(routes, &attach_unavailable(&1, :traffic_not_configured))
    end
  rescue
    _error -> Enum.map(routes, &attach_unavailable(&1, :traffic_unavailable))
  end

  defp fetch_missing(_provider, _provider_name, []), do: %{}

  defp fetch_missing(provider, provider_name, points) do
    now = DateTime.utc_now(:second)

    ttl_seconds =
      Application.get_env(:wazi_route, :traffic_cache_ttl_seconds, @default_cache_ttl_seconds)

    max_concurrency =
      Application.get_env(:wazi_route, :traffic_max_concurrency, @default_max_concurrency)

    points
    |> Task.async_stream(
      fn point -> {point, provider.flow(point)} end,
      max_concurrency: max_concurrency,
      timeout: :infinity,
      ordered: true
    )
    |> Enum.reduce(%{}, fn
      {:ok, {point, {:ok, flow}}}, observations ->
        attrs = %{
          provider: provider_name,
          point_key: TrafficCache.point_key(point),
          latitude: point.latitude,
          longitude: point.longitude,
          current_speed_kph: flow.current_speed_kph,
          free_flow_speed_kph: flow.free_flow_speed_kph,
          confidence: flow.confidence,
          road_closure: flow.road_closure,
          observed_at: now,
          expires_at: DateTime.add(now, ttl_seconds, :second)
        }

        case TrafficCache.cache_observation(attrs) do
          {:ok, observation} -> Map.put(observations, observation.point_key, observation)
          {:error, _changeset} -> observations
        end

      _result, observations ->
        observations
    end)
  end

  defp uphill_points(%CandidateRoute{elevation: %{status: :available, features: features}}) do
    features
    |> Map.get("uphill_points", Map.get(features, :uphill_points, []))
    |> Enum.flat_map(&normalize_point/1)
    |> representative_points()
  end

  defp uphill_points(_route), do: []

  defp normalize_point(%{latitude: latitude, longitude: longitude})
       when is_number(latitude) and is_number(longitude),
       do: [%{latitude: latitude * 1.0, longitude: longitude * 1.0}]

  defp normalize_point(%{"latitude" => latitude, "longitude" => longitude})
       when is_number(latitude) and is_number(longitude),
       do: [%{latitude: latitude * 1.0, longitude: longitude * 1.0}]

  defp normalize_point(_point), do: []

  defp representative_points([]), do: []
  defp representative_points(points) when length(points) <= @maximum_points_per_route, do: points

  defp representative_points(points) do
    [List.first(points), List.last(points)] |> Enum.uniq_by(&TrafficCache.point_key/1)
  end

  defp attach_traffic(route, [], _observations) do
    %{
      route
      | traffic: %{status: :not_applicable, basis: :none, uphill_slow_traffic_exposure: 0.0}
    }
  end

  defp attach_traffic(route, points, observations) do
    flows =
      points
      |> Enum.flat_map(fn point ->
        case Map.fetch(observations, TrafficCache.point_key(point)) do
          {:ok, observation} -> [observation]
          :error -> []
        end
      end)

    case flows do
      [] ->
        attach_unavailable(route, :traffic_unavailable)

      _ ->
        slowdown = flows |> Enum.map(&slowdown_factor/1) |> Enum.sum() |> Kernel./(length(flows))
        uphill_distance_km = uphill_distance_m(route) / 1000
        all_points_fresh? = length(flows) == length(points)

        %{
          route
          | traffic: %{
              status: if(all_points_fresh?, do: :fresh, else: :partial),
              basis: if(all_points_fresh?, do: :live, else: :mixed),
              observed_at: Enum.max_by(flows, & &1.observed_at).observed_at,
              expires_at: Enum.min_by(flows, & &1.expires_at).expires_at,
              sampled_points: length(flows),
              road_closure?: Enum.any?(flows, & &1.road_closure),
              uphill_slow_traffic_exposure: uphill_distance_km * slowdown
            }
        }
    end
  end

  defp attach_unavailable(route, reason) do
    %{
      route
      | traffic: %{
          status: :unavailable,
          basis: :none,
          reason: reason,
          uphill_slow_traffic_exposure: 0.0
        }
    }
  end

  defp slowdown_factor(observation) do
    speed_ratio = observation.current_speed_kph / observation.free_flow_speed_kph
    max(1 - speed_ratio, 0) * Decimal.to_float(observation.confidence)
  end

  defp uphill_distance_m(%CandidateRoute{elevation: %{features: features}}) do
    Map.get(features, "uphill_distance_m", Map.get(features, :uphill_distance_m, 0.0))
  end
end
