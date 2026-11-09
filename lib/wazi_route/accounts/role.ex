defmodule WaziRoute.Accounts.Role do
  use Ecto.Schema

  schema "roles" do
    field :name, :string
    field :description, :string

    timestamps(type: :utc_datetime)
  end
end
