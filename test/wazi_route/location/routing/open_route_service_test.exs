defmodule WaziRoute.Location.Routing.OpenRouteServiceTest do
  use ExUnit.Case, async: false

  alias WaziRoute.Location.Routing.OpenRouteService

  setup do
    previous = Application.get_env(:wazi_route, OpenRouteService)

    Application.put_env(:wazi_route, OpenRouteService,
      api_key: "ors-test-key",
      req_options: [plug: {Req.Test, __MODULE__}]
    )

    on_exit(fn -> restore_config(OpenRouteService, previous) end)
  end

  test "requests GeoJSON and normalizes and limits route candidates" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert Plug.Conn.get_req_header(conn, "accept") == ["application/geo+json"]

      features =
        for index <- 1..4 do
          %{
            "properties" => %{
              "summary" => %{"distance" => 10_000 + index, "duration" => 1_200 + index},
              "segments" => [
                %{"steps" => [%{"name" => "Waiyaki Way"}, %{"name" => "Red Hill Link Road"}]}
              ]
            },
            "geometry" => %{
              "type" => "LineString",
              "coordinates" => [[36.7784, -1.2044], [36.7384 + index / 10_000, -1.2527]]
            }
          }
        end

      Req.Test.json(conn, %{"features" => features})
    end)

    assert {:ok, routes} =
             OpenRouteService.routes({-1.2044, 36.7784}, {-1.2527, 36.7384}, limit: 3)

    assert length(routes) == 3
    assert Enum.map(routes, & &1.id) == ["route-1", "route-2", "route-3"]
    assert Enum.all?(routes, &(&1.geometry["type"] == "LineString"))
    assert Enum.all?(routes, &(&1.via == ["Waiyaki Way", "Red Hill Link Road"]))
  end

  test "does not duplicate identical route options" do
    route = %{
      "properties" => %{
        "summary" => %{"distance" => 10_000, "duration" => 1_200},
        "segments" => [%{"steps" => [%{"name" => "Limuru Road"}]}]
      },
      "geometry" => %{
        "type" => "LineString",
        "coordinates" => [[36.7784, -1.2044], [36.7384, -1.2527]]
      }
    }

    Req.Test.stub(__MODULE__, fn conn -> Req.Test.json(conn, %{"features" => [route, route]}) end)

    assert {:ok, [candidate]} =
             OpenRouteService.routes({-1.2044, 36.7784}, {-1.2527, 36.7384}, limit: 3)

    assert candidate.via == ["Limuru Road"]
  end

  test "reports a missing API key without making a request" do
    Application.put_env(:wazi_route, OpenRouteService, api_key: nil)

    assert {:error, :missing_api_key} =
             OpenRouteService.routes({-1.2044, 36.7784}, {-1.2527, 36.7384})
  end

  defp restore_config(module, nil), do: Application.delete_env(:wazi_route, module)
  defp restore_config(module, config), do: Application.put_env(:wazi_route, module, config)
end
