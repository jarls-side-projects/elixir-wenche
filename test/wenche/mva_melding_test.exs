defmodule Wenche.MvaMeldingTest do
  use ExUnit.Case, async: true

  alias Wenche.MvaMelding

  defp sample_mva_data do
    %{
      org_nummer: "912345678",
      termin: 1,
      year: 2025,
      system_name: "TestSystem",
      fastsatt_merverdiavgift: 1500,
      linjer: [
        %{mva_kode: 3, grunnlag: 10000, sats: 25, merverdiavgift: 2500},
        %{mva_kode: 1, grunnlag: 4000, sats: 25, merverdiavgift: 1000}
      ]
    }
  end

  describe "valider/2" do
    test "returns ok with validation result on success" do
      Req.Test.stub(Wenche.MvaMelding, fn conn ->
        assert conn.method == "POST"
        assert {"authorization", "Bearer test-token"} in conn.req_headers
        Req.Test.json(conn, %{"status" => "ok", "errors" => []})
      end)

      assert {:ok, %{"status" => "ok"}} =
               MvaMelding.valider(sample_mva_data(),
                 token: "test-token",
                 env: "test",
                 req_options: [plug: {Req.Test, Wenche.MvaMelding}]
               )
    end

    test "returns error on validation failure" do
      Req.Test.stub(Wenche.MvaMelding, fn conn ->
        Plug.Conn.send_resp(conn, 400, Jason.encode!(%{"errors" => ["invalid period"]}))
      end)

      assert {:error, {:valider_failed, 400, _}} =
               MvaMelding.valider(sample_mva_data(),
                 token: "test-token",
                 env: "test",
                 req_options: [plug: {Req.Test, Wenche.MvaMelding}]
               )
    end
  end

  describe "send_inn/3 dry_run" do
    test "writes XML files in dry_run mode" do
      data = sample_mva_data()
      client = Wenche.AltinnClient.new("token", env: "test")

      assert {:ok, {:dry_run, konvolutt_file, melding_file}} =
               MvaMelding.send_inn(data, client, dry_run: true)

      assert File.exists?(konvolutt_file)
      assert File.exists?(melding_file)

      konvolutt = File.read!(konvolutt_file)
      assert konvolutt =~ "mvaMeldingInnsending"
      assert konvolutt =~ "912345678"

      melding = File.read!(melding_file)
      assert melding =~ "mvaMeldingDto"
      assert melding =~ "912345678"

      # Cleanup
      File.rm(konvolutt_file)
      File.rm(melding_file)
    end
  end
end
