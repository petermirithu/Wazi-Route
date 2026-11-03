defmodule WaziRoute.LocationTest do
  use WaziRoute.DataCase, async: true

  alias WaziRoute.Accounts.Scope
  alias WaziRoute.Location

  import WaziRoute.AccountsFixtures

  test "geocodes both locations and returns at most three routes" do
    scope = user_fixture() |> Scope.for_user()

    assert {:ok, result} =
             Location.plan_routes(scope, "Ruaka, Nairobi", "Loresho, Nairobi")

    assert result.origin.label == "Ruaka, Nairobi"
    assert result.destination.label == "Loresho, Nairobi"
    assert length(result.routes) == 3
    assert Enum.all?(result.routes, &(&1.distance_m > 0 and &1.duration_s > 0))
    assert Enum.all?(result.routes, &(&1.evidence.elevation.status == :available))
  end

  test "returns an explicit error when geocoding has no result" do
    scope = user_fixture() |> Scope.for_user()

    assert {:error, :origin_not_found} =
             Location.plan_routes(scope, "Unknown place", "Loresho, Nairobi")
  end

  test "rejects calls without an authenticated user" do
    assert {:error, :unauthorized} =
             Location.plan_routes(%Scope{}, "Ruaka, Nairobi", "Loresho, Nairobi")
  end
end
