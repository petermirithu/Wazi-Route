defmodule WaziRoute.Roads do
  @moduledoc """
  Verified, time-bounded road-condition evidence used by route scoring.

  An absent record represents unknown condition. It is deliberately never treated
  as smooth road evidence.
  """

  import Ecto.Query, warn: false

  alias WaziRoute.Repo
  alias WaziRoute.Roads.ConditionEvidence

  def record_condition_evidence(attrs) do
    %ConditionEvidence{}
    |> ConditionEvidence.changeset(attrs)
    |> Repo.insert()
  end

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
