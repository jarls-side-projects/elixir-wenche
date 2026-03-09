defmodule Wenche.BrgXml do
  @moduledoc """
  Generates BRG XML documents for annual statement submission to Bronnøysundregistrene.

  Ported from `wenche/brg_xml.py` in the original Python Wenche project.

  Two separate XML documents are required:
  - **Hovedskjema** (dataFormatId=1266): company info, fiscal year, financial summary
  - **Underskjema** (dataFormatId=758): supplementary notes/principles

  ## Financial data format

  Both functions accept a map with these keys:

      %{
        year: integer(),
        resultatregnskap: %{
          driftsinntekter: Decimal.t(),
          driftskostnader: Decimal.t(),
          driftsresultat: Decimal.t(),
          finansinntekter: Decimal.t(),
          finanskostnader: Decimal.t(),
          resultat_foer_skatt: Decimal.t(),
          skattekostnad: Decimal.t(),
          aarsresultat: Decimal.t()
        },
        balanse: %{
          anleggsmidler: Decimal.t(),
          omloepsmidler: Decimal.t(),
          sum_eiendeler: Decimal.t(),
          innskutt_egenkapital: Decimal.t(),
          opptjent_egenkapital: Decimal.t(),
          sum_egenkapital: Decimal.t(),
          langsiktig_gjeld: Decimal.t(),
          kortsiktig_gjeld: Decimal.t(),
          sum_gjeld: Decimal.t()
        }
      }

  And a company map with `:org_number` and `:name`.
  """

  @doc """
  Generates Hovedskjema XML (dataFormatId=1266) for BRG annual statement.

  Returns `{:ok, xml_string}`.
  """
  def generate_hovedskjema(financial_data, company) do
    r = financial_data.resultatregnskap
    b = financial_data.balanse
    year = financial_data.year

    xml =
      XmlBuilder.document(
        :Skjema,
        %{
          "xmlns" => "http://www.brreg.no/or/regnskapsregisteret/1266",
          "dataFormatProvider" => "OR",
          "dataFormatId" => "1266",
          "dataFormatVersion" => "11878"
        },
        [
          el(:Regnskapsaar, Integer.to_string(year)),
          el(:Organisasjonsnummer, company.org_number),
          el(:Foretaksnavn, company.name),
          el(:SumDriftsinntekter, to_nok(r.driftsinntekter)),
          orid(72, to_nok(r.driftsinntekter)),
          el(:SumDriftskostnader, to_nok(r.driftskostnader)),
          orid(75, to_nok(r.driftskostnader)),
          el(:Driftsresultat, to_nok(r.driftsresultat)),
          orid(79, to_nok(r.driftsresultat)),
          el(:SumFinansinntekter, to_nok(r.finansinntekter)),
          el(:SumFinanskostnader, to_nok(r.finanskostnader)),
          el(:ResultatFoerSkattekostnad, to_nok(r.resultat_foer_skatt)),
          orid(146, to_nok(r.resultat_foer_skatt)),
          el(:Skattekostnad, to_nok(r.skattekostnad)),
          el(:Aarsresultat, to_nok(r.aarsresultat)),
          orid(167, to_nok(r.aarsresultat)),
          el(:SumAnleggsmidler, to_nok(b.anleggsmidler)),
          orid(217, to_nok(b.anleggsmidler)),
          el(:SumOmloepsmidler, to_nok(b.omloepsmidler)),
          orid(194, to_nok(b.omloepsmidler)),
          el(:SumEiendeler, to_nok(b.sum_eiendeler)),
          orid(234, to_nok(b.sum_eiendeler)),
          el(:SumInnskuttEgenkapital, to_nok(b.innskutt_egenkapital)),
          orid(251, to_nok(b.innskutt_egenkapital)),
          el(:SumOpptjentEgenkapital, to_nok(b.opptjent_egenkapital)),
          orid(263, to_nok(b.opptjent_egenkapital)),
          el(:SumEgenkapital, to_nok(b.sum_egenkapital)),
          orid(272, to_nok(b.sum_egenkapital)),
          el(:SumLangsiktigGjeld, to_nok(b.langsiktig_gjeld)),
          orid(289, to_nok(b.langsiktig_gjeld)),
          el(:SumKortsiktigGjeld, to_nok(b.kortsiktig_gjeld)),
          orid(322, to_nok(b.kortsiktig_gjeld)),
          el(:SumGjeld, to_nok(b.sum_gjeld)),
          orid(329, to_nok(b.sum_gjeld)),
          el(:SumEgenkapitalOgGjeld, to_nok(Decimal.add(b.sum_egenkapital, b.sum_gjeld))),
          orid(330, to_nok(Decimal.add(b.sum_egenkapital, b.sum_gjeld)))
        ]
        |> Enum.reject(&is_nil/1)
      )
      |> XmlBuilder.generate(format: :indent)

    {:ok, xml}
  end

  @doc """
  Generates Underskjema XML (dataFormatId=758) — the notes/supplementary data.

  Returns `{:ok, xml_string}`.
  """
  def generate_underskjema(financial_data, company) do
    year = financial_data.year

    xml =
      XmlBuilder.document(
        :Skjema,
        %{
          "xmlns" => "http://www.brreg.no/or/regnskapsregisteret/758",
          "dataFormatProvider" => "OR",
          "dataFormatId" => "758",
          "dataFormatVersion" => "11544"
        },
        [
          el(:Regnskapsaar, Integer.to_string(year)),
          el(:Organisasjonsnummer, company.org_number),
          el(:Foretaksnavn, company.name),
          el(
            :Regnskapsprinsipper,
            "Regnskapet er utarbeidet i samsvar med regnskapsloven og god regnskapsskikk for små foretak."
          )
        ]
        |> Enum.reject(&is_nil/1)
      )
      |> XmlBuilder.generate(format: :indent)

    {:ok, xml}
  end

  defp orid(code, value) do
    XmlBuilder.element(:Post, %{orid: Integer.to_string(code)}, value)
  end

  defp to_nok(decimal) do
    decimal
    |> Decimal.round(0)
    |> Decimal.to_integer()
    |> Integer.to_string()
  end

  defp el(name, content), do: XmlBuilder.element(name, content)
end
