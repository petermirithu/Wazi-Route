defmodule WaziRoute.Repo.Migrations.CreateTrafficObservations do
  use Ecto.Migration

  def change do
    create table(:traffic_observations) do
      add :provider, :string, null: false
      add :point_key, :string, null: false
      add :latitude, :float, null: false
      add :longitude, :float, null: false
      add :current_speed_kph, :float, null: false
      add :free_flow_speed_kph, :float, null: false
      add :confidence, :decimal, null: false, precision: 3, scale: 2
      add :road_closure, :boolean, null: false, default: false
      add :observed_at, :utc_datetime, null: false
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:traffic_observations, [:provider, :point_key])
    create index(:traffic_observations, [:provider, :expires_at])
  end
end
