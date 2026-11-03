defmodule WaziRoute.Routing.Preference do
  use Ecto.Schema

  import Ecto.Changeset

  alias WaziRoute.Accounts.User

  @unknown_condition_tolerances ~w(cautious balanced open)

  schema "routing_preferences" do
    field :avoid_rough_roads, :boolean, default: true
    field :avoid_congested_uphill, :boolean, default: true
    field :prefer_verified_conditions, :boolean, default: true
    field :max_extra_minutes, :integer, default: 10
    field :unknown_condition_tolerance, :string, default: "cautious"

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  def changeset(preference, attrs) do
    preference
    |> cast(attrs, [
      :avoid_rough_roads,
      :avoid_congested_uphill,
      :prefer_verified_conditions,
      :max_extra_minutes,
      :unknown_condition_tolerance
    ])
    |> validate_required([
      :avoid_rough_roads,
      :avoid_congested_uphill,
      :prefer_verified_conditions,
      :max_extra_minutes,
      :unknown_condition_tolerance
    ])
    |> validate_number(:max_extra_minutes, greater_than_or_equal_to: 0, less_than_or_equal_to: 60)
    |> validate_inclusion(:unknown_condition_tolerance, @unknown_condition_tolerances)
    |> unique_constraint(:user_id)
  end
end
