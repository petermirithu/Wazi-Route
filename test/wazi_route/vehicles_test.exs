defmodule WaziRoute.VehiclesTest do
  use WaziRoute.DataCase, async: true

  alias WaziRoute.Accounts.Scope
  alias WaziRoute.Vehicles

  import WaziRoute.AccountsFixtures

  test "creates user-scoped profiles and makes the first one the default" do
    scope = user_fixture() |> Scope.for_user()
    other_scope = user_fixture() |> Scope.for_user()

    assert {:ok, first_profile} =
             Vehicles.create_vehicle_profile(scope, %{
               name: "Daily car",
               transmission: "manual",
               clearance_class: "low",
               hill_start_assist: false
             })

    assert first_profile.is_default

    assert {:ok, second_profile} =
             Vehicles.create_vehicle_profile(scope, %{
               name: "Weekend car",
               transmission: "automatic",
               clearance_class: "high",
               hill_start_assist: true
             })

    refute second_profile.is_default
    assert [listed_first_profile, listed_second_profile] = Vehicles.list_vehicle_profiles(scope)
    assert listed_first_profile.id == first_profile.id
    assert listed_second_profile.id == second_profile.id
    assert [] = Vehicles.list_vehicle_profiles(other_scope)
  end

  test "changes and preserves exactly one default profile" do
    scope = user_fixture() |> Scope.for_user()

    {:ok, first_profile} =
      Vehicles.create_vehicle_profile(scope, %{
        name: "Daily car",
        transmission: "manual",
        clearance_class: "low"
      })

    {:ok, second_profile} =
      Vehicles.create_vehicle_profile(scope, %{
        name: "Weekend car",
        transmission: "automatic",
        clearance_class: "high"
      })

    assert {:ok, %{id: second_id, is_default: true}} =
             Vehicles.make_default_vehicle_profile(scope, second_profile.id)

    assert [%{id: ^second_id, is_default: true}, %{id: first_id, is_default: false}] =
             Vehicles.list_vehicle_profiles(scope)

    assert {:ok, %{id: ^second_id}} = Vehicles.delete_vehicle_profile(scope, second_profile.id)
    assert [%{id: ^first_id, is_default: true}] = Vehicles.list_vehicle_profiles(scope)
    assert first_id == first_profile.id
  end

  test "validates the vehicle attributes" do
    scope = user_fixture() |> Scope.for_user()

    assert {:error, changeset} =
             Vehicles.create_vehicle_profile(scope, %{
               name: "",
               transmission: "electric",
               clearance_class: "very low"
             })

    assert %{
             name: ["can't be blank"],
             transmission: ["is invalid"],
             clearance_class: ["is invalid"]
           } =
             errors_on(changeset)
  end
end
