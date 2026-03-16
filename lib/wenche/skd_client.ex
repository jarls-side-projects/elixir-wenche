defmodule Wenche.SkdClient do
  @moduledoc """
  SKD API client for aksjonærregisteroppgave (RF-1086).

  Skatteetaten has its own REST API for reporting — independent of Altinn instance flow.
  Authentication uses a Maskinporten token directly (not exchanged for Altinn token).

  Submission flow:
    1. POST /{year}/1086H        — send Hovedskjema, get back hovedskjemaid
    2. POST /{year}/{id}/1086U   — send Underskjema for each shareholder
    3. POST /{year}/{id}/bekreft — confirm all sub-forms submitted
  """

  @bases %{
    "test" => "https://api-test.sits.no/api/aksjonaerregister/v1",
    "prod" => "https://api.sits.no/api/aksjonaerregister/v1"
  }

  @doc """
  Creates a new SKD client config.

  Returns a map with base URL and token for use in other functions.
  """
  def new(maskinporten_token, opts \\ []) do
    env = Keyword.get(opts, :env, "prod")

    base =
      Map.get(@bases, env) ||
        raise ArgumentError, "invalid env: #{inspect(env)}. Use \"prod\" or \"test\"."

    %{base: base, token: maskinporten_token}
  end

  @doc """
  Sends Hovedskjema (RF-1086) to SKD.

  Returns `{:ok, hovedskjemaid}` or `{:error, reason}`.
  """
  def send_hovedskjema(%{base: base, token: token}, regnskapsaar, xml) do
    url = "#{base}/#{regnskapsaar}/1086H"

    case Req.post(url, body: xml, headers: headers(token), receive_timeout: 30_000) do
      {:ok, %Req.Response{status: status, body: %{"hovedskjemaid" => id}}}
      when status in 200..299 ->
        {:ok, id}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:hovedskjema_failed, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Sends Underskjema (RF-1086-U) for one shareholder.

  Returns `:ok` or `{:error, reason}`.
  """
  def send_underskjema(%{base: base, token: token}, regnskapsaar, hovedskjemaid, xml) do
    url = "#{base}/#{regnskapsaar}/#{hovedskjemaid}/1086U"

    case Req.post(url, body: xml, headers: headers(token), receive_timeout: 30_000) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:underskjema_failed, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Confirms that all sub-forms have been submitted.

  Returns `{:ok, response_map}` with forsendelse-ID and dialog-ID, or `{:error, reason}`.
  """
  def bekreft(%{base: base, token: token}, regnskapsaar, hovedskjemaid, antall_underskjema) do
    url =
      "#{base}/#{regnskapsaar}/#{hovedskjemaid}/bekreft?antall_underskjema=#{antall_underskjema}"

    case Req.post(url, body: "", headers: headers(token), receive_timeout: 30_000) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:bekreft_failed, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp headers(token) do
    [
      {"authorization", "Bearer #{token}"},
      {"content-type", "application/xml"},
      {"accept", "application/json"},
      {"idempotencyKey", UUID.uuid4()}
    ]
  end
end
