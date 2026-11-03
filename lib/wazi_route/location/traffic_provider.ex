defmodule WaziRoute.Location.TrafficProvider do
  @type point :: %{latitude: float(), longitude: float()}

  @type flow :: %{
          current_speed_kph: float(),
          free_flow_speed_kph: float(),
          confidence: float(),
          road_closure: boolean()
        }

  @callback provider_name() :: String.t()
  @callback available?() :: boolean()
  @callback flow(point()) :: {:ok, flow()} | {:error, term()}
end
