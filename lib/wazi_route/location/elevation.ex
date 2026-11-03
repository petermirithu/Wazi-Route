defmodule WaziRoute.Location.Elevation do
  @moduledoc false

  alias WaziRoute.Elevations
  alias WaziRoute.Location.{CandidateRoute, Gradient, RouteSampler}

  @default_sampling_interval_m 50
  @default_maximum_request_points 100

  def enrich_routes(routes) do
    provider = Application.fetch_env!(:wazi_route, :elevation_provider)
    dataset = provider.dataset()

    maximum_request_points =
      Application.get_env(
        :wazi_route,
        :elevation_maximum_request_points,
        @default_maximum_request_points
      )

    sampling_interval_m =
      Application.get_env(
        :wazi_route,
        :elevation_sampling_interval_m,
        @default_sampling_interval_m
      )

    descriptors =
      Enum.map(routes, fn route ->
        geometry_hash = geometry_hash(route.geometry)

        case Elevations.get_route_profile(geometry_hash, dataset) do
          nil -> %{route: route, geometry_hash: geometry_hash, cached_profile: nil}
          profile -> %{route: route, geometry_hash: geometry_hash, cached_profile: profile}
        end
      end)

    {cached, missing} = Enum.split_with(descriptors, & &1.cached_profile)

    cached_routes =
      Map.new(cached, fn descriptor ->
        {descriptor.geometry_hash,
         attach_profile(descriptor.route, profile_to_elevation(descriptor.cached_profile, :cache))}
      end)

    fetched_routes =
      fetch_missing_profiles(
        missing,
        provider,
        dataset,
        sampling_interval_m,
        maximum_request_points
      )

    descriptors
    |> Enum.map(fn descriptor ->
      Map.fetch!(Map.merge(cached_routes, fetched_routes), descriptor.geometry_hash)
    end)
  rescue
    error ->
      Enum.map(routes, &attach_unavailable(&1, {:enrichment_failed, Exception.message(error)}))
  end

  def geometry_hash(geometry) do
    geometry
    |> Jason.encode!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp fetch_missing_profiles([], _provider, _dataset, _interval, _maximum_points), do: %{}

  defp fetch_missing_profiles(
         missing,
         provider,
         dataset,
         sampling_interval_m,
         maximum_request_points
       ) do
    maximum_samples_per_route = max(div(maximum_request_points, length(missing)), 2)

    with {:ok, samples} <-
           sample_missing_routes(missing, sampling_interval_m, maximum_samples_per_route),
         points <- Enum.flat_map(samples, & &1.points),
         {:ok, elevations} <- provider.elevations(points),
         true <- length(points) == length(elevations) do
      attach_fetched_profiles(samples, elevations, dataset, provider)
    else
      {:error, reason} ->
        Map.new(missing, &{&1.geometry_hash, attach_unavailable(&1.route, reason)})

      false ->
        Map.new(missing, &{&1.geometry_hash, attach_unavailable(&1.route, :unexpected_response)})
    end
  end

  defp sample_missing_routes(missing, sampling_interval_m, maximum_samples_per_route) do
    missing
    |> Enum.reduce_while({:ok, []}, fn descriptor, {:ok, samples} ->
      case RouteSampler.sample(descriptor.route.geometry,
             sampling_interval_m: sampling_interval_m,
             maximum_samples: maximum_samples_per_route
           ) do
        {:ok, sample} ->
          descriptor = descriptor |> Map.put(:sample, sample) |> Map.put(:points, sample.points)
          {:cont, {:ok, [descriptor | samples]}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> then(fn
      {:ok, samples} -> {:ok, Enum.reverse(samples)}
      error -> error
    end)
  end

  defp attach_fetched_profiles(samples, elevations, dataset, provider) do
    {routes, _remaining_elevations} =
      Enum.map_reduce(samples, elevations, fn descriptor, remaining_elevations ->
        {route_elevations, remaining_elevations} =
          Enum.split(remaining_elevations, length(descriptor.points))

        points = Enum.zip_with(descriptor.points, route_elevations, &Map.merge(&1, &2))
        features = Gradient.features(points)

        elevation = %{
          status: :available,
          dataset: dataset,
          source: provider.source(),
          sampling_interval_m: descriptor.sample.sampling_interval_m,
          sample_count: length(points),
          features: features
        }

        attrs = %{
          geometry_hash: descriptor.geometry_hash,
          dataset: dataset,
          route_distance_m: descriptor.sample.route_distance_m,
          sampling_interval_m: descriptor.sample.sampling_interval_m,
          sample_count: length(points),
          samples: %{"points" => points},
          features: features,
          source: provider.source(),
          retrieved_at: DateTime.utc_now(:second)
        }

        _ = Elevations.cache_route_profile(attrs)

        {{descriptor.geometry_hash, attach_profile(descriptor.route, elevation)},
         remaining_elevations}
      end)

    Map.new(routes)
  end

  defp profile_to_elevation(profile, source) do
    %{
      status: :available,
      dataset: profile.dataset,
      source: source,
      sampling_interval_m: profile.sampling_interval_m,
      sample_count: profile.sample_count,
      features: profile.features
    }
  end

  defp attach_profile(%CandidateRoute{} = route, elevation), do: %{route | elevation: elevation}

  defp attach_unavailable(%CandidateRoute{} = route, reason) do
    %{route | elevation: %{status: :unavailable, reason: reason}}
  end
end
