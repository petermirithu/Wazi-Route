defmodule WaziRoute.Location.RouteSampler do
  @moduledoc false

  @earth_radius_m 6_371_000

  def sample(%{"type" => "LineString", "coordinates" => coordinates}, opts)
      when is_list(coordinates) do
    with {:ok, points} <- coordinate_points(coordinates),
         route_distance_m when route_distance_m > 0 <- route_distance_m(points) do
      maximum_samples = Keyword.fetch!(opts, :maximum_samples)
      requested_interval_m = Keyword.fetch!(opts, :sampling_interval_m)
      requested_count = max(trunc(Float.ceil(route_distance_m / requested_interval_m)) + 1, 2)
      sample_count = min(requested_count, maximum_samples)
      sampling_interval_m = route_distance_m / (sample_count - 1)

      {:ok,
       %{
         points:
           Enum.map(
             0..(sample_count - 1),
             &interpolate(points, route_distance_m * &1 / (sample_count - 1))
           ),
         route_distance_m: route_distance_m,
         sampling_interval_m: sampling_interval_m
       }}
    else
      _ -> {:error, :invalid_route_geometry}
    end
  end

  def sample(_geometry, _opts), do: {:error, :invalid_route_geometry}

  def distance_m(%{latitude: from_lat, longitude: from_lon}, %{
        latitude: to_lat,
        longitude: to_lon
      }) do
    latitude_delta = degrees_to_radians(to_lat - from_lat)
    longitude_delta = degrees_to_radians(to_lon - from_lon)
    from_latitude = degrees_to_radians(from_lat)
    to_latitude = degrees_to_radians(to_lat)

    a =
      :math.sin(latitude_delta / 2) ** 2 +
        :math.cos(from_latitude) * :math.cos(to_latitude) * :math.sin(longitude_delta / 2) ** 2

    @earth_radius_m * 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
  end

  defp coordinate_points(coordinates) do
    points =
      Enum.flat_map(coordinates, fn
        [longitude, latitude] when is_number(latitude) and is_number(longitude) ->
          [%{latitude: latitude * 1.0, longitude: longitude * 1.0}]

        _ ->
          []
      end)

    if length(points) >= 2 and length(points) == length(coordinates),
      do: {:ok, points},
      else: :error
  end

  defp route_distance_m(points) do
    points
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [from, to] -> distance_m(from, to) end)
    |> Enum.sum()
  end

  defp interpolate(points, target_distance_m) do
    points
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce_while({0.0, List.last(points)}, fn [from, to], {covered_m, _point} ->
      segment_distance_m = distance_m(from, to)

      if covered_m + segment_distance_m >= target_distance_m do
        ratio = (target_distance_m - covered_m) / segment_distance_m

        {:halt,
         %{
           latitude: from.latitude + (to.latitude - from.latitude) * ratio,
           longitude: from.longitude + (to.longitude - from.longitude) * ratio
         }}
      else
        {:cont, {covered_m + segment_distance_m, to}}
      end
    end)
    |> case do
      %{latitude: _latitude, longitude: _longitude} = point -> point
      {_covered_m, point} -> point
    end
  end

  defp degrees_to_radians(degrees), do: degrees * :math.pi() / 180
end
