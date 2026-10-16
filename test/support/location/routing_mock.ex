defmodule WaziRoute.Location.Routing.Mock do
  @behaviour WaziRoute.Location.Routing

  alias WaziRoute.Location.CandidateRoute

  @impl true
  def routes(_origin, _destination, options) do
    routes =
      for index <- 1..3 do
        %CandidateRoute{
          id: "route-#{index}",
          distance_m: 12_900 + (index - 1) * 850,
          duration_s: 1_500 + index * 180,
          geometry: %{
            "type" => "LineString",
            "coordinates" => [[36.7784, -1.2044], [36.7384, -1.2527]]
          }
        }
      end

    {:ok, Enum.take(routes, Keyword.get(options, :limit, 3))}
  end
end
