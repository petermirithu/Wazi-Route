defmodule WaziRouteWeb.DashboardLive do
  use WaziRouteWeb, :live_view

  alias WaziRoute.Location

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       form: planner_form(),
       planner_state: :idle,
       planner_error: nil,
       origin: nil,
       destination: nil,
       route_count: 0,
       route_options: [],
       selected_route_id: nil,
       selected_route: nil,
       sheet_collapsed: false
     )
     |> stream(:routes, [])
     |> stream(:route_tabs, [])}
  end

  @impl true
  def handle_event("submit", %{"journey_form" => params}, socket) do
    origin = String.trim(params["starting_point"] || "")
    destination = String.trim(params["destination_point"] || "")

    if origin == "" or destination == "" do
      {:noreply,
       assign(socket,
         form: planner_form(params),
         planner_state: :error,
         planner_error: "Enter both a starting point and destination."
       )}
    else
      current_scope = socket.assigns.current_scope

      {:noreply,
       socket
       |> assign(
         form: planner_form(params),
         planner_state: :loading,
         planner_error: nil,
         origin: nil,
         destination: nil,
         route_count: 0,
         route_options: [],
         selected_route_id: nil,
         selected_route: nil,
         sheet_collapsed: false
       )
       |> stream(:routes, [], reset: true)
       |> stream(:route_tabs, [], reset: true)
       |> push_event("route-cleared", %{})
       |> start_async(:plan_routes, fn ->
         Location.plan_routes(current_scope, origin, destination)
       end)}
    end
  end

  @impl true
  def handle_event("validate", %{"journey_form" => params}, socket) do
    {:noreply, assign(socket, :form, planner_form(params))}
  end

  def handle_event("toggle-sheet", _params, socket) do
    {:noreply, assign(socket, :sheet_collapsed, !socket.assigns.sheet_collapsed)}
  end

  def handle_event("set-sheet", %{"collapsed" => collapsed}, socket) do
    {:noreply, assign(socket, :sheet_collapsed, collapsed == true)}
  end

  def handle_event("reset-search", _params, socket) do
    {:noreply,
     socket
     |> assign(
       planner_state: :idle,
       planner_error: nil,
       origin: nil,
       destination: nil,
       route_count: 0,
       route_options: [],
       selected_route_id: nil,
       selected_route: nil,
       sheet_collapsed: false
     )
     |> stream(:routes, [], reset: true)
     |> stream(:route_tabs, [], reset: true)
     |> push_event("route-cleared", %{})}
  end

  def handle_event("select-route", %{"route-id" => route_id}, socket) do
    case Enum.find(socket.assigns.route_options, &(&1.id == route_id)) do
      nil ->
        {:noreply, socket}

      route ->
        {:noreply,
         socket
         |> assign(selected_route_id: route.id, selected_route: route)
         |> stream(:routes, socket.assigns.route_options, reset: true)
         |> stream(:route_tabs, socket.assigns.route_options, reset: true)
         |> push_event("route-selected", %{id: route.id})}
    end
  end

  @impl true
  def handle_async(:plan_routes, {:ok, {:ok, result}}, socket) do
    [selected_route | _] = result.routes

    {:noreply,
     socket
     |> assign(
       planner_state: :ready,
       planner_error: nil,
       origin: result.origin,
       destination: result.destination,
       route_count: length(result.routes),
       route_options: result.routes,
       selected_route_id: selected_route.id,
       selected_route: selected_route,
       sheet_collapsed: false
     )
     |> stream(:routes, result.routes, reset: true)
     |> stream(:route_tabs, result.routes, reset: true)
     |> push_event("routes-found", %{
       routes: Enum.map(result.routes, &%{id: &1.id, geometry: &1.geometry}),
       selected_id: selected_route.id,
       origin: [result.origin.latitude, result.origin.longitude],
       destination: [result.destination.latitude, result.destination.longitude]
     })}
  end

  def handle_async(:plan_routes, {:ok, {:error, reason}}, socket) do
    {:noreply,
     assign(socket,
       planner_state: :error,
       planner_error: error_message(reason),
       route_count: 0
     )}
  end

  def handle_async(:plan_routes, {:exit, _reason}, socket) do
    {:noreply,
     assign(socket,
       planner_state: :error,
       planner_error: "Route planning is temporarily unavailable. Please try again.",
       route_count: 0
     )}
  end

  defp planner_form(params \\ %{"starting_point" => "", "destination_point" => ""}) do
    to_form(params, as: :journey_form)
  end

  defp error_message(:missing_api_key),
    do: "Route planning needs its provider API keys configured."

  defp error_message(:origin_not_found),
    do: "We couldn't find that starting point. Try adding the area or city."

  defp error_message(:destination_not_found),
    do: "We couldn't find that destination. Try adding the area or city."

  defp error_message(:no_routes_found),
    do: "No driving routes were found between those locations."

  defp error_message(:no_matching_routes),
    do: "No candidate route meets your current comfort and detour preferences."

  defp error_message(_reason),
    do: "Route planning is temporarily unavailable. Please try again."

  defp format_distance(distance_m), do: "#{Float.round(distance_m / 1000, 1)} km"

  defp format_via([]), do: "Direct route"
  defp format_via(roads), do: "Via #{Enum.join(roads, " · ")}"

  defp route_label("route-" <> number), do: "Route #{number}"
  defp route_label(_id), do: "Route option"

  defp format_duration(duration_s) do
    minutes = duration_s |> Kernel./(60) |> Float.ceil() |> trunc()

    case div(minutes, 60) do
      0 -> "#{minutes} min"
      hours -> "#{hours} hr #{rem(minutes, 60)} min"
    end
  end

  defp evidence_coverage_label(%{coverage: :full}),
    do: "Verified condition evidence covers named roads"

  defp evidence_coverage_label(%{coverage: :partial}), do: "Condition evidence is partial"
  defp evidence_coverage_label(%{coverage: :unknown}), do: "Road condition is unknown"
  defp evidence_coverage_label(_evidence), do: "Road condition is unknown"

  defp evidence_condition_label("smooth"), do: "recently verified smooth"
  defp evidence_condition_label("rough"), do: "rough-road evidence"
  defp evidence_condition_label("unpaved"), do: "unpaved-road evidence"
  defp evidence_condition_label("obstruction"), do: "obstruction evidence"

  defp elevation_status_label(%{status: :available}), do: "Directional elevation estimate"
  defp elevation_status_label(_elevation), do: "Elevation data is unavailable for this route"

  defp elevation_feature(elevation, feature) do
    features = Map.get(elevation, :features, %{})
    Map.get(features, Atom.to_string(feature), Map.get(features, feature, 0.0))
  end

  defp format_metres(value), do: "#{Float.round(value * 1.0, 0)} m"
  defp format_grade(value), do: "#{Float.round(value * 1.0, 1)}%"
end
