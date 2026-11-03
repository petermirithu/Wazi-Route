defmodule WaziRoute.Elevations do
  @moduledoc """
  Persistent cache for on-demand elevation profiles.

  Elevation is comparatively static, so a profile is reused by route geometry and
  dataset rather than repeatedly requested for every user search.
  """

  alias WaziRoute.Elevations.RouteElevationProfile
  alias WaziRoute.Repo

  def get_route_profile(geometry_hash, dataset) do
    Repo.get_by(RouteElevationProfile, geometry_hash: geometry_hash, dataset: dataset)
  end

  def cache_route_profile(attrs) do
    %RouteElevationProfile{}
    |> RouteElevationProfile.changeset(attrs)
    |> Repo.insert(
      on_conflict:
        {:replace,
         [
           :route_distance_m,
           :sampling_interval_m,
           :sample_count,
           :samples,
           :features,
           :source,
           :retrieved_at,
           :updated_at
         ]},
      conflict_target: [:geometry_hash, :dataset]
    )
  end
end
