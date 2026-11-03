defmodule WaziRoute.Location.Traffic.TomTomTest do
  use ExUnit.Case, async: false

  alias WaziRoute.Location.Traffic.TomTom

  setup do
    previous = Application.get_env(:wazi_route, TomTom)

    Application.put_env(:wazi_route, TomTom,
      api_key: "tomtom-test-key",
      req_options: [plug: {Req.Test, __MODULE__}]
    )

    on_exit(fn -> restore_config(TomTom, previous) end)
  end

  test "requests and normalizes live flow data for one point" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.request_path == "/traffic/services/4/flowSegmentData/absolute/10/json"
      assert conn.query_string =~ "key=tomtom-test-key"
      assert conn.query_string =~ "point=-1.2044%2C36.7784"

      Req.Test.json(conn, %{
        "flowSegmentData" => %{
          "currentSpeed" => 12,
          "freeFlowSpeed" => 40,
          "confidence" => 0.9,
          "roadClosure" => false
        }
      })
    end)

    assert {:ok, flow} = TomTom.flow(%{latitude: -1.2044, longitude: 36.7784})
    assert flow.current_speed_kph == 12.0
    assert flow.free_flow_speed_kph == 40.0
    assert flow.confidence == 0.9
    refute flow.road_closure
  end

  test "reports a missing key without making a provider request" do
    Application.put_env(:wazi_route, TomTom, api_key: nil)

    assert {:error, :missing_api_key} = TomTom.flow(%{latitude: -1.2044, longitude: 36.7784})
  end

  test "is available only when an API key is configured" do
    assert TomTom.available?()

    Application.put_env(:wazi_route, TomTom, api_key: nil)

    refute TomTom.available?()
  end

  defp restore_config(module, nil), do: Application.delete_env(:wazi_route, module)
  defp restore_config(module, config), do: Application.put_env(:wazi_route, module, config)
end
