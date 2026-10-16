defmodule WaziRoute.Location.Routing.OpenRouteService do
  @behaviour WaziRoute.Location.Routing

  alias WaziRoute.Location.CandidateRoute

  @default_base_url "https://api.openrouteservice.org"

  @impl true
  def routes({origin_lat, origin_lon}, {destination_lat, destination_lon}, options \\ []) do
    limit = options |> Keyword.get(:limit, 3) |> min(3) |> max(1)

    body = %{
      coordinates: [
        [origin_lon, origin_lat],
        [destination_lon, destination_lat]
      ],
      alternative_routes: %{
        target_count: limit,
        weight_factor: 1.4,
        share_factor: 0.6
      }
    }

    with {:ok, api_key} <- api_key(),
         {:ok, %Req.Response{status: 200, body: %{"features" => features}}} <-
           Req.post(client(),
             url: "/v2/directions/driving-car/geojson",
             headers: [{"authorization", api_key}],
             json: body
           ) do
      routes =
        features
        |> Enum.with_index(1)
        |> Enum.flat_map(&parse_route/1)
        |> Enum.take(limit)

      {:ok, routes}
    else
      {:ok, %Req.Response{status: status, body: response_body}} ->
        {:error, {:provider_error, status, error_message(response_body)}}

      {:error, :missing_api_key} ->
        {:error, :missing_api_key}

      {:error, reason} ->
        {:error, {:request_failed, reason}}

      error ->
        error
    end
  end

  defp client do
    config = Application.get_env(:wazi_route, __MODULE__, [])

    Req.new(
      [
        base_url: Keyword.get(config, :base_url, @default_base_url),
        headers: [{"accept", "application/geo+json"}],
        receive_timeout: 15_000
      ] ++ Keyword.get(config, :req_options, [])
    )
  end

  defp api_key do
    case Application.get_env(:wazi_route, __MODULE__, [])[:api_key] do
      key when is_binary(key) and key != "" -> {:ok, key}
      _ -> {:error, :missing_api_key}
    end
  end

  defp parse_route(
         {%{
            "properties" => %{"summary" => %{"distance" => distance, "duration" => duration}},
            "geometry" => geometry
          }, index}
       )
       when is_number(distance) and is_number(duration) and is_map(geometry) do
    [
      %CandidateRoute{
        id: "route-#{index}",
        distance_m: distance,
        duration_s: duration,
        geometry: geometry
      }
    ]
  end

  defp parse_route(_feature), do: []

  defp error_message(%{"error" => %{"message" => message}}) when is_binary(message), do: message
  defp error_message(%{"error" => message}) when is_binary(message), do: message
  defp error_message(_body), do: "Routing provider returned an unexpected response"
end
