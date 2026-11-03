defmodule WaziRoute.Location.ElevationProvider do
  @type point :: %{latitude: float(), longitude: float()}
  @type elevation :: %{elevation_m: float() | nil}

  @callback dataset() :: String.t()
  @callback source() :: String.t()
  @callback elevations([point()]) :: {:ok, [elevation()]} | {:error, term()}
end
