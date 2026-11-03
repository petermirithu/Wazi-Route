defmodule WaziRoute.Vehicles.VehicleProfile do
  use Ecto.Schema

  import Ecto.Changeset

  alias WaziRoute.Accounts.User

  @transmissions ~w(manual automatic)
  @clearance_classes ~w(low normal high)

  schema "vehicle_profiles" do
    field :name, :string
    field :transmission, :string, default: "manual"
    field :clearance_class, :string, default: "normal"
    field :hill_start_assist, :boolean, default: false
    field :is_default, :boolean, default: false

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  def changeset(vehicle_profile, attrs) do
    vehicle_profile
    |> cast(attrs, [:name, :transmission, :clearance_class, :hill_start_assist])
    |> validate_required([:name, :transmission, :clearance_class])
    |> validate_length(:name, max: 60)
    |> validate_inclusion(:transmission, @transmissions)
    |> validate_inclusion(:clearance_class, @clearance_classes)
    |> unique_constraint(:name, name: :vehicle_profiles_user_id_name_index)
  end
end
