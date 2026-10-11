defmodule WaziRoute.Repo.Migrations.AddVerificationAttemptsToUserTokens do
  use Ecto.Migration

  def change do
    alter table(:users_tokens) do
      add :attempts, :integer, null: false, default: 0
    end
  end
end
