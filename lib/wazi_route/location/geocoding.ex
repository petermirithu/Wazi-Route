defmodule WaziRoute.Location.Geocoding do
  alias WaziRoute.Location.Place

  @callback search(query :: String.t(), options :: keyword()) ::
              {:ok, [Place.t()]} | {:error, term()}
end
