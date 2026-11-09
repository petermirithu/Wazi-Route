defmodule WaziRoute.Accounts.RolePermission do
  use Ecto.Schema

  schema "role_permissions" do
    field :role_id, :id
    field :permission_id, :id

    timestamps(type: :utc_datetime)
  end
end
