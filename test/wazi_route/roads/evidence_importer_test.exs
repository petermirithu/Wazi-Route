defmodule WaziRoute.Roads.EvidenceImporterTest do
  use WaziRoute.DataCase, async: true

  alias WaziRoute.Roads
  alias WaziRoute.Roads.EvidenceImporter

  test "imports tag-supported OSM evidence as inactive pending review" do
    now = DateTime.utc_now(:second)

    assert {:ok, [evidence]} = EvidenceImporter.import_manifest(manifest(now), now)

    assert evidence.import_key == "osm:way:703287964:v9"
    assert evidence.verification_status == "unverified"

    assert evidence.source_details == %{
             "osm_id" => 703_287_964,
             "osm_version" => 9,
             "tags" => %{"smoothness" => "good", "surface" => "asphalt"}
           }

    assert Roads.active_condition_evidence_by_road_names(["Red Hill Road"], now) == %{}
  end

  test "retains a review decision when the same source version is reimported" do
    now = DateTime.utc_now(:second)

    assert {:ok, [imported]} = EvidenceImporter.import_manifest(manifest(now), now)

    assert {:ok, verified} =
             Roads.review_imported_condition_evidence(imported.import_key, "verified", now)

    assert verified.verification_status == "verified"
    assert {:ok, [reimported]} = EvidenceImporter.import_manifest(manifest(now), now)
    assert reimported.id == imported.id
    assert reimported.verification_status == "verified"

    assert %{"red hill road" => %{condition: "smooth"}} =
             Roads.active_condition_evidence_by_road_names(["Red Hill Road"], now)
  end

  test "rejects an unsupported smooth-road claim based on asphalt alone" do
    now = DateTime.utc_now(:second)

    manifest =
      manifest(now)
      |> put_in(["records", Access.at(0), "osm_tags"], %{"surface" => "asphalt"})

    assert {:error, :unsupported_osm_condition_tags} =
             EvidenceImporter.import_manifest(manifest, now)
  end

  test "keeps a historical OSM source record until a later revalidation workflow" do
    now = DateTime.utc_now(:second)
    expired_observed_at = DateTime.add(now, -91, :day)

    assert {:ok, [imported]} =
             EvidenceImporter.import_manifest(manifest(expired_observed_at), now)

    assert is_nil(imported.valid_until)

    assert {:ok, %{verification_status: "verified"}} =
             Roads.review_imported_condition_evidence(imported.import_key, "verified", now)
  end

  test "reads an OSM manifest from disk" do
    path = Path.expand("../../fixtures/road_condition_imports/osm_conditions.json", __DIR__)

    assert {:ok, [evidence]} = EvidenceImporter.import_file(path)
    assert evidence.road_name == "Red Hill Road"
    assert evidence.verification_status == "unverified"
  end

  test "imports and validates the Nairobi northwest pilot corridor dataset" do
    path = Path.expand("../../../priv/road_condition_imports/nairobi_northwest_osm.json", __DIR__)

    assert {:ok, records} = EvidenceImporter.import_file(path)
    assert length(records) == 8

    by_name = Map.new(records, &{&1.road_name, &1})

    assert by_name["Limuru Road"].condition == "rough"
    assert by_name["Limuru Road"].verification_status == "unverified"
    assert by_name["Red Hill Road"].condition == "smooth"
    assert by_name["Red Hill Link Road"].condition == "smooth"
    assert by_name["Lower Kabete Road"].condition == "smooth"
    assert by_name["Waiyaki Way"].condition == "smooth"
    assert by_name["James Gichuru Road"].condition == "smooth"
    assert by_name["Loresho Ridge"].condition == "smooth"
    assert by_name["Kaptagat Road"].condition == "smooth"

    # Approving evidence makes it active for route scoring
    assert {:ok, verified} =
             Roads.review_imported_condition_evidence(
               by_name["Limuru Road"].import_key,
               "verified"
             )

    assert verified.verification_status == "verified"
  end

  defp manifest(observed_at) do
    %{
      "schema_version" => 1,
      "retrieved_at" => DateTime.to_iso8601(observed_at),
      "records" => [
        %{
          "source_record_key" => "osm:way:703287964:v9",
          "road_name" => "Red Hill Road",
          "condition" => "smooth",
          "observed_at" => DateTime.to_iso8601(observed_at),
          "confidence" => 0.65,
          "source_reference" => "https://www.openstreetmap.org/way/703287964",
          "osm_tags" => %{"smoothness" => "good", "surface" => "asphalt"}
        }
      ]
    }
  end
end
