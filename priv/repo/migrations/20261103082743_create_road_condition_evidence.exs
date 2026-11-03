defmodule WaziRoute.Repo.Migrations.CreateRoadConditionEvidence do
  use Ecto.Migration

  def change do
    create table(:road_condition_evidence) do
      add :road_name, :string, null: false
      add :road_key, :string, null: false
      add :condition, :string, null: false
      add :source_type, :string, null: false
      add :source_reference, :string, null: false
      add :observed_at, :utc_datetime, null: false
      add :retrieved_at, :utc_datetime, null: false
      add :valid_until, :utc_datetime
      add :confidence, :decimal, precision: 3, scale: 2, null: false
      add :verification_status, :string, null: false, default: "unverified"
      add :verified_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:road_condition_evidence, [:road_key])
    create index(:road_condition_evidence, [:road_key, :verification_status])
  end
end
