defmodule WaziRoute.RoutingTest do
  use WaziRoute.DataCase, async: true

  alias WaziRoute.Accounts.Scope
  alias WaziRoute.Routing

  import WaziRoute.AccountsFixtures

  test "uses cautious defaults until a user saves route preferences" do
    scope = user_fixture() |> Scope.for_user()

    preferences = Routing.get_routing_preferences(scope)

    assert preferences.avoid_rough_roads
    assert preferences.avoid_congested_uphill
    assert preferences.prefer_verified_conditions
    assert preferences.max_extra_minutes == 10
    assert preferences.unknown_condition_tolerance == "cautious"

    assert {:ok, saved_preferences} =
             Routing.save_routing_preferences(scope, %{
               avoid_rough_roads: true,
               avoid_congested_uphill: false,
               prefer_verified_conditions: false,
               max_extra_minutes: 15,
               unknown_condition_tolerance: "balanced"
             })

    assert saved_preferences.user_id == scope.user.id
    assert saved_preferences.max_extra_minutes == 15
    assert saved_preferences.unknown_condition_tolerance == "balanced"
  end

  test "validates the detour budget and unknown-road tolerance" do
    scope = user_fixture() |> Scope.for_user()

    assert {:error, changeset} =
             Routing.save_routing_preferences(scope, %{
               max_extra_minutes: 61,
               unknown_condition_tolerance: "always safe"
             })

    assert %{
             max_extra_minutes: ["must be less than or equal to 60"],
             unknown_condition_tolerance: ["is invalid"]
           } =
             errors_on(changeset)
  end
end
