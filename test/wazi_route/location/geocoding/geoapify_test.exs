defmodule WaziRoute.Location.Geocoding.GeoapifyTest do
  use ExUnit.Case, async: false

  alias WaziRoute.Location.Geocoding.Geoapify

  setup do
    previous = Application.get_env(:wazi_route, Geoapify)

    Application.put_env(:wazi_route, Geoapify,
      api_key: "geoapify-test-key",
      req_options: [plug: {Req.Test, __MODULE__}]
    )

    on_exit(fn -> restore_config(Geoapify, previous) end)
  end

  test "normalizes GeoJSON search results" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "features" => [
          %{
            "properties" => %{
              "place_id" => "ruaka",
              "formatted" => "Ruaka, Kiambu County, Kenya"
            },
            "geometry" => %{"coordinates" => [36.7784, -1.2044]}
          }
        ]
      })
    end)

    assert {:ok, [place]} = Geoapify.search("Ruaka", limit: 1)
    assert place.id == "ruaka"
    assert place.label == "Ruaka, Kiambu County, Kenya"
    assert place.latitude == -1.2044
    assert place.longitude == 36.7784
  end

  test "reports a missing API key without making a request" do
    Application.put_env(:wazi_route, Geoapify, api_key: nil)

    assert {:error, :missing_api_key} = Geoapify.search("Ruaka")
  end

  defp restore_config(module, nil), do: Application.delete_env(:wazi_route, module)
  defp restore_config(module, config), do: Application.put_env(:wazi_route, module, config)
end
