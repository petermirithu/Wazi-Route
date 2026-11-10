defmodule WaziRouteWeb.Admin.EvidenceLive do
  use WaziRouteWeb, :live_view

  alias WaziRoute.Roads
  alias WaziRoute.Roads.OsmCollector

  @impl true
  def mount(_params, _session, socket) do
    evidence = Roads.list_condition_evidence_for_review(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:evidence_count, length(evidence))
     |> assign(:collect_form, collect_form())
     |> stream(:evidence, evidence, dom_id: &"evidence-#{&1.id}")}
  end

  @impl true
  def handle_event("collect-osm", %{"osm_collection" => params}, socket) do
    source_url = String.trim(params["source_url"] || "")

    case OsmCollector.collect(source_url) do
      {:ok, evidence} ->
        evidence_count =
          socket.assigns.current_scope
          |> Roads.list_condition_evidence_for_review()
          |> length()

        {:noreply,
         socket
         |> assign(:collect_form, collect_form())
         |> assign(:evidence_count, evidence_count)
         |> stream_insert(:evidence, evidence, at: 0)
         |> put_flash(:info, "OSM record collected. Review it below before it can affect routing.")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:collect_form, collect_form(%{"source_url" => source_url}))
         |> put_flash(:error, collection_error(reason))}
    end
  end

  @impl true
  def handle_event("review", %{"import-key" => import_key, "decision" => decision}, socket) do
    case Roads.review_condition_evidence(socket.assigns.current_scope, import_key, decision) do
      {:ok, evidence} ->
        {:noreply,
         socket
         |> stream_insert(:evidence, evidence)
         |> put_flash(:info, "Evidence marked as #{evidence.verification_status}.")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "That evidence record is no longer available.")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not allowed to review evidence.")}

      {:error, :invalid_decision} ->
        {:noreply, put_flash(socket, :error, "That review decision is not valid.")}
    end
  end

  defp status_class("verified"), do: "bg-emerald-100 text-emerald-800"
  defp status_class("rejected"), do: "bg-rose-100 text-rose-800"
  defp status_class(_status), do: "bg-amber-100 text-amber-800"

  defp condition_label("smooth"), do: "Smooth"
  defp condition_label("rough"), do: "Rough"
  defp condition_label("unpaved"), do: "Unpaved"
  defp condition_label("obstruction"), do: "Obstruction"
  defp condition_label(condition), do: condition

  defp format_timestamp(nil), do: "Not recorded"
  defp format_timestamp(timestamp), do: Calendar.strftime(timestamp, "%d %b %Y, %H:%M UTC")

  defp source_tags(%{source_details: %{"tags" => tags}}) when is_map(tags) do
    tags
    |> Enum.sort_by(fn {key, _value} -> key end)
    |> Enum.map_join(" · ", fn {key, value} -> "#{key}=#{value}" end)
  end

  defp source_tags(_evidence), do: "No imported OSM tags"

  defp collect_form(params \\ %{"source_url" => ""}), do: to_form(params, as: :osm_collection)

  defp collection_error(:invalid_source_url),
    do: "Paste an OpenStreetMap way URL, for example https://www.openstreetmap.org/way/703287964."

  defp collection_error(:way_not_found), do: "OpenStreetMap could not find that way."
  defp collection_error(:missing_road_name), do: "That way has no road name and cannot be queued."

  defp collection_error(:unsupported_osm_condition_tags),
    do: "That way has no supported smoothness or unpaved-surface tag to support a condition claim."

  defp collection_error({:osm_error, _status}), do: "OpenStreetMap could not provide that record right now."
  defp collection_error({:request_failed, _reason}), do: "OpenStreetMap could not be reached. Please try again."
  defp collection_error(_reason), do: "That OSM record could not be collected. Please check the source and try again."
end
