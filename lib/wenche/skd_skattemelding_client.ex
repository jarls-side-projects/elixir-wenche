defmodule Wenche.SkdSkattemeldingClient do
  @moduledoc """
  Skatteetaten API client for skattemeldingen (corporate tax return).

  Endpoints:
  - GET /{year}/{orgNr} — fetch pre-filled draft (contains `partsnummer`)
  - GET /utkast/{year}/{orgNr} — legacy alias for the pre-filled draft
  - POST /valider/{year}/{orgNr} — validate tax return XML

  Authentication uses a raw Maskinporten token (no Altinn exchange) with
  the `skatteetaten:formueinntekt/skattemelding` scope and systemuser
  authorization for the target organisation. See
  `Wenche.Maskinporten.get_skd_skattemelding_token/2`.
  """

  alias Wenche.SkattemeldingXml

  @forespoersel_response_ns "no:skatteetaten:fastsetting:formueinntekt:skattemeldingognaeringsspesifikasjon:forespoersel:response:v2"

  @bases %{
    "test" => "https://api-test.sits.no/api/skattemelding/v2",
    "prod" => "https://api.skatteetaten.no/api/skattemelding/v2"
  }

  defstruct [:base, :token, req_options: []]

  @type t :: %__MODULE__{
          base: String.t(),
          token: String.t(),
          req_options: keyword()
        }

  @doc """
  Creates a new SKD skattemelding client.

  ## Options

  - `:env` — `"test"` or `"prod"` (default: `"prod"`)
  - `:req_options` — extra options passed to `Req` (default: `[]`)
  """
  def new(token, opts \\ []) do
    env = Keyword.get(opts, :env, "prod")
    req_options = Keyword.get(opts, :req_options, [])

    base =
      Map.get(@bases, env) ||
        raise ArgumentError, "invalid env: #{inspect(env)}. Use \"prod\" or \"test\"."

    %__MODULE__{base: base, token: token, req_options: req_options}
  end

  @doc """
  Fetches the pre-filled tax return draft from Skatteetaten.

  Returns `{:ok, %{xml: xml, dokumentidentifikator: id}}` or `{:error, reason}`.
  """
  def hent_utkast(%__MODULE__{} = client, year, org_nr) do
    url = "#{client.base}/utkast/#{year}/#{org_nr}"

    case Req.get(
           url,
           Keyword.merge(
             [headers: headers(client.token), receive_timeout: 30_000],
             client.req_options
           )
         ) do
      {:ok, %Req.Response{status: 200, body: body}} when is_map(body) ->
        {:ok, body}

      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
        {:ok, %{"content" => body}}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:utkast_failed, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Validates a tax return XML against Skatteetaten's validation service.

  The `xml` should be the full `skattemeldingOgNaeringsspesifikasjonRequest` envelope.

  Returns `{:ok, validation_result}` or `{:error, reason}`.
  """
  def valider(%__MODULE__{} = client, year, org_nr, xml) do
    url = "#{client.base}/valider/#{year}/#{org_nr}"

    valider_headers = [
      {"authorization", "Bearer #{client.token}"},
      {"content-type", "application/xml;charset=UTF-8"},
      {"accept", "application/xml;charset=UTF-8"}
    ]

    case Req.post(
           url,
           Keyword.merge(
             [body: xml, headers: valider_headers, receive_timeout: 30_000],
             client.req_options
           )
         ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:valider_failed, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Fetches the pre-filled skattemelding XML from Skatteetaten.

  Calls `GET /{year}/{orgNr}` with `Accept: application/xml`. If the response is
  wrapped in a `forespoerselResponse` envelope with base64-encoded `<content>`,
  the wrapper is unpacked and the inner XML returned.

  Returns `{:ok, inner_xml :: binary}` or `{:error, reason}`.
  """
  def hent_forhandsutfylt(%__MODULE__{} = client, year, org_nr) do
    url = "#{client.base}/#{year}/#{org_nr}"

    request_headers = [
      {"authorization", "Bearer #{client.token}"},
      {"accept", "application/xml"}
    ]

    case Req.get(
           url,
           Keyword.merge(
             [headers: request_headers, receive_timeout: 30_000],
             client.req_options
           )
         ) do
      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
        {:ok, maybe_unwrap_forespoersel(body)}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:utkast_failed, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Fetches and extracts the company's `partsnummer` from Skatteetaten.

  Convenience wrapper around `hent_forhandsutfylt/3` + `SkattemeldingXml.hent_partsnummer/1`.

  Returns `{:ok, integer}` or `{:error, reason}`.
  """
  def hent_partsnummer(%__MODULE__{} = client, year, org_nr) do
    with {:ok, xml} <- hent_forhandsutfylt(client, year, org_nr) do
      SkattemeldingXml.hent_partsnummer(xml)
    end
  end

  defp maybe_unwrap_forespoersel(xml) do
    case Regex.run(~r{<(?:\w+:)?content[^>]*>\s*([A-Za-z0-9+/=\s]+)\s*</(?:\w+:)?content>}, xml) do
      [_, b64] when is_binary(b64) ->
        if String.contains?(xml, @forespoersel_response_ns) do
          decode_b64(b64) || xml
        else
          xml
        end

      _ ->
        xml
    end
  end

  defp decode_b64(b64) do
    case Base.decode64(String.replace(b64, ~r/\s+/, ""), ignore: :whitespace) do
      {:ok, decoded} -> decoded
      :error -> nil
    end
  end

  defp headers(token) do
    [
      {"authorization", "Bearer #{token}"},
      {"accept", "application/json"}
    ]
  end
end
