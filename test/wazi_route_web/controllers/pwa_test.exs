defmodule WaziRouteWeb.PWATest do
  use WaziRouteWeb.ConnCase

  test "serves a standalone manifest with install icons", %{conn: conn} do
    conn = get(conn, ~p"/manifest.json")
    manifest = conn |> response(200) |> Jason.decode!()

    assert manifest["id"] == "/"
    assert manifest["start_url"] == "/"
    assert manifest["scope"] == "/"
    assert manifest["display"] == "standalone"
    assert get_resp_header(conn, "cache-control") == ["no-cache"]

    for size <- ["192x192", "512x512"] do
      assert Enum.any?(manifest["icons"], &(&1["sizes"] == size and &1["purpose"] == "any"))
    end

    assert Enum.any?(manifest["icons"], &(&1["purpose"] == "maskable"))

    for icon <- manifest["icons"] do
      icon_conn = get(build_conn(), icon["src"])
      assert get_resp_header(icon_conn, "content-type") == ["image/png"]
      assert <<137, 80, 78, 71, 13, 10, 26, 10, _::binary>> = response(icon_conn, 200)
    end
  end

  test "serves the root worker as revalidated JavaScript", %{conn: conn} do
    conn = get(conn, ~p"/sw.js")
    assert response(conn, 200) =~ "addEventListener(\"fetch\""
    assert get_resp_header(conn, "cache-control") == ["no-cache"]
    assert Enum.any?(get_resp_header(conn, "content-type"), &String.contains?(&1, "javascript"))
  end

  test "provides Apple install metadata and manual installation help", %{conn: conn} do
    page = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()

    assert page |> LazyHTML.query("link[rel='manifest']") |> LazyHTML.attribute("href") == [
             "/manifest.json"
           ]

    assert page
           |> LazyHTML.query("meta[name='apple-mobile-web-app-capable']")
           |> LazyHTML.attribute("content") == ["yes"]

    assert page |> LazyHTML.query("link[rel='apple-touch-icon']") |> LazyHTML.attribute("href") ==
             ["/images/logos/apple-touch-icon.png"]

    assert page |> LazyHTML.query("#ios-install-help") |> LazyHTML.text() =~ "Add to Home Screen"
    assert page |> LazyHTML.query("#android-install-help") |> LazyHTML.text() =~ "Install app"
    assert page |> LazyHTML.query("button#pwa-install[hidden]") |> Enum.count() == 1
    assert get(build_conn(), ~p"/images/logos/apple-touch-icon.png") |> response(200) != ""
  end

  test "offline fallback is static, anonymous, and offers a retry", %{conn: conn} do
    conn = get(conn, ~p"/offline.html")
    page = conn |> html_response(200) |> LazyHTML.from_document()

    assert page |> LazyHTML.query("#offline-content") |> LazyHTML.text() =~
             "aren't available offline"

    assert page |> LazyHTML.query("a#offline-retry") |> LazyHTML.attribute("href") == ["/"]
    assert page |> LazyHTML.query("meta[name='csrf-token'], script") |> Enum.count() == 0
    assert get_resp_header(conn, "set-cookie") == []
    assert get_resp_header(conn, "cache-control") == ["no-cache"]
  end
end
