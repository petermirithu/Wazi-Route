defmodule WaziRoute.Location.Geocoding.Geoapify do
  @behaviour WaziRoute.Location.Geocoding

  alias WaziRoute.Location.Place

  @default_base_url "https://api.geoapify.com"

  @impl true
  def search(query, options \\ []) do
    limit = options |> Keyword.get(:limit, 5) |> min(5) |> max(1)

    with {:ok, api_key} <- api_key(),
         {:ok, %Req.Response{status: 200, body: %{"features" => features}}} <-
           Req.get(client(),
             url: "/v1/geocode/search",
             params: %{
               "text" => query,
               "filter" => "countrycode:ke",
               "bias" => "countrycode:ke",
               "limit" => limit,
               "format" => "geojson",
               "apiKey" => api_key
             }
           ) do
      {:ok, Enum.flat_map(features, &parse_place/1)}
    else
      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:provider_error, status, error_message(body)}}

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
        headers: [{"accept", "application/json"}],
        receive_timeout: 10_000
      ] ++ Keyword.get(config, :req_options, [])
    )
  end

  defp api_key do
    case Application.get_env(:wazi_route, __MODULE__, [])[:api_key] do
      key when is_binary(key) and key != "" -> {:ok, key}
      _ -> {:error, :missing_api_key}
    end
  end

  defp parse_place(%{
         "properties" => properties,
         "geometry" => %{"coordinates" => [longitude, latitude]}
       })
       when is_number(latitude) and is_number(longitude) do
    label = properties["formatted"] || properties["address_line1"]

    if is_binary(label) do
      [
        %Place{
          id: to_string(properties["place_id"] || "#{longitude},#{latitude}"),
          label: label,
          latitude: latitude,
          longitude: longitude
        }
      ]
    else
      []
    end
  end

  defp parse_place(_feature), do: []

  defp error_message(%{"message" => message}) when is_binary(message), do: message
  defp error_message(_body), do: "Geocoding provider returned an unexpected response"
end
