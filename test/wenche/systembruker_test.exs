defmodule Wenche.SystembrukerTest do
  use ExUnit.Case, async: true

  alias Wenche.Systembruker

  @vendor_orgnr "912345678"
  @token "test-token"
  @client_id "test-client-id"
  @org_nummer "987654321"

  @valid_description %{
    "nb" => "Test beskrivelse",
    "nn" => "Test skildring",
    "en" => "Test description"
  }

  describe "system_id/2" do
    test "generates correct system ID format" do
      assert Systembruker.system_id("912345678", "kontira") == "912345678_kontira"
    end

    test "works with any name" do
      assert Systembruker.system_id("912345678", "myapp") == "912345678_myapp"
    end

    test "raises on empty name" do
      assert_raise FunctionClauseError, fn ->
        Systembruker.system_id("912345678", "")
      end
    end

    test "raises on non-string name" do
      assert_raise FunctionClauseError, fn ->
        Systembruker.system_id("912345678", nil)
      end
    end
  end

  describe "registrer_system/4 required options" do
    test "raises ArgumentError when :name is missing" do
      assert_raise ArgumentError, "required option :name is missing", fn ->
        Systembruker.registrer_system(@token, @vendor_orgnr, @client_id,
          description: @valid_description,
          env: "test"
        )
      end
    end

    test "raises ArgumentError when :description is missing" do
      assert_raise ArgumentError, "required option :description is missing", fn ->
        Systembruker.registrer_system(@token, @vendor_orgnr, @client_id,
          name: "kontira",
          env: "test"
        )
      end
    end

    test "raises ArgumentError when :name is nil" do
      assert_raise ArgumentError, "required option :name is missing", fn ->
        Systembruker.registrer_system(@token, @vendor_orgnr, @client_id,
          name: nil,
          description: @valid_description,
          env: "test"
        )
      end
    end
  end

  describe "opprett_forespoersel/4 required options" do
    test "raises ArgumentError when :name is missing" do
      assert_raise ArgumentError, "required option :name is missing", fn ->
        Systembruker.opprett_forespoersel(@token, @vendor_orgnr, @org_nummer, env: "test")
      end
    end

    test "raises ArgumentError when :name is nil" do
      assert_raise ArgumentError, "required option :name is missing", fn ->
        Systembruker.opprett_forespoersel(@token, @vendor_orgnr, @org_nummer,
          name: nil,
          env: "test"
        )
      end
    end
  end

  describe "hent_systembrukere/3 required options" do
    test "raises ArgumentError when :name is missing" do
      assert_raise ArgumentError, "required option :name is missing", fn ->
        Systembruker.hent_systembrukere(@token, @vendor_orgnr, env: "test")
      end
    end

    test "raises ArgumentError when :name is nil" do
      assert_raise ArgumentError, "required option :name is missing", fn ->
        Systembruker.hent_systembrukere(@token, @vendor_orgnr, name: nil, env: "test")
      end
    end
  end

  describe "rights/1 configurable scopes" do
    test "default rights include årsregnskap and aksjonærregister only" do
      default = Systembruker.rights()

      values =
        Enum.flat_map(default, fn %{"resource" => resources} ->
          Enum.map(resources, & &1["value"])
        end)

      assert "app_brg_aarsregnskap-vanlig-202406" in values
      assert "ske-innrapportering-aksjonaerregisteroppgave" in values
      refute "app_skd_formueinntekt-skattemelding-v2" in values
    end

    test "skattemelding feature adds skattemelding scope" do
      with_skatt = Systembruker.rights([:skattemelding])

      values =
        Enum.flat_map(with_skatt, fn %{"resource" => resources} ->
          Enum.map(resources, & &1["value"])
        end)

      assert "app_brg_aarsregnskap-vanlig-202406" in values
      assert "ske-innrapportering-aksjonaerregisteroppgave" in values
      assert "app_skd_formueinntekt-skattemelding-v2" in values
    end

    test "unknown features are ignored" do
      result = Systembruker.rights([:nonexistent_feature])
      assert result == Systembruker.rights()
    end

    test "empty features list returns default rights" do
      assert Systembruker.rights([]) == Systembruker.rights()
    end
  end

  describe "resource_ids/1 configurable scopes" do
    test "default resource_ids exclude skattemelding" do
      ids = Systembruker.resource_ids()
      assert length(ids) == 2
      refute "app_skd_formueinntekt-skattemelding-v2" in ids
    end

    test "resource_ids with skattemelding feature includes all three" do
      ids = Systembruker.resource_ids([:skattemelding])
      assert length(ids) == 3
      assert "app_skd_formueinntekt-skattemelding-v2" in ids
    end
  end

  describe "hent_forespoersel_status/3" do
    test "does not require :name option" do
      # This function only needs a request_id, not a system name.
      # It will fail on the HTTP call, but should not raise ArgumentError.
      result = Systembruker.hent_forespoersel_status(@token, "some-request-id", env: "test")
      assert {:error, _} = result
    end
  end

  describe "req_options support" do
    @req_opts [
      plug: {Req.Test, Wenche.Systembruker},
      retry: false
    ]

    test "registrer_system passes req_options through to Req" do
      Req.Test.stub(Wenche.Systembruker, fn conn ->
        assert conn.method == "POST"

        conn
        |> Plug.Conn.put_status(200)
        |> Req.Test.json(%{"id" => "912345678_kontira"})
      end)

      assert {:ok, body} =
               Systembruker.registrer_system(@token, @vendor_orgnr, @client_id,
                 name: "kontira",
                 description: @valid_description,
                 env: "test",
                 req_options: @req_opts
               )

      assert body["id"] == "912345678_kontira"
    end

    test "opprett_forespoersel passes req_options through to Req" do
      Req.Test.stub(Wenche.Systembruker, fn conn ->
        assert conn.method == "POST"

        conn
        |> Plug.Conn.put_status(200)
        |> Req.Test.json(%{"id" => "request-uuid", "status" => "New"})
      end)

      assert {:ok, body} =
               Systembruker.opprett_forespoersel(@token, @vendor_orgnr, @org_nummer,
                 name: "kontira",
                 env: "test",
                 req_options: @req_opts
               )

      assert body["status"] == "New"
    end

    test "hent_forespoersel_status passes req_options through to Req" do
      Req.Test.stub(Wenche.Systembruker, fn conn ->
        assert conn.method == "GET"
        Req.Test.json(conn, %{"status" => "Accepted"})
      end)

      assert {:ok, body} =
               Systembruker.hent_forespoersel_status(@token, "request-uuid",
                 env: "test",
                 req_options: @req_opts
               )

      assert body["status"] == "Accepted"
    end

    test "hent_systembrukere passes req_options through to Req" do
      Req.Test.stub(Wenche.Systembruker, fn conn ->
        assert conn.method == "GET"
        Req.Test.json(conn, [%{"id" => "user-1"}])
      end)

      assert {:ok, users} =
               Systembruker.hent_systembrukere(@token, @vendor_orgnr,
                 name: "kontira",
                 env: "test",
                 req_options: @req_opts
               )

      assert [%{"id" => "user-1"}] = users
    end
  end
end
