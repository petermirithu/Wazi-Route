defmodule WaziRoute.Location do
  alias WaziRoute.Accounts.{Scope, User}
  alias WaziRoute.Location.Elevation
  alias WaziRoute.Location.Place
  alias WaziRoute.Routing.Ranker

  @spec plan_routes(struct(), String.t(), String.t()) ::
          {:ok, %{origin: Place.t(), destination: Place.t(), routes: list()}} | {:error, term()}
  def plan_routes(%Scope{user: %User{}} = scope, origin_query, destination_query)
      when is_binary(origin_query) and is_binary(destination_query) do
    geocoding_provider = Application.fetch_env!(:wazi_route, :geocoding_provider)
    routing_provider = Application.fetch_env!(:wazi_route, :routing_provider)

    with {:ok, origin} <- geocode_first(geocoding_provider, origin_query, :origin_not_found),
         {:ok, destination} <-
           geocode_first(geocoding_provider, destination_query, :destination_not_found),
         {:ok, candidates} <-
           routing_provider.routes(coordinates(origin), coordinates(destination), limit: 3) do
      routes = candidates |> Enum.uniq_by(& &1.geometry) |> Enum.take(3)

      case routes do
        [] ->
          {:error, :no_routes_found}

        _ ->
          case routes |> Elevation.enrich_routes() |> then(&Ranker.rank(scope, &1)) do
            [] ->
              {:error, :no_matching_routes}

            ranked_routes ->
              ranked_routes =
                ranked_routes
                |> Enum.with_index(1)
                |> Enum.map(fn {route, index} -> %{route | id: "route-#{index}"} end)

              {:ok, %{origin: origin, destination: destination, routes: ranked_routes}}
          end
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def plan_routes(%Scope{}, _origin_query, _destination_query), do: {:error, :unauthorized}

  defp geocode_first(provider, query, not_found_error) do
    case String.trim(query) do
      "" ->
        {:error, :invalid_location}

      trimmed_query ->
        case provider.search(trimmed_query, limit: 1) do
          {:ok, [place | _]} -> {:ok, place}
          {:ok, []} -> {:error, not_found_error}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp coordinates(%Place{latitude: latitude, longitude: longitude}),
    do: {latitude, longitude}
end
