defmodule WaziRoute.Roads.OsmCollector do
  @moduledoc """
  Fetches one OpenStreetMap way and turns its condition tags into reviewable
  road evidence. Collection never approves the evidence; an administrator must
  review the queued record separately.
  """

  alias WaziRoute.Roads

  @default_base_url "https://www.openstreetmap.org"
  @smoothness_to_smooth ~w(excellent good)
  @smoothness_to_rough ~w(bad very_bad horrible very_horrible impassable)
  @unpaved_surfaces ~w(unpaved compacted fine_gravel gravel dirt earth ground sand)

  def collect(source_url, now \\ DateTime.utc_now(:second)) when is_binary(source_url) do
    with {:ok, way_id} <- way_id_from_url(source_url),
         {:ok, %Req.Response{status: 200, body: body}} <- Req.get(client(), url: "/api/0.6/way/#{way_id}.json"),
         {:ok, attrs} <- attrs_from_response(body, way_id, now) do
      Roads.import_condition_evidence(attrs)
    else
      {:ok, %Req.Response{status: 404}} -> {:error, :way_not_found}
      {:ok, %Req.Response{status: status}} -> {:error, {:osm_error, status}}
      {:error, reason} when is_atom(reason) -> {:error, reason}
      {:error, reason} -> {:error, {:request_failed, reason}}
      error -> error
    end
  end

  def collect(_source_url, _now), do: {:error, :invalid_source_url}

  defp way_id_from_url(source_url) do
    uri = URI.parse(String.trim(source_url))

    case {uri.scheme, uri.host, uri.path} do
      {scheme, host, path}
      when scheme in ["https", "http"] and host in ["www.openstreetmap.org", "openstreetmap.org"] ->
        case Regex.run(~r{^/way/(\d+)/?$}, path || "") do
          [_, way_id] -> {:ok, way_id}
          _ -> {:error, :invalid_source_url}
        end

      _ ->
        {:error, :invalid_source_url}
    end
  end

  defp attrs_from_response(%{"elements" => elements}, way_id, now) when is_list(elements) do
    case Enum.find(elements, &(&1["type"] == "way" and to_string(&1["id"]) == way_id)) do
      %{"id" => id, "version" => version, "timestamp" => timestamp, "tags" => tags}
      when is_integer(id) and is_integer(version) and is_binary(timestamp) and is_map(tags) ->
        with {:ok, observed_at, _offset} <- DateTime.from_iso8601(timestamp),
             {:ok, road_name} <- road_name(tags),
             {:ok, condition} <- infer_condition(tags) do
          {:ok,
           %{
             import_key: "osm:way:#{id}:v#{version}",
             road_name: road_name,
             condition: condition,
             source_type: "osm",
             source_reference: "https://www.openstreetmap.org/way/#{id}",
             source_details: %{osm_id: id, osm_version: version, tags: tags},
             observed_at: DateTime.truncate(observed_at, :second),
             retrieved_at: now,
             valid_until: nil,
             confidence: "0.65",
             verification_status: "unverified"
           }}
        else
          {:error, _reason} = error -> error
          _ -> {:error, :invalid_osm_timestamp}
        end

      _ ->
        {:error, :invalid_osm_way}
    end
  end

  defp attrs_from_response(_body, _way_id, _now), do: {:error, :invalid_osm_response}

  defp road_name(%{"name" => name}) when is_binary(name) and name != "", do: {:ok, name}
  defp road_name(_tags), do: {:error, :missing_road_name}

  defp infer_condition(tags) do
    cond do
      Map.get(tags, "smoothness") in @smoothness_to_smooth -> {:ok, "smooth"}
      Map.get(tags, "smoothness") in @smoothness_to_rough -> {:ok, "rough"}
      Map.get(tags, "surface") in @unpaved_surfaces -> {:ok, "unpaved"}
      true -> {:error, :unsupported_osm_condition_tags}
    end
  end

  defp client do
    config = Application.get_env(:wazi_route, __MODULE__, [])

    Req.new(
      [
        base_url: Keyword.get(config, :base_url, @default_base_url),
        headers: [{"accept", "application/json"}, {"user-agent", "WaziRoute evidence reviewer"}],
        receive_timeout: 10_000
      ] ++ Keyword.get(config, :req_options, [])
    )
  end
end
