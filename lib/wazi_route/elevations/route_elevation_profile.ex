defmodule WaziRoute.Elevations.RouteElevationProfile do
  use Ecto.Schema

  import Ecto.Changeset

  schema "route_elevation_profiles" do
    field :geometry_hash, :string
    field :dataset, :string
    field :route_distance_m, :float
    field :sampling_interval_m, :float
    field :sample_count, :integer
    field :samples, :map
    field :features, :map
    field :source, :string
    field :retrieved_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [
      :geometry_hash,
      :dataset,
      :route_distance_m,
      :sampling_interval_m,
      :sample_count,
      :samples,
      :features,
      :source,
      :retrieved_at
    ])
    |> validate_required([
      :geometry_hash,
      :dataset,
      :route_distance_m,
      :sampling_interval_m,
      :sample_count,
      :samples,
      :features,
      :source,
      :retrieved_at
    ])
    |> validate_number(:route_distance_m, greater_than: 0)
    |> validate_number(:sampling_interval_m, greater_than: 0)
    |> validate_number(:sample_count, greater_than: 1)
    |> unique_constraint([:geometry_hash, :dataset])
  end
end
