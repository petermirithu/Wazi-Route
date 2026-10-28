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

    assert has_element?(view, "#dashboard-brand")
    refute has_element?(view, "#nav-brand")
    assert has_element?(view, "#profile-menu")
    assert has_element?(view, "#profile-menu a[href='/profile']", "Profile")
    assert has_element?(view, "#profile-menu a[href='/discover']", "Discover Wazi")
    assert has_element?(view, "#profile-menu a[href='/users/log-out']", "Log out")
    assert has_element?(view, "#journey-form")
    assert has_element?(view, "#plan-route-button")
    assert has_element?(view, "#route-map[phx-hook='RouteMap']")
    assert has_element?(view, "#dashboard-workspace.h-dvh")
    assert has_element?(view, "#dashboard-controls")
    assert has_element?(view, "#planner-panel.wazi-planner-sheet[data-state='idle']")
    assert has_element?(view, "label[for='journey_form_starting_point']")
    assert has_element?(view, "label[for='journey_form_destination_point']")
  end

  test "fetches and renders up to three candidate routes", %{conn: conn} do
    user = user_fixture()

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/dashboard")

    view
    |> form("#journey-form", %{
      "journey_form" => %{
        "starting_point" => "Ruaka, Nairobi",
        "destination_point" => "Loresho, Nairobi"
      }
    })
    |> render_submit()

    render_async(view)

    assert has_element?(view, "#planner-results")
    assert has_element?(view, "#planner-panel[data-state='ready']")
    refute has_element?(view, "#journey-form")
    assert has_element?(view, "#candidate-routes > button", "12.9 km")
    assert has_element?(view, "#routes-route-1", "Via Limuru Road")
    assert has_element?(view, "#routes-route-2", "Via Red Hill Link Road · Waiyaki Way")
    assert has_element?(view, "#routes-route-3")
    refute has_element?(view, "#routes-route-4")
    assert view |> element("#routes-route-1") |> render() =~ ~s(aria-pressed="true")

    view
    |> element("#routes-route-2")
    |> render_click()

    assert view |> element("#routes-route-2") |> render() =~ ~s(aria-pressed="true")

    view
    |> element("#back-to-search")
    |> render_click()

    assert has_element?(view, "#journey-form")
    assert has_element?(view, "#journey_form_starting_point[value='Ruaka, Nairobi']")
    assert has_element?(view, "#journey_form_destination_point[value='Loresho, Nairobi']")
    refute has_element?(view, "#planner-results")
  end

  test "shows a useful error when a location cannot be found", %{conn: conn} do
    user = user_fixture()

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/dashboard")

    view
    |> form("#journey-form", %{
      "journey_form" => %{
        "starting_point" => "Unknown place",
        "destination_point" => "Loresho, Nairobi"
      }
    })
    |> render_submit()

    render_async(view)

    assert has_element?(view, "#planner-error", "We couldn't find that starting point")
    refute has_element?(view, "#planner-results")
  end

  test "requires authentication", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/dashboard")
  end

  test "authenticated users can still visit the public landing page", %{conn: conn} do
    conn = conn |> log_in_user(user_fixture()) |> get(~p"/discover")

    assert html_response(conn, 200) =~ "Know the road"
  end
end
