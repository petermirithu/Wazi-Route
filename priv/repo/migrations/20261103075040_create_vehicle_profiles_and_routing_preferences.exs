defmodule WaziRoute.Repo.Migrations.CreateVehicleProfilesAndRoutingPreferences do
  use Ecto.Migration

  def change do
    create table(:vehicle_profiles) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :transmission, :string, null: false
      add :clearance_class, :string, null: false
      add :hill_start_assist, :boolean, null: false, default: false
      add :is_default, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:vehicle_profiles, [:user_id])
    create unique_index(:vehicle_profiles, [:user_id, :name])

    create unique_index(:vehicle_profiles, [:user_id],
             where: "is_default",
             name: :vehicle_profiles_one_default_per_user
           )

    create table(:routing_preferences) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :avoid_rough_roads, :boolean, null: false, default: true
      add :avoid_congested_uphill, :boolean, null: false, default: true
      add :prefer_verified_conditions, :boolean, null: false, default: true
      add :max_extra_minutes, :integer, null: false, default: 10
      add :unknown_condition_tolerance, :string, null: false, default: "cautious"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:routing_preferences, [:user_id])
  end
end
