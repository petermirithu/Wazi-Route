defmodule WaziRoute.Roads.EvidenceImporter do
  @moduledoc """
  Imports reviewable OpenStreetMap road-condition signals for the Nairobi pilot.

  An OSM source import is always stored as `unverified`; an administrator must
  approve it before it can influence route scoring.
  """

  alias WaziRoute.Roads
  alias WaziRoute.Repo

  @smoothness_to_smooth ~w(excellent good)
  @smoothness_to_rough ~w(bad very_bad horrible very_horrible impassable)
  @unpaved_surfaces ~w(unpaved compacted fine_gravel gravel dirt earth ground sand)

  def import_file(path, now \\ DateTime.utc_now(:second)) do
    with {:ok, contents} <- File.read(path),
         {:ok, manifest} <- Jason.decode(contents) do
      import_manifest(manifest, now)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def import_manifest(manifest, now \\ DateTime.utc_now(:second))

  def import_manifest(manifest, now) when is_map(manifest) do
    with {:ok, retrieved_at} <- manifest_timestamp(manifest),
         {:ok, records} <- Map.fetch(manifest, "records"),
         true <- is_list(records) or {:error, :invalid_records},
         {:ok, attrs} <- normalize_records(records, retrieved_at) do
      import_records(attrs, now)
    else
      :error -> {:error, :missing_records}
      {:error, _reason} = error -> error
    end
  end

  def import_manifest(_manifest, _now), do: {:error, :invalid_manifest}

  defp import_records(attrs, _now) do
    Repo.transaction(fn ->
      Enum.map(attrs, fn attrs ->
        case Roads.import_condition_evidence(attrs) do
          {:ok, evidence} -> evidence
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end)
    end)
  end

  defp manifest_timestamp(%{"schema_version" => 1, "retrieved_at" => value}) do
    parse_timestamp(value, :invalid_retrieved_at)
  end

  defp manifest_timestamp(_manifest), do: {:error, :invalid_manifest}

  defp normalize_records(records, retrieved_at) do
    records
    |> Enum.reduce_while({:ok, []}, fn record, {:ok, attrs} ->
      case normalize_record(record, retrieved_at) do
        {:ok, record_attrs} -> {:cont, {:ok, [record_attrs | attrs]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, attrs} -> {:ok, Enum.reverse(attrs)}
      {:error, _reason} = error -> error
    end
  end

  defp normalize_record(
         %{
           "source_record_key" => source_record_key,
           "road_name" => road_name,
           "condition" => condition,
           "observed_at" => observed_at,
           "confidence" => confidence,
           "source_reference" => source_reference,
           "osm_tags" => tags
         },
         retrieved_at
       )
       when is_binary(source_record_key) and is_binary(road_name) and is_binary(condition) and
              is_number(confidence) and is_binary(source_reference) and is_map(tags) do
    with {:ok, osm_id, osm_version} <- parse_source_record_key(source_record_key),
         {:ok, observed_at} <- parse_timestamp(observed_at, :invalid_observed_at),
         :ok <- validate_source_reference(source_reference, osm_id),
         :ok <- validate_condition(condition, tags),
         :ok <- validate_confidence(confidence) do
      {:ok,
       %{
         import_key: source_record_key,
         road_name: road_name,
         condition: condition,
         source_type: "osm",
         source_reference: source_reference,
         source_details: %{osm_id: osm_id, osm_version: osm_version, tags: tags},
         observed_at: observed_at,
         retrieved_at: retrieved_at,
         valid_until: nil,
         confidence: confidence,
         verification_status: "unverified"
       }}
    end
  end

  defp normalize_record(_record, _retrieved_at), do: {:error, :invalid_record}

  defp parse_source_record_key(key) do
    case Regex.named_captures(~r/^osm:way:(?<id>\d+):v(?<version>\d+)$/, key) do
      %{"id" => id, "version" => version} ->
        {:ok, String.to_integer(id), String.to_integer(version)}

      nil ->
        {:error, :invalid_source_record_key}
    end
  end

  defp parse_timestamp(value, error) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, timestamp, _offset} -> {:ok, DateTime.truncate(timestamp, :second)}
      {:error, _reason} -> {:error, error}
    end
  end

  defp parse_timestamp(_value, error), do: {:error, error}

  defp validate_source_reference(reference, osm_id) do
    expected_reference = "https://www.openstreetmap.org/way/#{osm_id}"
    if reference == expected_reference, do: :ok, else: {:error, :invalid_source_reference}
  end

  defp validate_condition(condition, tags) do
    case inferred_condition(tags) do
      ^condition -> :ok
      nil -> {:error, :unsupported_osm_condition_tags}
      _other_condition -> {:error, :condition_does_not_match_osm_tags}
    end
  end

  defp validate_confidence(confidence) when confidence >= 0 and confidence <= 1, do: :ok
  defp validate_confidence(_confidence), do: {:error, :invalid_confidence}

  defp inferred_condition(tags) do
    cond do
      Map.get(tags, "smoothness") in @smoothness_to_smooth -> "smooth"
      Map.get(tags, "smoothness") in @smoothness_to_rough -> "rough"
      Map.get(tags, "surface") in @unpaved_surfaces -> "unpaved"
      true -> nil
    end
  end
end
