defmodule WaziRoute.Repo.Migrations.CreateRbacAuthorizationTables do
  use Ecto.Migration

  def up do
    create table(:roles) do
      add :name, :string, null: false
      add :description, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:roles, [:name])

    create table(:permissions) do
      add :resource, :string, null: false
      add :action, :string, null: false
      add :description, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:permissions, [:resource, :action])

    create table(:role_permissions) do
      add :role_id, references(:roles, on_delete: :delete_all), null: false
      add :permission_id, references(:permissions, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:role_permissions, [:role_id, :permission_id])

    create table(:user_roles) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :role_id, references(:roles, on_delete: :delete_all), null: false
      add :assigned_by_user_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_roles, [:user_id, :role_id])
    create index(:user_roles, [:role_id])

    execute """
    INSERT INTO roles (name, description, inserted_at, updated_at)
    VALUES
      ('admin', 'Can administer evidence and protected workspace features.', NOW(), NOW()),
      ('user', 'Standard signed-in driver account.', NOW(), NOW())
    """

    execute """
    INSERT INTO permissions (resource, action, description, inserted_at, updated_at)
    VALUES
      ('road_condition_evidence', 'read', 'View imported road-condition evidence.', NOW(), NOW()),
      ('road_condition_evidence', 'review', 'Approve or reject imported road-condition evidence.', NOW(), NOW())
    """

    execute """
    INSERT INTO role_permissions (role_id, permission_id, inserted_at, updated_at)
    SELECT roles.id, permissions.id, NOW(), NOW()
    FROM roles
    CROSS JOIN permissions
    WHERE roles.name = 'admin'
    """

    execute """
    INSERT INTO user_roles (user_id, role_id, inserted_at, updated_at)
    SELECT users.id, roles.id, NOW(), NOW()
    FROM users
    CROSS JOIN roles
    WHERE roles.name = 'user'
    """
  end

  def down do
    drop table(:user_roles)
    drop table(:role_permissions)
    drop table(:permissions)
    drop table(:roles)
  end
end
