defmodule WaziRouteWeb.Admin.EvidenceLiveTest do
  use WaziRouteWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import WaziRoute.AccountsFixtures

  alias WaziRoute.Accounts.Scope
  alias WaziRoute.Roads
  alias WaziRoute.Roads.OsmCollector

  setup do
    previous = Application.get_env(:wazi_route, OsmCollector)

    Application.put_env(:wazi_route, OsmCollector,
      req_options: [plug: {Req.Test, __MODULE__}]
    )

    on_exit(fn -> restore_config(previous) end)
  end

  test "an administrator can approve imported evidence", %{conn: conn} do
    admin = admin_fixture()
    evidence = imported_evidence()

    {:ok, view, _html} = conn |> log_in_user(admin) |> live(~p"/admin/evidence")

    assert has_element?(view, "#evidence-review-title")
    assert has_element?(view, "#admin-evidence-link", "Evidence review")
    assert has_element?(view, "#evidence-#{evidence.id}", "Red Hill Road")
    assert has_element?(view, "#approve-evidence-#{evidence.id}")

    view
    |> element("#approve-evidence-#{evidence.id}")
    |> render_click()

    assert has_element?(view, "#evidence-#{evidence.id}", "verified")
    refute has_element?(view, "#approve-evidence-#{evidence.id}")

    assert [%{verification_status: "verified"}] =
             Roads.list_condition_evidence_for_review(Scope.for_user(admin))
  end

  test "a regular user cannot open the evidence review workspace", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/dashboard"}}} =
             conn |> log_in_user(user_fixture()) |> live(~p"/admin/evidence")
  end

  test "an administrator can collect an OSM source record in the review workspace", %{conn: conn} do
    Req.Test.stub(__MODULE__, fn conn ->
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

    {:ok, view, _html} = conn |> log_in_user(admin_fixture()) |> live(~p"/admin/evidence")

    assert has_element?(view, "#osm-collection-form")

    view
    |> form("#osm-collection-form", %{
      "osm_collection" => %{"source_url" => "https://www.openstreetmap.org/way/703287964"}
    })
    |> render_submit()

    assert has_element?(view, "#evidence-list", "Red Hill Road")
    assert has_element?(view, "button[id^='approve-evidence-']")
  end

  test "an unauthenticated visitor is redirected to log in", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/admin/evidence")
  end

  defp imported_evidence do
    {:ok, evidence} =
      Roads.import_condition_evidence(%{
        import_key: "osm:way:703287964:v9",
        road_name: "Red Hill Road",
        condition: "smooth",
        source_type: "osm",
        source_reference: "https://www.openstreetmap.org/way/703287964",
        source_details: %{
          osm_id: 703_287_964,
          osm_version: 9,
          tags: %{"smoothness" => "good", "surface" => "asphalt"}
        },
        observed_at: ~U[2026-05-22 06:33:19Z],
        retrieved_at: ~U[2026-11-03 09:58:00Z],
        confidence: "0.65",
        verification_status: "unverified"
      })

    evidence
  end

  defp restore_config(nil), do: Application.delete_env(:wazi_route, OsmCollector)
  defp restore_config(config), do: Application.put_env(:wazi_route, OsmCollector, config)
end
