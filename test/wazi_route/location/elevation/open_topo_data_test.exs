defmodule WaziRoute.Location.Elevation.OpenTopoDataTest do
  use ExUnit.Case, async: false

  alias WaziRoute.Location.Elevation.OpenTopoData

  setup do
    previous = Application.get_env(:wazi_route, OpenTopoData)

    Application.put_env(:wazi_route, OpenTopoData,
      dataset: "mapzen",
      req_options: [plug: {Req.Test, __MODULE__}]
    )

    on_exit(fn -> restore_config(OpenTopoData, previous) end)
  end

  test "requests and normalizes a bounded batch of elevation points" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.request_path == "/v1/mapzen"
      assert conn.query_string =~ "locations=-1.2%2C36.8%7C-1.19%2C36.8"

      Req.Test.json(conn, %{
        "status" => "OK",
        "results" => [%{"elevation" => 1_700}, %{"elevation" => 1_720}]
      })
    end)

    assert {:ok, [%{elevation_m: 1_700.0}, %{elevation_m: 1_720.0}]} =
             OpenTopoData.elevations([
               %{latitude: -1.2, longitude: 36.8},
               %{latitude: -1.19, longitude: 36.8}
             ])
  end

  test "rejects batches larger than the public endpoint allows" do
    points = for _ <- 1..101, do: %{latitude: -1.2, longitude: 36.8}

    assert {:error, :too_many_locations} = OpenTopoData.elevations(points)
  end

  defp restore_config(module, nil), do: Application.delete_env(:wazi_route, module)
  defp restore_config(module, config), do: Application.put_env(:wazi_route, module, config)
end
