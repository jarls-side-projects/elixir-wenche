defmodule Wenche.SkdSkattemeldingClientTest do
  use ExUnit.Case, async: true

  alias Wenche.SkdSkattemeldingClient

  describe "new/2" do
    test "creates client with default prod env" do
      client = SkdSkattemeldingClient.new("test-token")

      assert client.token == "test-token"
      assert client.base =~ "api.skatteetaten.no"
    end

    test "creates client with test env" do
      client = SkdSkattemeldingClient.new("test-token", env: "test")

      assert client.base =~ "api-test.sits.no"
    end

    test "raises on invalid env" do
      assert_raise ArgumentError, fn ->
        SkdSkattemeldingClient.new("test-token", env: "invalid")
      end
    end
  end
end
