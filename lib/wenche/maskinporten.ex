defmodule Wenche.Maskinporten do
  @moduledoc """
  Authentication against Maskinporten via JWT grant (RFC 7523).

  Ported from `wenche/auth.py` in the original Python Wenche project.

  ## Flow

  1. Build a JWT signed with your private RSA key
  2. Exchange it at Maskinporten for an access token
  3. Exchange the Maskinporten token for an Altinn platform token

  ## Configuration

  Pass a keyword list with:

  - `:client_id` — Maskinporten client ID from Digdir
  - `:kid` — Key ID (UUID) from Digdir
  - `:private_key_pem` — PEM-encoded RSA private key (binary)
  - `:env` — `"test"` or `"prod"` (default: `"test"`)
  - `:req_options` — optional extra options passed to `Req` (default: `[]`)
  """

  @maskinporten_urls %{
    "test" => "https://test.maskinporten.no",
    "prod" => "https://maskinporten.no"
  }

  @altinn_urls %{
    "test" => "https://platform.tt02.altinn.no",
    "prod" => "https://platform.altinn.no"
  }

  @doc """
  Obtains an Altinn platform token by:
  1. Building a JWT grant assertion
  2. Exchanging it at Maskinporten for an access token
  3. Exchanging the Maskinporten token for an Altinn platform token

  Returns `{:ok, altinn_token}` or `{:error, reason}`.
  """
  def get_altinn_token(config, scope) do
    with {:ok, jwt} <- build_jwt_grant(config, scope),
         {:ok, maskinporten_token} <- exchange_jwt(config, jwt),
         {:ok, altinn_token} <- exchange_for_altinn_token(config, maskinporten_token) do
      {:ok, altinn_token}
    end
  end

  @doc """
  Builds a JWT grant assertion (RFC 7523) signed with RS256.

  Returns `{:ok, jwt_string}` or `{:error, reason}`.
  """
  def build_jwt_grant(config, scope) do
    env = Keyword.get(config, :env, "test")
    client_id = Keyword.fetch!(config, :client_id)
    kid = Keyword.fetch!(config, :kid)
    private_key_pem = Keyword.fetch!(config, :private_key_pem)
    audience = Map.fetch!(@maskinporten_urls, env)

    now = System.os_time(:second)

    claims = %{
      "aud" => audience,
      "iss" => client_id,
      "scope" => scope,
      "iat" => now,
      "exp" => now + 120,
      "jti" => generate_jti()
    }

    signer = Joken.Signer.create("RS256", %{"pem" => private_key_pem}, %{"kid" => kid})

    case Joken.encode_and_sign(claims, signer) do
      {:ok, jwt, _claims} -> {:ok, jwt}
      {:error, reason} -> {:error, {:jwt_sign_failed, reason}}
    end
  end

  defp exchange_jwt(config, jwt) do
    env = Keyword.get(config, :env, "test")
    req_options = Keyword.get(config, :req_options, [])
    token_url = "#{Map.fetch!(@maskinporten_urls, env)}/token"

    body =
      URI.encode_query(%{
        "grant_type" => "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion" => jwt
      })

    case Req.post(
           token_url,
           [
             {:body, body},
             {:headers, [{"content-type", "application/x-www-form-urlencoded"}]} | req_options
           ]
         ) do
      {:ok, %Req.Response{status: 200, body: %{"access_token" => token}}} ->
        {:ok, token}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:maskinporten_error, status, body}}

      {:error, reason} ->
        {:error, {:maskinporten_request_failed, reason}}
    end
  end

  defp exchange_for_altinn_token(config, maskinporten_token) do
    env = Keyword.get(config, :env, "test")
    req_options = Keyword.get(config, :req_options, [])
    exchange_url = "#{Map.fetch!(@altinn_urls, env)}/authentication/api/v1/exchange/maskinporten"

    case Req.get(
           exchange_url,
           [{:headers, [{"authorization", "Bearer #{maskinporten_token}"}]} | req_options]
         ) do
      {:ok, %Req.Response{status: 200, body: token}} when is_binary(token) ->
        {:ok, token}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:altinn_exchange_error, status, body}}

      {:error, reason} ->
        {:error, {:altinn_exchange_failed, reason}}
    end
  end

  defp generate_jti do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end
end
