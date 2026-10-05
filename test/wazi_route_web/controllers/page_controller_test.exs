defmodule WaziRouteWeb.PageControllerTest do
  use WaziRouteWeb.ConnCase

  setup %{conn: conn} do
    document = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()
    %{document: document}
  end

  test "welcomes drivers with the product's vehicle-aware purpose", %{document: document} do
    assert document |> LazyHTML.query("main#main-content h1#hero-title") |> Enum.count() == 1

    for id <-
          ~w(why-wazi how-it-works our-story coming-soon feature-vehicle feature-roads feature-hills feature-evidence) do
      assert document |> LazyHTML.query("##{id}") |> Enum.count() == 1
    end

    assert document |> LazyHTML.query("head > title") |> LazyHTML.text() ==
             "Wazi Route — Your kind of route"
  end

  test "account actions link to an honest notice rather than missing authentication routes", %{
    document: document
  } do
    for id <- ~w(sign-in sign-up hero-get-started launch-cta) do
      link = LazyHTML.query(document, "##{id}[data-coming-soon]")
      assert Enum.count(link) == 1
      assert link |> LazyHTML.attribute("href") |> hd() |> String.ends_with?("#coming-soon")
    end

    assert document |> LazyHTML.query("#launch-description") |> LazyHTML.text() =~
             "No account details are being collected."

    assert document
           |> LazyHTML.query(
             "dialog#launch-dialog[aria-labelledby='launch-title'] form[method='dialog'] #close-launch-dialog"
           )
           |> Enum.count() == 1
  end

  test "distinguishes photography from route guidance and explains coverage", %{
    document: document
  } do
    assert document |> LazyHTML.query("#preview-caption") |> LazyHTML.text() =~
             "Photography for inspiration, not live route guidance."

    assert document |> LazyHTML.query("#coverage-note") |> LazyHTML.text() =~
             "Unknown road conditions won't be labelled smooth or safe."
  end

  test "uses the supplied logo and locally hosted responsive photography", %{document: document} do
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

    assert document |> LazyHTML.query("[class*='tracking-'], .badge, .eyebrow") |> Enum.count() ==
             0
  end

  test "uses theme-based utilities and viewport gutters without page-specific CSS classes", %{
    document: document
  } do
    assert document |> LazyHTML.query("#site-frame main#main-content") |> Enum.count() == 1

    body_classes =
      document |> LazyHTML.query("body") |> LazyHTML.attribute("class") |> hd() |> String.split()

    assert Enum.all?(~w(p-3 sm:p-5 lg:p-8), &(&1 in body_classes))

    assert document
           |> LazyHTML.query(
             ".site-frame, .journey-hero, .hero-photograph, .action, .launch-dialog"
           )
           |> Enum.count() == 0

    assert document |> LazyHTML.query("#close-launch-dialog:not([href])") |> Enum.count() == 1

    assert document |> LazyHTML.query("a#hero-get-started[href='#coming-soon']") |> Enum.count() ==
             1
  end

  test "reserves sculpted cutouts for photographs, not content panels", %{document: document} do
    for id <- ~w(road-photo-shape story-photo-shape) do
      assert document |> LazyHTML.query("clipPath##{id} path") |> Enum.count() == 1
    end

    assert document |> LazyHTML.query("figure[class*='clip-path'] img") |> Enum.count() == 2
    assert document |> LazyHTML.query(":not(figure)[class*='clip-path']") |> Enum.count() == 0
    assert document |> LazyHTML.query("#journey-trail") |> Enum.count() == 0

    assert document
           |> LazyHTML.query("#road-detail-photograph img[loading='lazy']")
           |> LazyHTML.attribute("src") == ["/images/sunlit-road.jpg"]

    assert document |> LazyHTML.query("#feature-list > article") |> Enum.count() == 4
    assert document |> LazyHTML.query("#journey-steps > li") |> Enum.count() == 3

    assert document
           |> LazyHTML.query("#feature-evidence a[href='#coverage-note']")
           |> Enum.count() == 1

    assert document
           |> LazyHTML.query("#coming-soon #launch-cta[data-coming-soon]")
           |> Enum.count() == 1
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
    assert length(links) >= 8

    for href <- links do
      [_path, id] = String.split(href, "#", parts: 2)
      assert document |> LazyHTML.query("##{id}") |> Enum.count() == 1
    end
  end
end
