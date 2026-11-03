defmodule WaziRoute.Location.Traffic.TomTom do
  @behaviour WaziRoute.Location.TrafficProvider

  @default_base_url "https://api.tomtom.com"

  @impl true
  def provider_name, do: "tomtom"

  @impl true
  def available? do
    match?({:ok, _api_key}, api_key())
  end

  @impl true
  def flow(%{latitude: latitude, longitude: longitude}) do
    with {:ok, api_key} <- api_key(),
         {:ok, %Req.Response{status: 200, body: %{"flowSegmentData" => data}}} <-
           Req.get(client(),
             url: "/traffic/services/4/flowSegmentData/absolute/10/json",
             params: [key: api_key, point: "#{latitude},#{longitude}", unit: "kmph"]
           ),
         {:ok, flow} <- parse_flow(data) do
      {:ok, flow}
    else
      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:provider_error, status, body}}

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
      [base_url: Keyword.get(config, :base_url, @default_base_url), receive_timeout: 10_000] ++
        Keyword.get(config, :req_options, [])
    )
  end

  defp api_key do
    case Application.get_env(:wazi_route, __MODULE__, [])[:api_key] do
      key when is_binary(key) and key != "" -> {:ok, key}
      _ -> {:error, :missing_api_key}
    end
  end

  defp parse_flow(%{
         "currentSpeed" => current_speed,
         "freeFlowSpeed" => free_flow_speed,
         "confidence" => confidence,
         "roadClosure" => road_closure
       })
       when is_number(current_speed) and is_number(free_flow_speed) and free_flow_speed > 0 and
              is_number(confidence) and is_boolean(road_closure) do
    {:ok,
     %{
       current_speed_kph: current_speed * 1.0,
       free_flow_speed_kph: free_flow_speed * 1.0,
       confidence: confidence * 1.0,
       road_closure: road_closure
     }}
  end

  defp parse_flow(_data), do: {:error, :unexpected_response}
end
