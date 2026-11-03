defmodule WaziRouteWeb.DrivingPreferencesLiveTest do
  use WaziRouteWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import WaziRoute.AccountsFixtures

  alias WaziRoute.Accounts.Scope
  alias WaziRoute.Routing
  alias WaziRoute.Vehicles

  test "captures a vehicle profile and route preferences", %{conn: conn} do
    user = user_fixture()

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/driving-preferences")

    assert has_element?(view, "#vehicle-profile-form")
    assert has_element?(view, "#routing-preferences-form")
    assert has_element?(view, "#vehicle-profiles[phx-update='stream']")

    view
    |> form("#vehicle-profile-form", %{
      "vehicle_profile" => %{
        "name" => "Daily hatchback",
        "transmission" => "manual",
        "clearance_class" => "low",
        "hill_start_assist" => "false"
      }
    })
    |> render_submit()

    assert has_element?(view, "#vehicle-profiles", "Daily hatchback")
    assert has_element?(view, "#vehicle-profiles", "Default")

    [vehicle] = Vehicles.list_vehicle_profiles(Scope.for_user(user))
    assert vehicle.name == "Daily hatchback"
    assert vehicle.transmission == "manual"
    assert vehicle.clearance_class == "low"

    view
    |> form("#routing-preferences-form", %{
      "routing_preference" => %{
        "avoid_rough_roads" => "true",
        "avoid_congested_uphill" => "true",
        "prefer_verified_conditions" => "false",
        "max_extra_minutes" => "12",
        "unknown_condition_tolerance" => "balanced"
      }
    })
    |> render_submit()

    assert has_element?(view, "#save-routing-preferences")

    saved_preferences = Routing.get_routing_preferences(Scope.for_user(user))
    assert saved_preferences.max_extra_minutes == 12
    assert saved_preferences.unknown_condition_tolerance == "balanced"
    refute saved_preferences.prefer_verified_conditions
  end

  test "requires authentication", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/driving-preferences")
  end
end
