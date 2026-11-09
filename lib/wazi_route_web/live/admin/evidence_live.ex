defmodule WaziRouteWeb.Admin.EvidenceLive do
  use WaziRouteWeb, :live_view

  alias WaziRoute.Roads

  @impl true
  def mount(_params, _session, socket) do
    evidence = Roads.list_condition_evidence_for_review(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:evidence_count, length(evidence))
     |> stream(:evidence, evidence, dom_id: &"evidence-#{&1.id}")}
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
end
