defmodule Wenche.SkattemeldingTest do
  use ExUnit.Case, async: true

  alias Wenche.Skattemelding

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
      skattekostnad: Decimal.new("0"),
      resultat_foer_skatt: Decimal.new("155000"),
      aarsresultat: Decimal.new("155000")
    },
    balanse: %{
      sum_eiendeler: Decimal.new("500000"),
      sum_egenkapital: Decimal.new("250000"),
      sum_gjeld: Decimal.new("250000")
    }
  }

  describe "calculate_tax/3" do
    test "calculates 22% tax on positive income" do
      calc = Skattemelding.calculate_tax(@financial_data, 22, [])

      assert Decimal.equal?(calc.taxable_income, Decimal.new("155000"))
      assert Decimal.equal?(calc.tax, Decimal.new("34100"))
      assert calc.tax_rate == 22
    end

    test "applies loss carryforward" do
      calc =
        Skattemelding.calculate_tax(@financial_data, 22,
          loss_carryforward: Decimal.new("55000")
        )

      assert Decimal.equal?(calc.taxable_income, Decimal.new("100000"))
      assert Decimal.equal?(calc.tax, Decimal.new("22000"))
    end

    test "loss carryforward does not make taxable income negative" do
      calc =
        Skattemelding.calculate_tax(@financial_data, 22,
          loss_carryforward: Decimal.new("200000")
        )

      assert Decimal.equal?(calc.taxable_income, Decimal.new("0"))
      assert Decimal.equal?(calc.tax, Decimal.new("0"))
    end

    test "applies fritaksmetoden on subsidiary dividends" do
      calc =
        Skattemelding.calculate_tax(@financial_data, 22,
          apply_exemption_method: true,
          subsidiary_dividends: Decimal.new("100000")
        )

      assert Decimal.equal?(calc.exemption_amount, Decimal.new("97000"))
      assert Decimal.equal?(calc.taxable_dividend_addition, Decimal.new("3000"))
      assert Decimal.equal?(calc.taxable_before_loss, Decimal.new("255000"))
      assert Decimal.equal?(calc.tax, Decimal.new("56100"))
    end

    test "no tax on negative income" do
      negative_data = %{
        @financial_data
        | resultatregnskap: %{
            @financial_data.resultatregnskap
            | resultat_foer_skatt: Decimal.new("-50000")
          }
      }

      calc = Skattemelding.calculate_tax(negative_data, 22, [])

      assert Decimal.equal?(calc.tax, Decimal.new("0"))
    end

    test "uses custom tax rate" do
      calc = Skattemelding.calculate_tax(@financial_data, 25, [])

      assert Decimal.equal?(calc.tax, Decimal.new("38750"))
    end
  end

  describe "format_report/3" do
    test "generates a readable report" do
      calc = Skattemelding.calculate_tax(@financial_data, 22, [])
      company = %{name: "Test AS", org_number: "912345678"}

      report = Skattemelding.format_report(2025, company, calc)

      assert report =~ "SKATTEMELDING 2025"
      assert report =~ "Test AS"
      assert report =~ "912345678"
      assert report =~ "22%"
    end
  end

  describe "format_nok/1" do
    test "formats positive numbers with thousand separators" do
      assert Skattemelding.format_nok(Decimal.new("1234567")) == "1 234 567 NOK"
    end

    test "formats negative numbers" do
      assert Skattemelding.format_nok(Decimal.new("-50000")) == "-50 000 NOK"
    end

    test "formats zero" do
      assert Skattemelding.format_nok(Decimal.new("0")) == "0 NOK"
    end
  end
end
