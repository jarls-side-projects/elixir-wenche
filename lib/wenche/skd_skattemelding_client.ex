defmodule Wenche.SkdSkattemeldingClient do
  @moduledoc """
  Skatteetaten API client for skattemeldingen (corporate tax return).

  Endpoints:
  - GET /utkast/{year}/{orgNr} — fetch pre-filled draft
  - POST /valider/{year}/{orgNr} — validate tax return XML

  Authentication uses an Altinn token (Maskinporten exchanged).
  """

  @bases %{
    "test" => "https://api-test.sits.no/api/skattemelding/v2",
    "prod" => "https://api.skatteetaten.no/api/skattemelding/v2"
  }

  defstruct [:base, :token]

  @type t :: %__MODULE__{
          base: String.t(),
          token: String.t()
        }

  @doc """
  Creates a new SKD skattemelding client.

  ## Options

  - `:env` — `"test"` or `"prod"` (default: `"prod"`)
  """
  def new(token, opts \\ []) do
    env = Keyword.get(opts, :env, "prod")

    base =
      Map.get(@bases, env) ||
        raise ArgumentError, "invalid env: #{inspect(env)}. Use \"prod\" or \"test\"."

    %__MODULE__{base: base, token: token}
  end

  @doc """
  Fetches the pre-filled tax return draft from Skatteetaten.

  Returns `{:ok, %{xml: xml, dokumentidentifikator: id}}` or `{:error, reason}`.
  """
  def hent_utkast(%__MODULE__{} = client, year, org_nr) do
    url = "#{client.base}/utkast/#{year}/#{org_nr}"

    case Req.get(url, headers: headers(client.token), receive_timeout: 30_000) do
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

    case Req.post(url,
           body: xml,
           headers: [{"content-type", "application/xml"} | headers(client.token)],
           receive_timeout: 30_000
         ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:valider_failed, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp headers(token) do
    [
      {"authorization", "Bearer #{token}"},
      {"accept", "application/json"}
    ]
  end
end
