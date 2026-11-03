defmodule WaziRoute.Roads.ConditionEvidence do
  use Ecto.Schema

  import Ecto.Changeset

  @conditions ~w(smooth rough unpaved obstruction)
  @source_types ~w(osm report survey)
  @verification_statuses ~w(unverified verified rejected)

  schema "road_condition_evidence" do
    field :road_name, :string
    field :road_key, :string
    field :condition, :string
    field :source_type, :string
    field :source_reference, :string
    field :observed_at, :utc_datetime
    field :retrieved_at, :utc_datetime
    field :valid_until, :utc_datetime
    field :confidence, :decimal
    field :verification_status, :string, default: "unverified"
    field :verified_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(evidence, attrs) do
    evidence
    |> cast(attrs, [
      :road_name,
      :condition,
      :source_type,
      :source_reference,
      :observed_at,
      :retrieved_at,
      :valid_until,
      :confidence,
      :verification_status,
      :verified_at
    ])
    |> update_change(:road_name, &String.trim/1)
    |> put_road_key()
    |> validate_required([
      :road_name,
      :road_key,
      :condition,
      :source_type,
      :source_reference,
      :observed_at,
      :retrieved_at,
      :confidence,
      :verification_status
    ])
    |> validate_length(:road_name, max: 160)
    |> validate_length(:source_reference, max: 500)
    |> validate_inclusion(:condition, @conditions)
    |> validate_inclusion(:source_type, @source_types)
    |> validate_inclusion(:verification_status, @verification_statuses)
    |> validate_number(:confidence, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
  end

  def road_key(road_name) when is_binary(road_name) do
    road_name
    |> String.trim()
    |> String.downcase()
  end

  defp put_road_key(changeset) do
    case get_field(changeset, :road_name) do
      road_name when is_binary(road_name) and road_name != "" ->
        put_change(changeset, :road_key, road_key(road_name))

      _ ->
        changeset
    end
  end
end
