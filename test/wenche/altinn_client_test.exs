defmodule Wenche.AltinnClientTest do
  use ExUnit.Case, async: true

  alias Wenche.AltinnClient

  @opts [req_options: [plug: {Req.Test, Wenche.AltinnClient}, retry: false], env: "test"]

  setup do
    Req.Test.stub(Wenche.AltinnClient, fn conn ->
      Req.Test.json(conn, %{})
    end)

    :ok
  end

  describe "create_instance/4" do
    test "creates an instance on success" do
      Req.Test.stub(Wenche.AltinnClient, fn conn ->
        assert conn.method == "POST"
        assert String.contains?(conn.request_path, "/instances")

        conn
        |> Plug.Conn.put_status(201)
        |> Req.Test.json(%{
          "id" => "50012345/abc-123-def",
          "status" => %{"isArchived" => false}
        })
      end)

      assert {:ok, body} =
               AltinnClient.create_instance("test-token", "912345678", "brg/aarsregnskap", @opts)

      assert body["id"] == "50012345/abc-123-def"
    end

    test "returns error on failure" do
      Req.Test.stub(Wenche.AltinnClient, fn conn ->
        conn
        |> Plug.Conn.put_status(403)
        |> Req.Test.json(%{"error" => "Forbidden"})
      end)

      assert {:error, {:altinn_create_instance_error, 403, _}} =
               AltinnClient.create_instance("bad-token", "912345678", "brg/aarsregnskap", @opts)
    end
  end

  describe "update_data_element/7" do
    test "uploads data successfully" do
      Req.Test.stub(Wenche.AltinnClient, fn conn ->
        assert conn.method == "POST"
        assert String.contains?(conn.request_path, "/data")

        conn
        |> Plug.Conn.put_status(201)
        |> Req.Test.json(%{"id" => "data-element-id"})
      end)

      assert {:ok, body} =
               AltinnClient.update_data_element(
                 "test-token",
                 "50012345/abc-123-def",
                 "brg/aarsregnskap",
                 "hovedskjema",
                 "application/xml",
                 "<xml>test</xml>",
                 @opts
               )

      assert body["id"] == "data-element-id"
    end
  end

  describe "complete_instance/4" do
    test "completes an instance" do
      Req.Test.stub(Wenche.AltinnClient, fn conn ->
        assert conn.method == "PUT"
        assert String.contains?(conn.request_path, "/process/next")

        Req.Test.json(conn, %{"ended" => "2025-01-15T12:00:00Z"})
      end)

      assert {:ok, body} =
               AltinnClient.complete_instance(
                 "test-token",
                 "50012345/abc-123-def",
                 "brg/aarsregnskap",
                 @opts
               )

      assert body["ended"]
    end

    test "returns error on failure" do
      Req.Test.stub(Wenche.AltinnClient, fn conn ->
        conn
        |> Plug.Conn.put_status(409)
        |> Req.Test.json(%{"error" => "Conflict"})
      end)

      assert {:error, {:altinn_complete_error, 409, _}} =
               AltinnClient.complete_instance(
                 "test-token",
                 "50012345/abc-123-def",
                 "brg/aarsregnskap",
                 @opts
               )
    end
  end

  describe "get_status/4" do
    test "returns instance status" do
      Req.Test.stub(Wenche.AltinnClient, fn conn ->
        assert conn.method == "GET"

        Req.Test.json(conn, %{
          "id" => "50012345/abc-123-def",
          "status" => %{"isArchived" => true}
        })
      end)

      assert {:ok, body} =
               AltinnClient.get_status(
                 "test-token",
                 "50012345/abc-123-def",
                 "brg/aarsregnskap",
                 @opts
               )

      assert body["status"]["isArchived"] == true
    end
  end
end
