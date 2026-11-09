defmodule WaziRoute.Roads do
  @moduledoc """
  Verified, time-bounded road-condition evidence used by route scoring.

  An absent record represents unknown condition. It is deliberately never treated
  as smooth road evidence.
  """

  import Ecto.Query, warn: false

  alias WaziRoute.Repo
  alias WaziRoute.Accounts
  alias WaziRoute.Accounts.Scope
  alias WaziRoute.Roads.ConditionEvidence

  def record_condition_evidence(attrs) do
    %ConditionEvidence{}
    |> ConditionEvidence.changeset(attrs)
    |> Repo.insert()
  end

  def import_condition_evidence(attrs) do
    %ConditionEvidence{}
    |> ConditionEvidence.changeset(attrs)
    |> Repo.insert(
      on_conflict:
        {:replace,
         [
           :road_name,
           :road_key,
           :condition,
           :source_type,
           :source_reference,
           :source_details,
           :observed_at,
           :retrieved_at,
           :valid_until,
           :confidence,
           :updated_at
         ]},
      conflict_target: [:import_key],
      returning: true
    )
  end

  def review_imported_condition_evidence(import_key, decision, now \\ DateTime.utc_now(:second))
      when decision in ["verified", "rejected"] do
    case Repo.get_by(ConditionEvidence, import_key: import_key) do
      nil ->
        {:error, :not_found}

      evidence ->
        evidence
        |> Ecto.Changeset.change(verification_status: decision, verified_at: now)
        |> Repo.update()
    end
  end

  def list_condition_evidence_for_review(%Scope{user: user}) do
    if Accounts.has_permission?(user, "road_condition_evidence", "read") do
      from(evidence in ConditionEvidence,
        order_by: [asc: evidence.verification_status, desc: evidence.inserted_at]
      )
      |> Repo.all()
    else
      []
    end
  end

  def review_condition_evidence(%Scope{user: user}, import_key, decision)
      when decision in ["verified", "rejected"] do
    if Accounts.has_permission?(user, "road_condition_evidence", "review") do
      review_imported_condition_evidence(import_key, decision)
    else
      {:error, :unauthorized}
    end
  end

  def review_condition_evidence(%Scope{}, _import_key, _decision), do: {:error, :invalid_decision}

  def active_condition_evidence_by_road_names(road_names, now \\ DateTime.utc_now(:second)) do
    road_keys =
      road_names
      |> Enum.map(&ConditionEvidence.road_key/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    from(evidence in ConditionEvidence,
      where:
        evidence.road_key in ^road_keys and evidence.verification_status == "verified" and
          (is_nil(evidence.valid_until) or evidence.valid_until > ^now),
      order_by: [desc: evidence.observed_at, desc: evidence.verified_at]
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn evidence, latest_by_road ->
      Map.put_new(latest_by_road, evidence.road_key, evidence)
    end)
  end
end
