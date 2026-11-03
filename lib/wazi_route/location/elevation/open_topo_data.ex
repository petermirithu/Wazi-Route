defmodule WaziRoute.Location.Elevation.OpenTopoData do
  @behaviour WaziRoute.Location.ElevationProvider

  @default_base_url "https://api.opentopodata.org"
  @default_dataset "mapzen"
  @maximum_locations 100

  @impl true
  def dataset do
    Application.get_env(:wazi_route, __MODULE__, [])[:dataset] || @default_dataset
  end

  @impl true
  def source, do: "open_topo_data"

  @impl true
  def elevations(points) when is_list(points) and length(points) in 1..@maximum_locations do
    with {:ok, %Req.Response{status: 200, body: %{"status" => "OK", "results" => results}}} <-
           Req.get(client(),
             url: "/v1/#{dataset()}",
             params: [
               locations: locations(points),
               interpolation: "bilinear",
               nodata_value: "null"
             ]
           ),
         {:ok, elevations} <- parse_results(results, length(points)) do
      {:ok, elevations}
    else
      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:provider_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}

      error ->
        error
    end
  end

  def elevations(_points), do: {:error, :too_many_locations}

  defp client do
    config = Application.get_env(:wazi_route, __MODULE__, [])

    Req.new(
      [base_url: Keyword.get(config, :base_url, @default_base_url), receive_timeout: 15_000] ++
        Keyword.get(config, :req_options, [])
    )
  end

  defp locations(points) do
    points
    |> Enum.map_join("|", fn point -> "#{point.latitude},#{point.longitude}" end)
  end

  defp parse_results(results, count) when is_list(results) and length(results) == count do
    elevations =
      Enum.map(results, fn result ->
        case result do
          %{"elevation" => elevation} when is_number(elevation) -> %{elevation_m: elevation * 1.0}
          %{"elevation" => nil} -> %{elevation_m: nil}
          _ -> :invalid
        end
      end)

    if :invalid in elevations, do: {:error, :unexpected_response}, else: {:ok, elevations}
  end

  defp parse_results(_results, _count), do: {:error, :unexpected_response}
end
