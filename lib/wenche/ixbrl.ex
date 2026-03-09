defmodule Wenche.Ixbrl do
  @moduledoc """
  Generates inline XBRL (iXBRL) HTML documents for annual statements.

  Ported from `wenche/xbrl.py` in the original Python Wenche project.

  iXBRL is the format required by Bronnøysundregistrene. It is an HTML document
  with embedded XBRL tags that make the numbers machine-readable while remaining
  viewable in a browser.

  Taxonomy: Norwegian GAAP (NRS) simplified for small enterprises.

  ## Financial data format

  Accepts the same financial data map as `Wenche.BrgXml` and a company map
  with `:org_number` and `:name`.
  """

  @nrs_ns "http://xbrl.difi.no/nrs/taxonomy/2023-01-01"
  @xbrli_ns "http://www.xbrl.org/2003/instance"
  @ix_ns "http://www.xbrl.org/2013/inlineXBRL"
  @iso4217_ns "http://www.xbrl.org/2003/iso4217"

  @doc """
  Generates an iXBRL HTML document from financial data.

  Returns `{:ok, html_string}`.
  """
  def generate(financial_data, company) do
    year = financial_data.year
    r = financial_data.resultatregnskap
    b = financial_data.balanse

    period_start = "#{year}-01-01"
    period_end = "#{year}-12-31"

    html = """
    <!DOCTYPE html>
    <html xmlns="http://www.w3.org/1999/xhtml"
          xmlns:ix="#{@ix_ns}"
          xmlns:xbrli="#{@xbrli_ns}"
          xmlns:iso4217="#{@iso4217_ns}"
          xmlns:nrs="#{@nrs_ns}">
    <head>
      <meta charset="UTF-8" />
      <title>Årsregnskap #{year} — #{escape_html(company.name)}</title>
      <style>
        body { font-family: sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        h1, h2 { color: #333; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
        th, td { border: 1px solid #ccc; padding: 8px; text-align: right; }
        th { background-color: #f5f5f5; text-align: left; }
        .total { font-weight: bold; border-top: 2px solid #333; }
      </style>
    </head>
    <body>
      <ix:header>
        <ix:hidden>
          <xbrli:context id="c1">
            <xbrli:entity>
              <xbrli:identifier scheme="http://www.brreg.no">#{escape_html(company.org_number)}</xbrli:identifier>
            </xbrli:entity>
            <xbrli:period>
              <xbrli:instant>#{period_end}</xbrli:instant>
            </xbrli:period>
          </xbrli:context>
          <xbrli:context id="c2">
            <xbrli:entity>
              <xbrli:identifier scheme="http://www.brreg.no">#{escape_html(company.org_number)}</xbrli:identifier>
            </xbrli:entity>
            <xbrli:period>
              <xbrli:startDate>#{period_start}</xbrli:startDate>
              <xbrli:endDate>#{period_end}</xbrli:endDate>
            </xbrli:period>
          </xbrli:context>
          <xbrli:unit id="NOK">
            <xbrli:measure>iso4217:NOK</xbrli:measure>
          </xbrli:unit>
        </ix:hidden>
      </ix:header>

      <h1>Årsregnskap #{year}</h1>
      <p>#{escape_html(company.name)} (#{escape_html(company.org_number)})</p>

      <h2>Resultatregnskap</h2>
      <table>
        <tr><th>Post</th><th>Beløp (NOK)</th></tr>
        <tr><td>Driftsinntekter</td><td>#{non_fraction("nrs:Driftsinntekter", "c2", r.driftsinntekter)}</td></tr>
        <tr><td>Driftskostnader</td><td>#{non_fraction("nrs:Driftskostnader", "c2", r.driftskostnader)}</td></tr>
        <tr class="total"><td>Driftsresultat</td><td>#{non_fraction("nrs:Driftsresultat", "c2", r.driftsresultat)}</td></tr>
        <tr><td>Finansinntekter</td><td>#{non_fraction("nrs:Finansinntekter", "c2", r.finansinntekter)}</td></tr>
        <tr><td>Finanskostnader</td><td>#{non_fraction("nrs:Finanskostnader", "c2", r.finanskostnader)}</td></tr>
        <tr class="total"><td>Resultat før skattekostnad</td><td>#{non_fraction("nrs:ResultatFoerSkattekostnad", "c2", r.resultat_foer_skatt)}</td></tr>
        <tr><td>Skattekostnad</td><td>#{non_fraction("nrs:Skattekostnad", "c2", r.skattekostnad)}</td></tr>
        <tr class="total"><td>Årsresultat</td><td>#{non_fraction("nrs:Aarsresultat", "c2", r.aarsresultat)}</td></tr>
      </table>

      <h2>Balanse</h2>
      <table>
        <tr><th>Post</th><th>Beløp (NOK)</th></tr>
        <tr><td>Anleggsmidler</td><td>#{non_fraction("nrs:Anleggsmidler", "c1", b.anleggsmidler)}</td></tr>
        <tr><td>Omløpsmidler</td><td>#{non_fraction("nrs:Omloepsmidler", "c1", b.omloepsmidler)}</td></tr>
        <tr class="total"><td>Sum eiendeler</td><td>#{non_fraction("nrs:SumEiendeler", "c1", b.sum_eiendeler)}</td></tr>
        <tr><td>Innskutt egenkapital</td><td>#{non_fraction("nrs:InnskuttEgenkapital", "c1", b.innskutt_egenkapital)}</td></tr>
        <tr><td>Opptjent egenkapital</td><td>#{non_fraction("nrs:OpptjentEgenkapital", "c1", b.opptjent_egenkapital)}</td></tr>
        <tr class="total"><td>Sum egenkapital</td><td>#{non_fraction("nrs:SumEgenkapital", "c1", b.sum_egenkapital)}</td></tr>
        <tr><td>Langsiktig gjeld</td><td>#{non_fraction("nrs:LangsiktigGjeld", "c1", b.langsiktig_gjeld)}</td></tr>
        <tr><td>Kortsiktig gjeld</td><td>#{non_fraction("nrs:KortsiktigGjeld", "c1", b.kortsiktig_gjeld)}</td></tr>
        <tr class="total"><td>Sum gjeld</td><td>#{non_fraction("nrs:SumGjeld", "c1", b.sum_gjeld)}</td></tr>
        <tr class="total"><td>Sum egenkapital og gjeld</td><td>#{non_fraction("nrs:SumEgenkapitalOgGjeld", "c1", Decimal.add(b.sum_egenkapital, b.sum_gjeld))}</td></tr>
      </table>
    </body>
    </html>
    """

    {:ok, html}
  end

  defp non_fraction(concept, context_ref, value) do
    nok_value = value |> Decimal.round(0) |> Decimal.to_integer()

    "<ix:nonFraction name=\"#{concept}\" contextRef=\"#{context_ref}\" unitRef=\"NOK\" decimals=\"0\" format=\"ixt:numcommadot\">#{nok_value}</ix:nonFraction>"
  end

  defp escape_html(nil), do: ""

  defp escape_html(str) do
    str
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
