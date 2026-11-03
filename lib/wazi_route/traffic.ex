defmodule WaziRoute.Traffic do
  @moduledoc """
  Short-lived traffic observations, cached only until their declared freshness expires.
  """

  import Ecto.Query, warn: false

  alias WaziRoute.Repo
  alias WaziRoute.Traffic.Observation

  def point_key(%{latitude: latitude, longitude: longitude}) do
    "#{Float.round(latitude * 1.0, 5)},#{Float.round(longitude * 1.0, 5)}"
  end

  def fresh_observations(provider, points, now \\ DateTime.utc_now(:second)) do
    point_keys = points |> Enum.map(&point_key/1) |> Enum.uniq()

    from(observation in Observation,
      where:
        observation.provider == ^provider and observation.point_key in ^point_keys and
          observation.expires_at > ^now
    )
    |> Repo.all()
    |> Map.new(&{&1.point_key, &1})
  end

  def cache_observation(attrs) do
    %Observation{}
    |> Observation.changeset(attrs)
    |> Repo.insert(
      on_conflict:
        {:replace,
         [
           :latitude,
           :longitude,
           :current_speed_kph,
           :free_flow_speed_kph,
           :confidence,
           :road_closure,
           :observed_at,
           :expires_at,
           :updated_at
         ]},
      conflict_target: [:provider, :point_key]
    )
  end
end
