defmodule WaziRoute.Traffic.Observation do
  use Ecto.Schema

  import Ecto.Changeset

  schema "traffic_observations" do
    field :provider, :string
    field :point_key, :string
    field :latitude, :float
    field :longitude, :float
    field :current_speed_kph, :float
    field :free_flow_speed_kph, :float
    field :confidence, :decimal
    field :road_closure, :boolean, default: false
    field :observed_at, :utc_datetime
    field :expires_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(observation, attrs) do
    observation
    |> cast(attrs, [
      :provider,
      :point_key,
      :latitude,
      :longitude,
      :current_speed_kph,
      :free_flow_speed_kph,
      :confidence,
      :road_closure,
      :observed_at,
      :expires_at
    ])
    |> validate_required([
      :provider,
      :point_key,
      :latitude,
      :longitude,
      :current_speed_kph,
      :free_flow_speed_kph,
      :confidence,
      :road_closure,
      :observed_at,
      :expires_at
    ])
    |> validate_number(:current_speed_kph, greater_than_or_equal_to: 0)
    |> validate_number(:free_flow_speed_kph, greater_than: 0)
    |> validate_number(:confidence, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> unique_constraint([:provider, :point_key])
  end
end
