defmodule WaziRoute.Repo.Migrations.CreateRouteElevationProfiles do
  use Ecto.Migration

  def change do
    create table(:route_elevation_profiles) do
      add :geometry_hash, :string, null: false
      add :dataset, :string, null: false
      add :route_distance_m, :float, null: false
      add :sampling_interval_m, :float, null: false
      add :sample_count, :integer, null: false
      add :samples, :map, null: false
      add :features, :map, null: false
      add :source, :string, null: false
      add :retrieved_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:route_elevation_profiles, [:geometry_hash, :dataset])
  end
end
