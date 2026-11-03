defmodule WaziRoute.Location.Gradient do
  @moduledoc false

  alias WaziRoute.Location.RouteSampler

  @uphill_threshold_percent 2.0

  def features(points) when length(points) < 2 do
    unavailable_features()
  end

  def features(points) do
    segments =
      points
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(&segment/1)

    valid_segments = Enum.reject(segments, &is_nil/1)

    if valid_segments == [] do
      unavailable_features()
    else
      ascent_m = valid_segments |> Enum.map(&max(&1.rise_m, 0)) |> Enum.sum()

      uphill_segments =
        Enum.filter(valid_segments, &(&1.grade_percent >= @uphill_threshold_percent))

      max_uphill_grade_percent =
        case uphill_segments do
          [] -> 0.0
          _ -> Enum.max_by(uphill_segments, & &1.grade_percent).grade_percent
        end

      %{
        "grade_data_confidence" => Float.round(length(valid_segments) / length(segments), 2),
        "total_ascent_m" => Float.round(ascent_m * 1.0, 1),
        "uphill_distance_m" =>
          Float.round(Enum.sum_by(uphill_segments, & &1.distance_m) * 1.0, 1),
        "max_uphill_grade_percent" => Float.round(max_uphill_grade_percent, 1)
      }
    end
  end

  defp segment([from, to]) do
    with elevation_from when is_number(elevation_from) <- Map.get(from, :elevation_m),
         elevation_to when is_number(elevation_to) <- Map.get(to, :elevation_m),
         distance_m when distance_m > 0 <- RouteSampler.distance_m(from, to) do
      rise_m = elevation_to - elevation_from
      %{rise_m: rise_m, distance_m: distance_m, grade_percent: 100 * rise_m / distance_m}
    else
      _ -> nil
    end
  end

  defp unavailable_features do
    %{
      "grade_data_confidence" => 0.0,
      "total_ascent_m" => 0.0,
      "uphill_distance_m" => 0.0,
      "max_uphill_grade_percent" => 0.0
    }
  end
end
