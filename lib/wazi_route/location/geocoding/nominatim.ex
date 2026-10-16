defmodule WaziRoute.Location.Geocoding.Nominatim do
  @behaviour WaziRoute.Location.Geocoding

  alias WaziRoute.Location.Place

  @base_url "https://nominatim.openstreetmap.org"

  @impl true
  def search(query, options \\ []) do
    limit = options |> Keyword.get(:limit, 5) |> min(5) |> max(1)

    Req.get(client(),
      url: "/search",
      params: [q: query, format: "jsonv2", countrycodes: "ke", limit: limit]
    )
    |> case do
      {:ok, %Req.Response{status: 200, body: body}} when is_list(body) ->
        {:ok, Enum.flat_map(body, &parse_place/1)}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:provider_error, status}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp client do
    Req.new(
      base_url: @base_url,
      headers: [
        {"user-agent", "Wazi-Route/1.0.0 (routes@waziroute.com)"},
        {"accept", "application/json"}
      ],
      receive_timeout: 10_000
    )
  end

  defp parse_place(%{
         "place_id" => id,
         "display_name" => label,
         "lat" => latitude,
         "lon" => longitude
       }) do
    with {latitude, ""} <- Float.parse(latitude),
         {longitude, ""} <- Float.parse(longitude) do
      [%Place{id: to_string(id), label: label, latitude: latitude, longitude: longitude}]
    else
      _ -> []
    end
  end

  defp parse_place(_result), do: []
end
