defmodule Wenche.Skattemelding do
  @moduledoc """
  Tax calculation for Norwegian AS (RF-1028 and RF-1167).

  Ported from `wenche/skattemelding.py` in the original Python Wenche project.

  Supports:
  - Standard 22% corporate tax calculation
  - Fritaksmetoden (participation exemption): 97% of subsidiary dividends are tax-exempt
  - Loss carryforward deduction
  - Formatted text report generation

  ## Options

  - `:loss_carryforward` — `Decimal` amount of prior-year losses to deduct (default: `0`)
  - `:apply_exemption_method` — boolean, apply fritaksmetoden on dividend income (default: `false`)
  - `:subsidiary_dividends` — `Decimal` amount of dividends from subsidiaries (default: `0`)
  """

  @doc """
  Calculates tax based on financial data, a tax rate (integer percentage), and options.

  Returns a map with all calculation details:

      %{
        resultat_foer_skatt: Decimal.t(),
        exemption_amount: Decimal.t(),
        taxable_dividend_addition: Decimal.t(),
        taxable_before_loss: Decimal.t(),
        loss_carryforward: Decimal.t(),
        taxable_income: Decimal.t(),
        tax_rate: integer(),
        tax: Decimal.t()
      }
  """
  def calculate_tax(financial_data, tax_rate, opts) do
    loss_carryforward = Keyword.get(opts, :loss_carryforward, Decimal.new(0))
    apply_exemption = Keyword.get(opts, :apply_exemption_method, false)
    subsidiary_dividends = Keyword.get(opts, :subsidiary_dividends, Decimal.new(0))

    r = financial_data.resultatregnskap
    resultat_foer_skatt = r.resultat_foer_skatt

    # Fritaksmetoden: 97% of subsidiary dividends are tax-exempt, 3% taxable
    {exemption_amount, taxable_dividend_addition} =
      if apply_exemption and Decimal.gt?(subsidiary_dividends, Decimal.new(0)) do
        exempt = Decimal.mult(subsidiary_dividends, Decimal.new("0.97"))
        taxable_3pct = Decimal.mult(subsidiary_dividends, Decimal.new("0.03"))
        {exempt, taxable_3pct}
      else
        {Decimal.new(0), Decimal.new(0)}
      end

    # Taxable income before loss carryforward
    taxable_before_loss =
      resultat_foer_skatt
      |> Decimal.add(exemption_amount)
      |> Decimal.add(taxable_dividend_addition)

    # Deduct loss carryforward
    taxable_income =
      if Decimal.gt?(taxable_before_loss, Decimal.new(0)) do
        Decimal.sub(taxable_before_loss, loss_carryforward) |> Decimal.max(Decimal.new(0))
      else
        taxable_before_loss
      end

    # Calculate tax (only on positive taxable income)
    tax =
      if Decimal.gt?(taxable_income, Decimal.new(0)) do
        rate = Decimal.div(Decimal.new(tax_rate), Decimal.new(100))
        Decimal.mult(taxable_income, rate) |> Decimal.round(0)
      else
        Decimal.new(0)
      end

    %{
      resultat_foer_skatt: resultat_foer_skatt,
      exemption_amount: exemption_amount,
      taxable_dividend_addition: taxable_dividend_addition,
      taxable_before_loss: taxable_before_loss,
      loss_carryforward: loss_carryforward,
      taxable_income: taxable_income,
      tax_rate: tax_rate,
      tax: tax
    }
  end

  @doc """
  Formats a tax calculation into a human-readable report string.

  Accepts `year`, a company map (`:name`, `:org_number`), and the result
  from `calculate_tax/3`.
  """
  def format_report(year, company, calc) do
    """
    SKATTEMELDING #{year}
    #{company.name} (#{company.org_number})
    ====================================

    Resultat før skattekostnad:       #{format_nok(calc.resultat_foer_skatt)}
    Fritaksmetoden (97% fritatt):     #{format_nok(calc.exemption_amount)}
    Skattepliktig utbyttetillegg (3%): #{format_nok(calc.taxable_dividend_addition)}
    Skattepliktig inntekt før fremf.: #{format_nok(calc.taxable_before_loss)}
    Fremførbart underskudd:           #{format_nok(calc.loss_carryforward)}
    Skattepliktig inntekt:            #{format_nok(calc.taxable_income)}
    Skattesats:                       #{calc.tax_rate}%
    Beregnet skatt:                   #{format_nok(calc.tax)}
    """
  end

  @doc """
  Formats a Decimal amount as NOK with thousand separators.

  ## Examples

      iex> Wenche.Skattemelding.format_nok(Decimal.new("1234567"))
      "1 234 567 NOK"
  """
  def format_nok(decimal) do
    decimal
    |> Decimal.round(0)
    |> Decimal.to_integer()
    |> Integer.to_string()
    |> add_thousand_separator()
    |> Kernel.<>(" NOK")
  end

  defp add_thousand_separator(str) do
    {sign, digits} =
      case str do
        "-" <> rest -> {"-", rest}
        other -> {"", other}
      end

    formatted =
      digits
      |> String.reverse()
      |> String.to_charlist()
      |> Enum.chunk_every(3)
      |> Enum.join(" ")
      |> String.reverse()

    sign <> formatted
  end
end
