defmodule Wenche.AltinnClient do
  @moduledoc """
  Altinn 3 API client for creating instances, uploading data, and completing submissions.

  Ported from `wenche/altinn_client.py` in the original Python Wenche project.

  All functions accept an `altinn_token` (obtained via `Wenche.Maskinporten`)
  and an `opts` keyword list with:

  - `:env` — `"test"` or `"prod"` (default: `"test"`)
  - `:req_options` — optional extra options passed to `Req` (default: `[]`)
  """

  @altinn_urls %{
    "test" => "https://platform.tt02.altinn.no",
    "prod" => "https://platform.altinn.no"
  }

  @doc """
  Creates a new Altinn 3 app instance for the given org/app.

  - `app_id` — e.g., `"brg/aarsregnskap"` or `"skd/rf-1086"`
  - `org_number` — the 9-digit organization number

  Returns `{:ok, instance_body}` or `{:error, reason}`.
  """
  def create_instance(altinn_token, org_number, app_id, opts \\ []) do
    url = "#{storage_url(opts)}/#{app_id}/instances"

    body = %{
      "instanceOwner" => %{
        "organisationNumber" => org_number
      }
    }

    case Req.post(
           url,
           [{:json, body}, {:headers, auth_headers(altinn_token)} | req_options(opts)]
         ) do
      {:ok, %Req.Response{status: status, body: body}} when status in [200, 201] ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:altinn_create_instance_error, status, body}}

      {:error, reason} ->
        {:error, {:altinn_request_failed, reason}}
    end
  end

  @doc """
  Uploads/updates a data element on an existing instance.

  - `instance_id` — the instance ID (e.g., `"50012345/abc-123-def"`)
  - `data_type` — the data type name (e.g., `"hovedskjema"`)
  - `content_type` — MIME type (e.g., `"application/xml"`)
  - `data` — the binary data to upload

  Returns `{:ok, response_body}` or `{:error, reason}`.
  """
  def update_data_element(altinn_token, instance_id, app_id, data_type, content_type, data, opts \\ []) do
    url = "#{storage_url(opts)}/#{app_id}/instances/#{instance_id}/data?dataType=#{data_type}"

    headers =
      [{"content-type", content_type} | auth_headers(altinn_token)]

    case Req.post(
           url,
           [{:body, data}, {:headers, headers} | req_options(opts)]
         ) do
      {:ok, %Req.Response{status: status, body: body}} when status in [200, 201] ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:altinn_upload_error, status, body}}

      {:error, reason} ->
        {:error, {:altinn_request_failed, reason}}
    end
  end

  @doc """
  Moves the instance to the next process step (complete/confirm).

  Returns `{:ok, response_body}` or `{:error, reason}`.
  """
  def complete_instance(altinn_token, instance_id, app_id, opts \\ []) do
    url = "#{storage_url(opts)}/#{app_id}/instances/#{instance_id}/process/next"

    case Req.put(
           url,
           [{:headers, auth_headers(altinn_token)} | req_options(opts)]
         ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:altinn_complete_error, status, body}}

      {:error, reason} ->
        {:error, {:altinn_request_failed, reason}}
    end
  end

  @doc """
  Gets the current status of an instance.

  Returns `{:ok, response_body}` or `{:error, reason}`.
  """
  def get_status(altinn_token, instance_id, app_id, opts \\ []) do
    url = "#{storage_url(opts)}/#{app_id}/instances/#{instance_id}"

    case Req.get(
           url,
           [{:headers, auth_headers(altinn_token)} | req_options(opts)]
         ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:altinn_status_error, status, body}}

      {:error, reason} ->
        {:error, {:altinn_request_failed, reason}}
    end
  end

  defp storage_url(opts) do
    env = Keyword.get(opts, :env, "test")
    "#{Map.fetch!(@altinn_urls, env)}/storage/api/v1"
  end

  defp req_options(opts), do: Keyword.get(opts, :req_options, [])

  defp auth_headers(token) do
    [
      {"authorization", "Bearer #{token}"},
      {"accept", "application/json"}
    ]
  end
end
