defmodule Wenche.Systembruker do
  @moduledoc """
  System user flow for Altinn 3.

  Ported from `wenche/systembruker.py` in the original Python Wenche project.

  Altinn 3 requires that end-user systems register themselves in the system register
  and create a system user for each organization they will act on behalf of.

  ## Setup (run once)

  1. `registrer_system/3` — registers Wenche in Altinn's system register
  2. `opprett_forespoersel/3` — sends request to org for approval
  3. User approves via confirmUrl in browser

  For submission, use `Wenche.Maskinporten.get_systemuser_token/2` to get a token.
  """

  @bases %{
    "test" => "https://platform.tt02.altinn.no",
    "prod" => "https://platform.altinn.no"
  }

  @system_navn "wenche"

  # Resource IDs for Altinn 3 apps
  @rights [
    %{
      "resource" => [
        %{"id" => "urn:altinn:resource", "value" => "app_brg_aarsregnskap-vanlig-202406"}
      ]
    }
  ]

  @doc """
  Returns the system ID in the format `<org_nummer>_wenche`.
  """
  def system_id(vendor_orgnr), do: "#{vendor_orgnr}_#{@system_navn}"

  @doc """
  Registers or updates Wenche in Altinn's system register.

  Tries POST first. If the system already exists, uses PUT to update.

  Returns `{:ok, response_map}` or `{:error, reason}`.
  """
  def registrer_system(maskinporten_token, vendor_orgnr, client_id, opts \\ []) do
    env = Keyword.get(opts, :env, "prod")
    base = Map.fetch!(@bases, env)
    sid = system_id(vendor_orgnr)
    payload = bygg_system_payload(vendor_orgnr, client_id)

    headers = [
      {"Authorization", "Bearer #{maskinporten_token}"},
      {"Content-Type", "application/json"}
    ]

    url = "#{base}/authentication/api/v1/systemregister/vendor"

    case Req.post(url, json: payload, headers: headers, receive_timeout: 15_000) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: 400, body: body}} when is_binary(body) ->
        if String.contains?(body, "already exists") do
          update_url = "#{url}/#{sid}"

          case Req.put(update_url, json: payload, headers: headers, receive_timeout: 15_000) do
            {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
              if is_map(body) and map_size(body) > 0 do
                {:ok, body}
              else
                {:ok, %{"id" => sid, "oppdatert" => true}}
              end

            {:ok, %Req.Response{status: status, body: body}} ->
              {:error, {:system_update_failed, status, body}}

            {:error, reason} ->
              {:error, {:request_failed, reason}}
          end
        else
          {:error, {:system_register_failed, 400, body}}
        end

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:system_register_failed, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Creates a system user request for the organization.

  Returns `{:ok, %{id: uuid, status: "New", confirmUrl: url}}` or `{:error, reason}`.

  The user must go to confirmUrl and approve in the browser.
  """
  def opprett_forespoersel(maskinporten_token, vendor_orgnr, org_nummer, opts \\ []) do
    env = Keyword.get(opts, :env, "prod")
    base = Map.fetch!(@bases, env)
    sid = system_id(vendor_orgnr)

    payload = %{
      "systemId" => sid,
      "partyOrgNo" => org_nummer,
      "integrationTitle" => "Wenche",
      "rights" => @rights
    }

    headers = [
      {"Authorization", "Bearer #{maskinporten_token}"},
      {"Content-Type", "application/json"}
    ]

    url = "#{base}/authentication/api/v1/systemuser/request/vendor"

    case Req.post(url, json: payload, headers: headers, receive_timeout: 15_000) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:request_create_failed, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Gets the status of a system user request.

  Returns `{:ok, response_map}` or `{:error, reason}`.
  """
  def hent_forespoersel_status(maskinporten_token, request_id, opts \\ []) do
    env = Keyword.get(opts, :env, "prod")
    base = Map.fetch!(@bases, env)

    headers = [{"Authorization", "Bearer #{maskinporten_token}"}]
    url = "#{base}/authentication/api/v1/systemuser/request/vendor/#{request_id}"

    case Req.get(url, headers: headers, receive_timeout: 15_000) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:status_fetch_failed, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Gets all approved system users for the Wenche system.

  Returns `{:ok, [system_user_map]}` or `{:error, reason}`.
  """
  def hent_systembrukere(maskinporten_token, vendor_orgnr, opts \\ []) do
    env = Keyword.get(opts, :env, "prod")
    base = Map.fetch!(@bases, env)
    sid = system_id(vendor_orgnr)

    headers = [{"Authorization", "Bearer #{maskinporten_token}"}]
    url = "#{base}/authentication/api/v1/systemuser/vendor/bysystem/#{sid}"

    case Req.get(url, headers: headers, receive_timeout: 15_000) do
      {:ok, %Req.Response{status: 200, body: body}} when is_list(body) ->
        {:ok, body}

      {:ok, %Req.Response{status: 200, body: %{"data" => data}}} when is_list(data) ->
        {:ok, data}

      {:ok, %Req.Response{status: 200, body: body}} when is_map(body) ->
        {:ok, Map.get(body, "data", [body])}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:users_fetch_failed, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp bygg_system_payload(vendor_orgnr, client_id) do
    sid = system_id(vendor_orgnr)

    %{
      "id" => sid,
      "vendor" => %{
        "authority" => "iso6523-actorid-upis",
        "ID" => "0192:#{vendor_orgnr}"
      },
      "name" => %{
        "nb" => "Wenche",
        "nn" => "Wenche",
        "en" => "Wenche"
      },
      "description" => %{
        "nb" =>
          "Enkel innsending av årsregnskap til Brønnøysundregistrene for holdingselskap.",
        "nn" =>
          "Enkel innsending av årsrekneskap til Brønnøysundregistra for holdingselskap.",
        "en" =>
          "Simple annual accounts submission to the Register of Business Enterprises."
      },
      "clientId" => [client_id],
      "isVisible" => true,
      "rights" => @rights
    }
  end
end
