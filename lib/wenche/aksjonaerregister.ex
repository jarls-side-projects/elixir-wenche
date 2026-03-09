defmodule Wenche.Aksjonaerregister do
  @moduledoc """
  RF-1086 (Aksjonærregisteroppgave) XML generation.

  Ported from `wenche/aksjonaerregister.py` in the original Python Wenche project.

  The shareholder register report is filed annually by January 31st to the
  Norwegian Tax Authority via Altinn.

  ## Shareholder data format

  Each shareholder is a map with:

      %{
        fodselsnummer: String.t(),    # 11-digit Norwegian national ID
        name: String.t(),
        antall_aksjer: integer(),
        aksjeklasse: String.t(),       # e.g., "A"
        utbytte_utbetalt: Decimal.t(), # dividends paid
        innbetalt_kapital_per_aksje: Decimal.t()
      }
  """

  @doc """
  Generates RF-1086 XML from company data and a list of shareholders.

  - `year` — the fiscal year
  - `company` — map with `:org_number` and `:name`
  - `shareholders` — list of shareholder maps

  Returns an XML string.
  """
  def generate_xml(year, company, shareholders) do
    total_shares = Enum.reduce(shareholders, 0, fn s, acc -> acc + s.antall_aksjer end)

    total_utbytte =
      Enum.reduce(shareholders, Decimal.new(0), fn s, acc ->
        Decimal.add(acc, s.utbytte_utbetalt || Decimal.new(0))
      end)

    XmlBuilder.document(
      :Aksjonaerregisteroppgave,
      %{xmlns: "urn:ske:fastsetting:formueinntekt:aksjonaerregisteroppgave:v2"},
      [
        el(:Inntektsaar, Integer.to_string(year)),
        XmlBuilder.element(:Selskap, [
          el(:Organisasjonsnummer, company.org_number),
          el(:Selskapsnavn, company.name),
          el(:AntallAksjer, Integer.to_string(total_shares)),
          el(:SumUtbytteutdeling, to_nok(total_utbytte))
        ]),
        XmlBuilder.element(
          :Aksjonaerliste,
          Enum.map(shareholders, fn s ->
            XmlBuilder.element(:Aksjonaer, [
              el(:Fodselsnummer, s.fodselsnummer),
              el(:Navn, s.name),
              el(:AntallAksjer, Integer.to_string(s.antall_aksjer)),
              el(:Aksjeklasse, s.aksjeklasse || "A"),
              el(:Utbytte, to_nok(s.utbytte_utbetalt || Decimal.new(0))),
              el(
                :InnbetaltKapitalPerAksje,
                to_nok(s.innbetalt_kapital_per_aksje || Decimal.new(0))
              )
            ])
          end)
        )
      ]
      |> Enum.reject(&is_nil/1)
    )
    |> XmlBuilder.generate(format: :indent)
  end

  @doc """
  Validates a list of shareholders.

  Returns `:ok` or `{:error, reason}`.
  """
  def validate_shareholders([]), do: {:error, :no_shareholders}

  def validate_shareholders(shareholders) do
    total_shares = Enum.reduce(shareholders, 0, fn s, acc -> acc + s.antall_aksjer end)

    cond do
      total_shares <= 0 ->
        {:error, :invalid_total_shares}

      Enum.any?(shareholders, fn s -> not Regex.match?(~r/^\d{11}$/, s.fodselsnummer) end) ->
        {:error, :invalid_fodselsnummer}

      true ->
        :ok
    end
  end

  defp to_nok(decimal) do
    decimal
    |> Decimal.round(0)
    |> Decimal.to_integer()
    |> Integer.to_string()
  end

  defp el(name, content), do: XmlBuilder.element(name, content)
end
