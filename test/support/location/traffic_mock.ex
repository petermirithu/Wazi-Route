defmodule WaziRoute.Location.Traffic.Mock do
  @behaviour WaziRoute.Location.TrafficProvider

  @impl true
  def provider_name, do: "test-traffic"

  @impl true
  def available?, do: true

  @impl true
  def flow(_point) do
    {:ok,
     %{
       current_speed_kph: 12.0,
       free_flow_speed_kph: 40.0,
       confidence: 0.9,
       road_closure: false
     }}
  end
end
