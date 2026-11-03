defmodule WaziRoute.RoadsTest do
  use WaziRoute.DataCase, async: true

  alias WaziRoute.Roads

  test "returns only the latest active verified evidence for each road" do
    now = DateTime.utc_now(:second)

    {:ok, _older} =
      Roads.record_condition_evidence(%{
        road_name: "Limuru Road",
        condition: "smooth",
        source_type: "survey",
        source_reference: "pilot-visit-1",
        observed_at: DateTime.add(now, -3, :day),
        retrieved_at: now,
        confidence: "0.80",
        verification_status: "verified",
        verified_at: now
      })

    {:ok, latest} =
      Roads.record_condition_evidence(%{
        road_name: "Limuru Road",
        condition: "rough",
        source_type: "survey",
        source_reference: "pilot-visit-2",
        observed_at: DateTime.add(now, -1, :day),
        retrieved_at: now,
        confidence: "0.90",
        verification_status: "verified",
        verified_at: now
      })

    {:ok, _expired} =
      Roads.record_condition_evidence(%{
        road_name: "Lower Kabete Road",
        condition: "rough",
        source_type: "report",
        source_reference: "report-1",
        observed_at: now,
        retrieved_at: now,
        valid_until: DateTime.add(now, -1, :hour),
        confidence: "0.90",
        verification_status: "verified",
        verified_at: now
      })

    {:ok, _unverified} =
      Roads.record_condition_evidence(%{
        road_name: "Waiyaki Way",
        condition: "rough",
        source_type: "report",
        source_reference: "report-2",
        observed_at: now,
        retrieved_at: now,
        confidence: "0.90",
        verification_status: "unverified"
      })

    evidence =
      Roads.active_condition_evidence_by_road_names(
        [" limuru road ", "Lower Kabete Road", "Waiyaki Way"],
        now
      )

    assert %{"limuru road" => %{id: latest_id, condition: "rough"}} = evidence
    assert latest_id == latest.id
    refute Map.has_key?(evidence, "lower kabete road")
    refute Map.has_key?(evidence, "waiyaki way")
  end
end
