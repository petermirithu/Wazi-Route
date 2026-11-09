defmodule Mix.Tasks.WaziRoute.ReviewConditionEvidence do
  @shortdoc "Approves or rejects imported road-condition evidence"

  use Mix.Task

  alias WaziRoute.Roads

  @impl Mix.Task
  def run([import_key, decision]) when decision in ["verified", "rejected"] do
    Mix.Task.run("app.start")

    case Roads.review_imported_condition_evidence(import_key, decision) do
      {:ok, evidence} ->
        Mix.shell().info("Marked #{evidence.import_key} as #{evidence.verification_status}.")

      {:error, :not_found} ->
        Mix.raise("No imported evidence exists for #{inspect(import_key)}.")

      {:error, reason} ->
        Mix.raise("Could not review evidence: #{inspect(reason)}")
    end
  end

  def run(_args) do
    Mix.raise("Usage: mix wazi_route.review_condition_evidence IMPORT_KEY verified|rejected")
  end
end
