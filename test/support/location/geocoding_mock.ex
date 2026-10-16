defmodule WaziRoute.Location.Geocoding.Mock do
  @behaviour WaziRoute.Location.Geocoding

  alias WaziRoute.Location.Place

  @impl true
  def search("Unknown place", _options), do: {:ok, []}

  def search(query, _options) do
    coordinates =
      if String.contains?(query, "Loresho") do
        {-1.2527, 36.7384}
      else
        {-1.2044, 36.7784}
      end

    {latitude, longitude} = coordinates

    {:ok,
     [
       %Place{
         id: String.downcase(String.replace(query, " ", "-")),
         label: query,
         latitude: latitude,
         longitude: longitude
       }
     ]}
  end
end
