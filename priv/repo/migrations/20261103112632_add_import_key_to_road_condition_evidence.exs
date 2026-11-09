defmodule WaziRoute.Repo.Migrations.AddImportKeyToRoadConditionEvidence do
  use Ecto.Migration

  def change do
    alter table(:road_condition_evidence) do
      add :import_key, :string
      add :source_details, :map
    end

    create unique_index(:road_condition_evidence, [:import_key])
  end
end
