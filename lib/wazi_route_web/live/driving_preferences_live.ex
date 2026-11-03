defmodule WaziRouteWeb.DrivingPreferencesLive do
  use WaziRouteWeb, :live_view

  alias WaziRoute.Routing
  alias WaziRoute.Vehicles
  alias WaziRoute.Vehicles.VehicleProfile

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:vehicle_form, vehicle_form())
      |> assign(:preference_form, preference_form(socket.assigns.current_scope))
      |> assign(:vehicle_count, 0)
      |> stream(:vehicle_profiles, [])
      |> refresh_vehicle_profiles()

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_vehicle", %{"vehicle_profile" => params}, socket) do
    form =
      %VehicleProfile{}
      |> Vehicles.change_vehicle_profile(params)
      |> Map.put(:action, :validate)
      |> vehicle_form()

    {:noreply, assign(socket, :vehicle_form, form)}
  end

  def handle_event("save_vehicle", %{"vehicle_profile" => params}, socket) do
    case Vehicles.create_vehicle_profile(socket.assigns.current_scope, params) do
      {:ok, _profile} ->
        {:noreply,
         socket
         |> assign(:vehicle_form, vehicle_form())
         |> refresh_vehicle_profiles()
         |> put_flash(:info, "Vehicle profile saved.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :vehicle_form, vehicle_form(changeset, :insert))}
    end
  end

  def handle_event("make_default_vehicle", %{"vehicle-id" => id}, socket) do
    case profile_id(id) do
      {:ok, id} ->
        case Vehicles.make_default_vehicle_profile(socket.assigns.current_scope, id) do
          {:ok, _profile} ->
            {:noreply,
             socket
             |> refresh_vehicle_profiles()
             |> put_flash(:info, "Default vehicle updated.")}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "That vehicle profile is no longer available.")}
        end

      :error ->
        {:noreply, put_flash(socket, :error, "That vehicle profile is no longer available.")}
    end
  end

  def handle_event("delete_vehicle", %{"vehicle-id" => id}, socket) do
    case profile_id(id) do
      {:ok, id} ->
        case Vehicles.delete_vehicle_profile(socket.assigns.current_scope, id) do
          {:ok, _profile} ->
            {:noreply,
             socket
             |> refresh_vehicle_profiles()
             |> put_flash(:info, "Vehicle profile removed.")}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "That vehicle profile is no longer available.")}
        end

      :error ->
        {:noreply, put_flash(socket, :error, "That vehicle profile is no longer available.")}
    end
  end

  def handle_event("validate_preferences", %{"routing_preference" => params}, socket) do
    form =
      socket.assigns.current_scope
      |> Routing.change_routing_preferences(params)
      |> Map.put(:action, :validate)
      |> preference_form()

    {:noreply, assign(socket, :preference_form, form)}
  end

  def handle_event("save_preferences", %{"routing_preference" => params}, socket) do
    case Routing.save_routing_preferences(socket.assigns.current_scope, params) do
      {:ok, _preference} ->
        {:noreply,
         socket
         |> assign(:preference_form, preference_form(socket.assigns.current_scope))
         |> put_flash(:info, "Route preferences saved.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :preference_form, preference_form(changeset, :insert))}
    end
  end

  defp refresh_vehicle_profiles(socket) do
    profiles = Vehicles.list_vehicle_profiles(socket.assigns.current_scope)

    socket
    |> assign(:vehicle_count, length(profiles))
    |> stream(:vehicle_profiles, profiles, reset: true)
  end

  defp vehicle_form(
         changeset \\ Vehicles.change_vehicle_profile(%VehicleProfile{}),
         action \\ nil
       ) do
    changeset = if action, do: Map.put(changeset, :action, action), else: changeset
    to_form(changeset, as: :vehicle_profile)
  end

  defp preference_form(preference_or_changeset, action \\ nil)

  defp preference_form(%Ecto.Changeset{} = changeset, action) do
    changeset = if action, do: Map.put(changeset, :action, action), else: changeset
    to_form(changeset, as: :routing_preference)
  end

  defp preference_form(scope, action) do
    scope
    |> Routing.change_routing_preferences()
    |> preference_form(action)
  end

  defp profile_id(id) do
    case Integer.parse(id) do
      {number, ""} when number > 0 -> {:ok, number}
      _ -> :error
    end
  end

  defp transmission_label("manual"), do: "Manual"
  defp transmission_label("automatic"), do: "Automatic"

  defp clearance_label("low"), do: "Low clearance"
  defp clearance_label("normal"), do: "Normal clearance"
  defp clearance_label("high"), do: "High clearance"
end
