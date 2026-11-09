defmodule WaziRoute.Accounts.UserRole do
  use Ecto.Schema

  import Ecto.Changeset

  schema "user_roles" do
    field :user_id, :id
    field :role_id, :id
    field :assigned_by_user_id, :id

    timestamps(type: :utc_datetime)
  end

  def changeset(user_role, attrs) do
    user_role
    |> cast(attrs, [:user_id, :role_id, :assigned_by_user_id])
    |> validate_required([:user_id, :role_id])
    |> unique_constraint([:user_id, :role_id])
  end
end
