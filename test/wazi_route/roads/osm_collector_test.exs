defmodule WaziRoute.Roads.OsmCollectorTest do
  use WaziRoute.DataCase, async: false

  alias WaziRoute.Roads.OsmCollector

  setup do
    previous = Application.get_env(:wazi_route, OsmCollector)

    Application.put_env(:wazi_route, OsmCollector,
      req_options: [plug: {Req.Test, __MODULE__}]
    )

    on_exit(fn -> restore_config(previous) end)
  end

  test "collects a supported OSM way as evidence awaiting review" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.request_path == "/api/0.6/way/703287964.json"

      Req.Test.json(conn, %{
        "elements" => [
          %{
            "type" => "way",
            "id" => 703_287_964,
            "version" => 9,
            "timestamp" => "2026-05-22T06:33:19Z",
            "tags" => %{
              "name" => "Red Hill Road",
              "smoothness" => "good",
              "surface" => "asphalt"
            }
          }
        ]
      })
    end)

    now = ~U[2026-11-10 09:30:00Z]

    assert {:ok, evidence} =
             OsmCollector.collect("https://www.openstreetmap.org/way/703287964", now)

    assert evidence.import_key == "osm:way:703287964:v9"
    assert evidence.road_name == "Red Hill Road"
    assert evidence.condition == "smooth"
    assert evidence.verification_status == "unverified"
    assert evidence.retrieved_at == now
  end

  test "does not collect arbitrary URLs or unsupported OSM tags" do
    assert {:error, :invalid_source_url} = OsmCollector.collect("https://example.com/way/12")

    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "elements" => [
          %{
            "type" => "way",
            "id" => 12,
            "version" => 1,
            "timestamp" => "2026-11-10T09:30:00Z",
            "tags" => %{"name" => "Unclassified Road", "surface" => "asphalt"}
          }
        ]
      })
    end)

    assert {:error, :unsupported_osm_condition_tags} =
             OsmCollector.collect("https://www.openstreetmap.org/way/12")
  end

  defp restore_config(nil), do: Application.delete_env(:wazi_route, OsmCollector)
  defp restore_config(config), do: Application.put_env(:wazi_route, OsmCollector, config)
end
