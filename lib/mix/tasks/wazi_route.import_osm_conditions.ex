defmodule Mix.Tasks.WaziRoute.ImportOsmConditions do
  @shortdoc "Imports reviewable OSM road-condition signals"

  use Mix.Task

  alias WaziRoute.Roads.EvidenceImporter

  @impl Mix.Task
  def run([path]) do
    Mix.Task.run("app.start")

    case EvidenceImporter.import_file(path) do
      {:ok, evidence} ->
        Mix.shell().info("Imported #{length(evidence)} reviewable OSM condition record(s).")

      {:error, reason} ->
        Mix.raise("Could not import OSM road-condition evidence: #{inspect(reason)}")
    end
  end

  def run(_args) do
    Mix.raise("Usage: mix wazi_route.import_osm_conditions PATH")
  end
end
