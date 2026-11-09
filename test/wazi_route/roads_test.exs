defmodule WaziRoute.RoadsTest do
  use WaziRoute.DataCase, async: true

  alias WaziRoute.Roads

  import WaziRoute.AccountsFixtures
  alias WaziRoute.Accounts.Scope

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

  test "permits only an admin scope to review imported evidence" do
    admin = admin_fixture()
    user = user_fixture()

    {:ok, evidence} =
      Roads.import_condition_evidence(%{
        import_key: "osm:way:703287964:v9",
        road_name: "Red Hill Road",
        condition: "smooth",
        source_type: "osm",
        source_reference: "https://www.openstreetmap.org/way/703287964",
        observed_at: ~U[2026-05-22 06:33:19Z],
        retrieved_at: ~U[2026-11-03 09:58:00Z],
        confidence: "0.65",
        verification_status: "unverified"
      })

    assert Roads.list_condition_evidence_for_review(Scope.for_user(user)) == []

    assert {:error, :unauthorized} =
             Roads.review_condition_evidence(
               Scope.for_user(user),
               evidence.import_key,
               "verified"
             )

    assert {:ok, %{verification_status: "verified"}} =
             Roads.review_condition_evidence(
               Scope.for_user(admin),
               evidence.import_key,
               "verified"
             )
  end
end
