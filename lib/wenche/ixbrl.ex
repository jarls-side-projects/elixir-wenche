defmodule Wenche.Ixbrl do
  @moduledoc """
  Generates inline XBRL (iXBRL) HTML documents for annual statements.

  Ported from `wenche/xbrl.py` in the original Python Wenche project.

  iXBRL is the format required by Bronnøysundregistrene. It combines HTML
  with embedded XBRL tags, making financial figures machine-readable
  while remaining viewable in web browsers.

  Taxonomy: Norwegian GAAP (NRS) simplified for small enterprises.
  """

  alias Wenche.Models.{
    Aarsregnskap,
    Driftsinntekter,
    Driftskostnader,
    Resultatregnskap,
    Eiendeler,
    Anleggsmidler,
    Omloepmidler,
    Egenkapital,
    LangsiktigGjeld,
    KortsiktigGjeld,
    EgenkapitalOgGjeld
  }

  @doc """
  Generates an iXBRL HTML document from an Aarsregnskap struct.

  Returns UTF-8 encoded HTML bytes.
  """
  def generer_ixbrl(%Aarsregnskap{} = regnskap) do
    s = regnskap.selskap
    r = regnskap.resultatregnskap
    b = regnskap.balanse
    aar = regnskap.regnskapsaar
    periode_start = "#{aar}-01-01"
    periode_slutt = "#{aar}-12-31"
    dato_i_dag = Date.to_iso8601(Date.utc_today())

    xbrl_contexts = """
        <xbrli:context id="c1">
          <xbrli:entity>
            <xbrli:identifier scheme="http://www.brreg.no/organisasjonsnummer">
              #{escape(s.org_nummer)}
            </xbrli:identifier>
          </xbrli:entity>
          <xbrli:period>
            <xbrli:instant>#{periode_slutt}</xbrli:instant>
          </xbrli:period>
        </xbrli:context>
        <xbrli:context id="c2">
          <xbrli:entity>
            <xbrli:identifier scheme="http://www.brreg.no/organisasjonsnummer">
              #{escape(s.org_nummer)}
            </xbrli:identifier>
          </xbrli:entity>
          <xbrli:period>
            <xbrli:startDate>#{periode_start}</xbrli:startDate>
            <xbrli:endDate>#{periode_slutt}</xbrli:endDate>
          </xbrli:period>
        </xbrli:context>
        <xbrli:unit id="NOK">
          <xbrli:measure>iso4217:NOK</xbrli:measure>
        </xbrli:unit>
    """

    di = r.driftsinntekter
    dk = r.driftskostnader
    fp = r.finansposter
    am = b.eiendeler.anleggsmidler
    om = b.eiendeler.omloepmidler
    ek = b.egenkapital_og_gjeld.egenkapital
    lg = b.egenkapital_og_gjeld.langsiktig_gjeld
    kg = b.egenkapital_og_gjeld.kortsiktig_gjeld

    html = """
    <?xml version="1.0" encoding="UTF-8"?>
    <html
      xmlns="http://www.w3.org/1999/xhtml"
      xmlns:ix="http://www.xbrl.org/2013/inlineXBRL"
      xmlns:ixt="http://www.xbrl.org/inlineXBRL/transformation/2020-02-12"
      xmlns:xbrli="http://www.xbrl.org/2003/instance"
      xmlns:xbrldi="http://xbrl.org/2006/xbrldi"
      xmlns:iso4217="http://www.xbrl.org/2003/iso4217"
      xmlns:no-gaap="http://xbrl.nrs.no/no-gaap/2022-12-31"
      xmlns:link="http://www.xbrl.org/2003/linkbase"
      xmlns:xlink="http://www.w3.org/1999/xlink">
    <head>
      <meta charset="UTF-8"/>
      <title>Årsregnskap #{aar} — #{escape(s.navn)}</title>
      <ix:header>
        <ix:hidden>
    #{xbrl_contexts}
        </ix:hidden>
        <ix:references>
          <link:schemaRef
            xlink:type="simple"
            xlink:href="http://xbrl.nrs.no/no-gaap/2022-12-31/no-gaap-small-2022-12-31.xsd"/>
        </ix:references>
      </ix:header>
    </head>
    <body>
      <h1>Årsregnskap #{aar}</h1>
      <p>
        <strong>Selskap:</strong> #{escape(s.navn)}<br/>
        <strong>Organisasjonsnummer:</strong> #{escape(s.org_nummer)}<br/>
        <strong>Regnskapsperiode:</strong> #{periode_start} – #{periode_slutt}<br/>
        <strong>Daglig leder:</strong> #{escape(s.daglig_leder)}<br/>
        <strong>Styreleder:</strong> #{escape(s.styreleder)}<br/>
        <strong>Dato signert:</strong> #{dato_i_dag}
      </p>

      <h2>Resultatregnskap</h2>
      <table border="1" cellpadding="4" style="border-collapse:collapse">
        <tr><th>Post</th><th>Beløp (NOK)</th></tr>

        <tr><td>Driftsinntekter</td>
            <td>#{tag("SalesRevenue", di.salgsinntekter, "c2")}</td></tr>
        <tr><td>Andre driftsinntekter</td>
            <td>#{tag("OtherOperatingIncome", di.andre_driftsinntekter, "c2")}</td></tr>
        <tr><td><strong>Sum driftsinntekter</strong></td>
            <td><strong>#{tag("TotalOperatingIncome", Driftsinntekter.sum(di), "c2")}</strong></td></tr>

        <tr><td>Lønnskostnader</td>
            <td>#{tag("WagesAndSalaries", dk.loennskostnader, "c2")}</td></tr>
        <tr><td>Avskrivninger</td>
            <td>#{tag("DepreciationAmortisation", dk.avskrivninger, "c2")}</td></tr>
        <tr><td>Andre driftskostnader</td>
            <td>#{tag("OtherOperatingExpenses", dk.andre_driftskostnader, "c2")}</td></tr>
        <tr><td><strong>Sum driftskostnader</strong></td>
            <td><strong>#{tag("TotalOperatingExpenses", Driftskostnader.sum(dk), "c2")}</strong></td></tr>

        <tr><td><strong>Driftsresultat</strong></td>
            <td><strong>#{tag("OperatingProfit", Resultatregnskap.driftsresultat(r), "c2")}</strong></td></tr>

        <tr><td>Utbytte fra datterselskap</td>
            <td>#{tag("DividendsFromSubsidiaries", fp.utbytte_fra_datterselskap, "c2")}</td></tr>
        <tr><td>Andre finansinntekter</td>
            <td>#{tag("OtherFinancialIncome", fp.andre_finansinntekter, "c2")}</td></tr>
        <tr><td>Rentekostnader</td>
            <td>#{tag("InterestExpense", fp.rentekostnader, "c2")}</td></tr>
        <tr><td>Andre finanskostnader</td>
            <td>#{tag("OtherFinancialExpenses", fp.andre_finanskostnader, "c2")}</td></tr>

        <tr><td><strong>Resultat før skatt</strong></td>
            <td><strong>#{tag("ProfitLossBeforeTax", Resultatregnskap.resultat_foer_skatt(r), "c2")}</strong></td></tr>
        <tr><td><strong>Årsresultat</strong></td>
            <td><strong>#{tag("ProfitLoss", Resultatregnskap.aarsresultat(r), "c2")}</strong></td></tr>
      </table>

      <h2>Balanse per #{periode_slutt}</h2>
      <table border="1" cellpadding="4" style="border-collapse:collapse">
        <tr><th>Post</th><th>Beløp (NOK)</th></tr>

        <tr><td colspan="2"><strong>EIENDELER</strong></td></tr>
        <tr><td>Aksjer i datterselskap</td>
            <td>#{tag("InvestmentsInSubsidiaries", am.aksjer_i_datterselskap, "c1")}</td></tr>
        <tr><td>Andre aksjer</td>
            <td>#{tag("OtherInvestments", am.andre_aksjer, "c1")}</td></tr>
        <tr><td>Langsiktige fordringer</td>
            <td>#{tag("OtherLongTermReceivables", am.langsiktige_fordringer, "c1")}</td></tr>
        <tr><td><strong>Sum anleggsmidler</strong></td>
            <td><strong>#{tag("TotalNonCurrentAssets", Anleggsmidler.sum(am), "c1")}</strong></td></tr>

        <tr><td>Kortsiktige fordringer</td>
            <td>#{tag("TradeAndOtherCurrentReceivables", om.kortsiktige_fordringer, "c1")}</td></tr>
        <tr><td>Bankinnskudd</td>
            <td>#{tag("CashAndCashEquivalents", om.bankinnskudd, "c1")}</td></tr>
        <tr><td><strong>Sum omløpsmidler</strong></td>
            <td><strong>#{tag("TotalCurrentAssets", Omloepmidler.sum(om), "c1")}</strong></td></tr>

        <tr><td><strong>SUM EIENDELER</strong></td>
            <td><strong>#{tag("Assets", Eiendeler.sum(b.eiendeler), "c1")}</strong></td></tr>

        <tr><td colspan="2"><strong>EGENKAPITAL OG GJELD</strong></td></tr>
        <tr><td>Aksjekapital</td>
            <td>#{tag("IssuedCapital", ek.aksjekapital, "c1")}</td></tr>
        <tr><td>Overkursfond</td>
            <td>#{tag("SharePremium", ek.overkursfond, "c1")}</td></tr>
        <tr><td>Annen egenkapital</td>
            <td>#{tag("RetainedEarnings", ek.annen_egenkapital, "c1")}</td></tr>
        <tr><td><strong>Sum egenkapital</strong></td>
            <td><strong>#{tag("Equity", Egenkapital.sum(ek), "c1")}</strong></td></tr>

        <tr><td>Lån fra aksjonær</td>
            <td>#{tag("LongTermLiabilitiesToRelatedParties", lg.laan_fra_aksjonaer, "c1")}</td></tr>
        <tr><td>Andre langsiktige lån</td>
            <td>#{tag("OtherLongTermLiabilities", lg.andre_langsiktige_laan, "c1")}</td></tr>
        <tr><td><strong>Sum langsiktig gjeld</strong></td>
            <td><strong>#{tag("TotalNonCurrentLiabilities", LangsiktigGjeld.sum(lg), "c1")}</strong></td></tr>

        <tr><td>Leverandørgjeld</td>
            <td>#{tag("TradeAndOtherPayables", kg.leverandoergjeld, "c1")}</td></tr>
        <tr><td>Skyldige offentlige avgifter</td>
            <td>#{tag("CurrentTaxLiabilities", kg.skyldige_offentlige_avgifter, "c1")}</td></tr>
        <tr><td>Annen kortsiktig gjeld</td>
            <td>#{tag("OtherCurrentLiabilities", kg.annen_kortsiktig_gjeld, "c1")}</td></tr>
        <tr><td><strong>Sum kortsiktig gjeld</strong></td>
            <td><strong>#{tag("TotalCurrentLiabilities", KortsiktigGjeld.sum(kg), "c1")}</strong></td></tr>

        <tr><td><strong>SUM EGENKAPITAL OG GJELD</strong></td>
            <td><strong>#{tag("EquityAndLiabilities", EgenkapitalOgGjeld.sum(b.egenkapital_og_gjeld), "c1")}</strong></td></tr>
      </table>

      <h2>Noter</h2>
    #{noter_html(regnskap)}
    </body>
    </html>
    """

    String.trim(html)
  end

  defp noter_html(%Aarsregnskap{} = regnskap) do
    Wenche.Noter.generer_noter_tekst(regnskap)
    |> Enum.map(fn {title, content} ->
      """
        <h3>#{escape(title)}</h3>
        <p style="white-space:pre-line">#{escape(content)}</p>
      """
    end)
    |> Enum.join("\n")
  end

  defp tag(concept, value, context) do
    ~s(<ix:nonFraction name="no-gaap:#{concept}" contextRef="#{context}" unitRef="NOK" decimals="0" format="ixt:num-dot-decimal">#{value}</ix:nonFraction>)
  end

  defp escape(nil), do: ""

  defp escape(str) when is_binary(str) do
    str
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp escape(val), do: to_string(val)
end
