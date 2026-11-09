defmodule WaziRoute.Accounts.Permission do
  use Ecto.Schema

  schema "permissions" do
    field :resource, :string
    field :action, :string
    field :description, :string

    timestamps(type: :utc_datetime)
  end
end
