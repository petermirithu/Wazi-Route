defmodule WaziRoute.Location.Routing.Osrm do
  @behaviour WaziRoute.Location.Routing

  alias WaziRoute.Location.CandidateRoute

  @base_url "https://router.project-osrm.org"

  @impl true
  def routes({origin_lat, origin_lon}, {destination_lat, destination_lon}, options \\ []) do
    limit = options |> Keyword.get(:limit, 3) |> min(3) |> max(1)
    path = "/route/v1/driving/#{origin_lon},#{origin_lat};#{destination_lon},#{destination_lat}"

    Req.get(client(),
      url: path,
      params: [alternatives: limit - 1, overview: "full", geometries: "geojson"]
    )
    |> case do
      {:ok, %Req.Response{status: 200, body: %{"routes" => routes}}} ->
        candidates =
          routes
          |> Enum.with_index(1)
          |> Enum.flat_map(&parse_route/1)
          |> Enum.take(limit)

        {:ok, candidates}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:provider_error, status}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp client do
    Req.new(
      base_url: @base_url,
      headers: [{"user-agent", "Wazi-Route/1.0.0"}],
      receive_timeout: 15_000
    )
  end

  defp parse_route(
         {%{
            "distance" => distance,
            "duration" => duration,
            "geometry" => geometry
          }, index}
       ) do
    [
      %CandidateRoute{
        id: "route-#{index}",
        distance_m: distance,
        duration_s: duration,
        geometry: geometry
      }
    ]
  end

  defp parse_route(_route), do: []
end
