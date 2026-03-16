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

  describe "hent_forespoersel_status/3" do
    test "does not require :name option" do
      # This function only needs a request_id, not a system name.
      # It will fail on the HTTP call, but should not raise ArgumentError.
      result = Systembruker.hent_forespoersel_status(@token, "some-request-id", env: "test")
      assert {:error, _} = result
    end
  end
end
