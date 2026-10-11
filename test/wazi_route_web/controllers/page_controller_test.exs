defmodule WaziRouteWeb.PageControllerTest do
  use WaziRouteWeb.ConnCase

  setup %{conn: conn} do
    document = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()
    %{document: document}
  end

  test "presents the vehicle-aware product and its core sections", %{document: document} do
    assert document |> LazyHTML.query("main#main-content h1#hero-title") |> Enum.count() == 1

    for id <-
          ~w(why-wazi how-it-works our-story coming-soon feature-vehicle feature-roads feature-hills feature-evidence) do
      assert document |> LazyHTML.query("##{id}") |> Enum.count() == 1
    end

    assert document |> LazyHTML.query("head > title") |> LazyHTML.text() ==
             "Wazi Route — Your kind of route"
  end

  test "account actions use the real authentication routes", %{document: document} do
    assert document |> LazyHTML.query("#sign-in[href='/users/log-in']") |> Enum.count() == 1
    assert document |> LazyHTML.query("#sign-up[href='/users/register']") |> Enum.count() == 1

    assert document |> LazyHTML.query("#hero-get-started[href='/users/register']") |> Enum.count() ==
             1

    assert document |> LazyHTML.query("#launch-cta[href='/users/register']") |> Enum.count() == 1
  end

  test "distinguishes photography from route guidance and explains coverage", %{
    document: document
  } do
    assert document |> LazyHTML.query("#preview-caption") |> LazyHTML.text() =~
             "Photography for inspiration, not live route guidance."

    assert document |> LazyHTML.query("#coverage-note") |> LazyHTML.text() =~
             "Unknown road conditions won't be labelled smooth or safe."
  end

  test "uses the supplied brand and locally hosted responsive photography", %{
    document: document
  } do
    assert document
           |> LazyHTML.query("#nav-brand img[src='/images/wazi-mark.png']")
           |> Enum.count() == 1

    assert document |> LazyHTML.query("#nav-brand img[alt='Wazi Route']") |> Enum.count() == 1

    hero = LazyHTML.query(document, "#hero-photograph img")
    assert LazyHTML.attribute(hero, "src") == ["/images/forest-road.jpg"]
    assert LazyHTML.attribute(hero, "fetchpriority") == ["high"]
    assert hero |> LazyHTML.attribute("srcset") |> hd() =~ "/images/forest-road-small.jpg 900w"

    assert document |> LazyHTML.query("#story-photograph img[loading='lazy']") |> Enum.count() ==
             1
  end

  test "uses the African mobility visual system", %{document: document} do
    assert document |> LazyHTML.query(".wazi-pattern") |> Enum.count() >= 2
    assert document |> LazyHTML.query(".wazi-pattern-light") |> Enum.count() >= 1
    assert document |> LazyHTML.query(".wazi-kitenge-border") |> Enum.count() == 1
    assert document |> LazyHTML.query("#feature-list > article") |> Enum.count() == 4
    assert document |> LazyHTML.query("#journey-steps > li") |> Enum.count() == 3
  end

  test "labels the drive example as illustrative rather than a working planner", %{
    document: document
  } do
    assert document |> LazyHTML.query("#drive-example dl > div") |> Enum.count() == 3

    assert document
           |> LazyHTML.query("#drive-example :is(button, input, select, form)")
           |> Enum.count() == 0

    assert document |> LazyHTML.query("#drive-example-note") |> LazyHTML.text() =~
             "Illustrative preferences, not a live route."

    ids = document |> LazyHTML.query("[id]") |> LazyHTML.attribute("id")
    assert length(ids) == length(Enum.uniq(ids))
  end

  test "navigation points to existing page sections", %{document: document} do
    links = document |> LazyHTML.query("a[href*='#']") |> LazyHTML.attribute("href")
    assert length(links) >= 6

    for href <- links do
      [_path, id] = String.split(href, "#", parts: 2)
      assert document |> LazyHTML.query("##{id}") |> Enum.count() == 1
    end
  end
end
