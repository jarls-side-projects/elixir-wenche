defmodule Wenche.BrgXmlTest do
  use ExUnit.Case, async: true

  alias Wenche.BrgXml

  @financial_data %{
    year: 2025,
    resultatregnskap: %{
      driftsinntekter: Decimal.new("500000"),
      driftskostnader: Decimal.new("350000"),
      driftsresultat: Decimal.new("150000"),
      finansinntekter: Decimal.new("10000"),
      finanskostnader: Decimal.new("5000"),
      resultat_foer_skatt: Decimal.new("155000"),
      skattekostnad: Decimal.new("34100"),
      aarsresultat: Decimal.new("120900")
    },
    balanse: %{
      anleggsmidler: Decimal.new("200000"),
      omloepsmidler: Decimal.new("300000"),
      sum_eiendeler: Decimal.new("500000"),
      innskutt_egenkapital: Decimal.new("100000"),
      opptjent_egenkapital: Decimal.new("150000"),
      sum_egenkapital: Decimal.new("250000"),
      langsiktig_gjeld: Decimal.new("100000"),
      kortsiktig_gjeld: Decimal.new("150000"),
      sum_gjeld: Decimal.new("250000")
    }
  }

  @company %{org_number: "912345678", name: "Test AS"}

  describe "generate_hovedskjema/2" do
    test "generates XML with correct structure" do
      {:ok, xml} = BrgXml.generate_hovedskjema(@financial_data, @company)

      assert xml =~ "dataFormatId"
      assert xml =~ "1266"
      assert xml =~ "912345678"
      assert xml =~ "Test AS"
      assert xml =~ "2025"
    end

    test "includes financial amounts" do
      {:ok, xml} = BrgXml.generate_hovedskjema(@financial_data, @company)

      assert xml =~ "500000"
      assert xml =~ "350000"
      assert xml =~ "150000"
    end
  end

  describe "generate_underskjema/2" do
    test "generates XML with correct structure" do
      {:ok, xml} = BrgXml.generate_underskjema(@financial_data, @company)

      assert xml =~ "758"
      assert xml =~ "Regnskapsprinsipper"
      assert xml =~ "2025"
      assert xml =~ "912345678"
    end
  end
end
