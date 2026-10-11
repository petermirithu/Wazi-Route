defmodule WaziRouteWeb.DashboardLiveTest do
  use WaziRouteWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import WaziRoute.AccountsFixtures

  test "renders the authenticated workspace", %{conn: conn} do
    user = user_fixture(%{first_name: "Amina", last_name: "Njeri"})

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/dashboard")

    assert has_element?(view, "#dashboard-title", "Habari, Amina.")
    assert has_element?(view, "#profile-menu")
    assert has_element?(view, "#profile-menu a[href='/profile']", "Profile")
    assert has_element?(view, "#profile-menu a[href='/']", "Discover Wazi")
    assert has_element?(view, "#profile-menu a[href='/users/log-out']", "Log out")
  end

  test "requires authentication", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/dashboard")
  end

  test "authenticated users can still visit the public landing page", %{conn: conn} do
    conn = conn |> log_in_user(user_fixture()) |> get(~p"/")

    assert html_response(conn, 200) =~ "Know the road"
  end
end
