defmodule Wenche.IxbrlTest do
  use ExUnit.Case, async: true

  alias Wenche.Ixbrl

  @financial_data %{
    year: 2025,
    resultatregnskap: %{
      driftsinntekter: Decimal.new("500000"),
      driftskostnader: Decimal.new("350000"),
      driftsresultat: Decimal.new("150000"),
      finansinntekter: Decimal.new("10000"),
      finanskostnader: Decimal.new("5000"),
      netto_finans: Decimal.new("5000"),
      ekstraordinaere: Decimal.new("0"),
      skattekostnad: Decimal.new("34100"),
      resultat_foer_skatt: Decimal.new("155000"),
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

  @company %{
    org_number: "912345678",
    name: "Test AS"
  }

  describe "generate/2" do
    test "generates valid HTML document" do
      {:ok, html} = Ixbrl.generate(@financial_data, @company)

      assert html =~ "<!DOCTYPE html>"
      assert html =~ "<html"
      assert html =~ "</html>"
    end

    test "includes XBRL namespaces" do
      {:ok, html} = Ixbrl.generate(@financial_data, @company)

      assert html =~ "xmlns:ix="
      assert html =~ "xmlns:xbrli="
      assert html =~ "xmlns:iso4217="
      assert html =~ "xmlns:nrs="
    end

    test "includes context c1 (instant/balance date)" do
      {:ok, html} = Ixbrl.generate(@financial_data, @company)

      assert html =~ ~s(id="c1")
      assert html =~ "<xbrli:instant>2025-12-31</xbrli:instant>"
    end

    test "includes context c2 (period/fiscal year)" do
      {:ok, html} = Ixbrl.generate(@financial_data, @company)

      assert html =~ ~s(id="c2")
      assert html =~ "<xbrli:startDate>2025-01-01</xbrli:startDate>"
      assert html =~ "<xbrli:endDate>2025-12-31</xbrli:endDate>"
    end

    test "includes NOK unit definition" do
      {:ok, html} = Ixbrl.generate(@financial_data, @company)

      assert html =~ ~s(id="NOK")
      assert html =~ "iso4217:NOK"
    end

    test "includes ix:nonFraction tags with correct values" do
      {:ok, html} = Ixbrl.generate(@financial_data, @company)

      assert html =~ ~s(name="nrs:Driftsinntekter" contextRef="c2")
      assert html =~ ~s(name="nrs:Driftskostnader" contextRef="c2")
      assert html =~ ~s(name="nrs:Aarsresultat" contextRef="c2")
      assert html =~ ~s(name="nrs:SumEiendeler" contextRef="c1")
      assert html =~ ~s(name="nrs:SumEgenkapital" contextRef="c1")
      assert html =~ ~s(name="nrs:SumGjeld" contextRef="c1")
    end

    test "contains company information" do
      {:ok, html} = Ixbrl.generate(@financial_data, @company)

      assert html =~ "Test AS"
      assert html =~ "912345678"
      assert html =~ "2025"
    end

    test "escapes HTML in company name" do
      company = %{@company | name: "Test & <Company>"}
      {:ok, html} = Ixbrl.generate(@financial_data, company)

      assert html =~ "Test &amp; &lt;Company&gt;"
      refute html =~ "Test & <Company>"
    end
  end
end
