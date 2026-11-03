defmodule WaziRoute.Location.Elevation.Mock do
  @behaviour WaziRoute.Location.ElevationProvider

  @impl true
  def dataset, do: "test-elevation"

  @impl true
  def source, do: "test"

  @impl true
  def elevations(points) do
    {:ok,
     points
     |> Enum.with_index()
     |> Enum.map(fn {_point, index} -> %{elevation_m: index * 6.0} end)}
  end
end
