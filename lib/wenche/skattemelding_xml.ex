defmodule Wenche.SkattemeldingXml do
  @moduledoc """
  XML generation for skattemelding (tax return) submission to Skatteetaten.

  Generates three XML documents:
  1. `skattemeldingUpersonlig` — the tax return for AS companies
  2. `naeringsspesifikasjon` — detailed business specification
  3. `skattemeldingOgNaeringsspesifikasjonRequest` — the envelope wrapping both

  All amounts are integers (whole kroner) per Skatteetaten's schema.
  """

  alias Wenche.Models.{
    Aarsregnskap,
    Anleggsmidler,
    Driftsinntekter,
    Driftskostnader,
    Eiendeler,
    Finansposter,
    KortsiktigGjeld,
    LangsiktigGjeld,
    Resultatregnskap,
    SkattemeldingKonfig
  }

  @skattemelding_ns "urn:no:skatteetaten:fastsetting:formueinntekt:skattemelding:upersonlig:ekstern:v5"
  @naering_ns "urn:no:skatteetaten:fastsetting:formueinntekt:naeringsspesifikasjon:ekstern:v5"
  @request_ns "no:skatteetaten:fastsetting:formueinntekt:skattemeldingognaeringsspesifikasjon:request:v2"

  @skattesats 0.22

  # ── skattemeldingUpersonlig ──────────────────────────────────────────

  @doc """
  Generates the `skattemeldingUpersonlig` XML document.

  Maps financial data to `inntektOgUnderskudd` and `formueOgGjeld`.
  """
  def generer_skattemelding_xml(%Aarsregnskap{} = regnskap, %SkattemeldingKonfig{} = konfig) do
    r = regnskap.resultatregnskap
    b = regnskap.balanse
    org = regnskap.selskap.org_nummer
    aar = regnskap.regnskapsaar

    {naeringsinntekt, _beregnet_skatt} = beregn_skattepliktig_inntekt(r, konfig)

    inntekt_foer_konsernbidrag = max(naeringsinntekt, 0)
    samlet_inntekt = max(naeringsinntekt, 0)

    eiendeler = b.eiendeler
    eog = b.egenkapital_og_gjeld

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <skattemelding xmlns="#{@skattemelding_ns}">
      <partsnummer>#{escape(org)}</partsnummer>
      <inntektsaar>#{aar}</inntektsaar>
      <inntektOgUnderskudd>
        <inntekt>
          <naeringsinntekt><beloepSomHeltall>#{naeringsinntekt}</beloepSomHeltall></naeringsinntekt>
        </inntekt>
        <inntektFoerFradragForEventueltAvgittKonsernbidrag>
          <beloepSomHeltall>#{inntekt_foer_konsernbidrag}</beloepSomHeltall>
        </inntektFoerFradragForEventueltAvgittKonsernbidrag>
        <samletInntekt>
          <beloep><beloepSomHeltall>#{samlet_inntekt}</beloepSomHeltall></beloep>
        </samletInntekt>
      </inntektOgUnderskudd>
      <formueOgGjeld>
        <verdiFoerVerdsettingsrabattForAksjeIkkeRegistrertIVerdipapirsentralen>
          <beloepSomHeltall>#{Anleggsmidler.sum(eiendeler.anleggsmidler)}</beloepSomHeltall>
        </verdiFoerVerdsettingsrabattForAksjeIkkeRegistrertIVerdipapirsentralen>
        <bankinnskudd>
          <beloepSomHeltall>#{eiendeler.omloepmidler.bankinnskudd}</beloepSomHeltall>
        </bankinnskudd>
        <samletGjeld>
          <beloepSomHeltall>#{LangsiktigGjeld.sum(eog.langsiktig_gjeld) + KortsiktigGjeld.sum(eog.kortsiktig_gjeld)}</beloepSomHeltall>
        </samletGjeld>
        <nettoFormue>
          <beloepSomHeltall>#{Eiendeler.sum(eiendeler) - LangsiktigGjeld.sum(eog.langsiktig_gjeld) - KortsiktigGjeld.sum(eog.kortsiktig_gjeld)}</beloepSomHeltall>
        </nettoFormue>
      </formueOgGjeld>
    </skattemelding>
    """
    |> String.trim()
  end

  # ── naeringsspesifikasjon ───────────────────────────────────────────

  @doc """
  Generates the `naeringsspesifikasjon` XML document.

  Maps income statement line items and balance sheet data.
  """
  def generer_naeringsspesifikasjon_xml(%Aarsregnskap{} = regnskap) do
    r = regnskap.resultatregnskap
    org = regnskap.selskap.org_nummer
    aar = regnskap.regnskapsaar

    di = r.driftsinntekter
    dk = r.driftskostnader
    fp = r.finansposter

    sum_driftsinntekter = Driftsinntekter.sum(di)
    sum_driftskostnader = Driftskostnader.sum(dk)
    driftsresultat = Resultatregnskap.driftsresultat(r)
    sum_finansinntekter = Finansposter.sum_inntekter(fp)
    sum_finanskostnader = Finansposter.sum_kostnader(fp)
    aarsresultat = Resultatregnskap.resultat_foer_skatt(r)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <naeringsspesifikasjon xmlns="#{@naering_ns}">
      <partsreferanse>#{escape(org)}</partsreferanse>
      <inntektsaar>#{aar}</inntektsaar>
      <resultatregnskap>
        <driftsinntekt>
          <sumDriftsinntekt><beloep><beloep>#{sum_driftsinntekter}</beloep></beloep></sumDriftsinntekt>
    #{driftsinntekt_poster(di)}
        </driftsinntekt>
        <driftskostnad>
          <sumDriftskostnad><beloep><beloep>#{sum_driftskostnader}</beloep></beloep></sumDriftskostnad>
    #{driftskostnad_poster(dk)}
        </driftskostnad>
        <driftsresultat><beloep><beloep>#{driftsresultat}</beloep></beloep></driftsresultat>
        <finansinntekt>
          <sumFinansinntekt><beloep><beloep>#{sum_finansinntekter}</beloep></beloep></sumFinansinntekt>
    #{finansinntekt_poster(fp)}
        </finansinntekt>
        <finanskostnad>
          <sumFinanskostnad><beloep><beloep>#{sum_finanskostnader}</beloep></beloep></sumFinanskostnad>
    #{finanskostnad_poster(fp)}
        </finanskostnad>
        <aarsresultat><beloep><beloep>#{aarsresultat}</beloep></beloep></aarsresultat>
      </resultatregnskap>
      <virksomhet>
        <regnskapsplikttype><regnskapsplikttype>fullRegnskapsplikt</regnskapsplikttype></regnskapsplikttype>
        <regnskapsperiode>
          <start><dato>#{aar}-01-01</dato></start>
          <slutt><dato>#{aar}-12-31</dato></slutt>
        </regnskapsperiode>
        <virksomhetstype><virksomhetstype>oevrigSelskap</virksomhetstype></virksomhetstype>
        <regeltypeForAarsregnskap><regeltypeForAarsregnskap>regnskapslovensAlminneligeRegler</regeltypeForAarsregnskap></regeltypeForAarsregnskap>
      </virksomhet>
      <skalBekreftedsAvRevisor>false</skalBekreftedsAvRevisor>
    </naeringsspesifikasjon>
    """
    |> String.trim()
  end

  # ── Request envelope ────────────────────────────────────────────────

  @doc """
  Generates the request envelope XML wrapping both inner documents.

  ## Options

  - `:dokumentidentifikator` — reference to the existing draft (from `hent_utkast`)
  - `:inntektsaar` — overrides the year from the inner documents
  """
  def generer_request_xml(skattemelding_xml, naeringsspesifikasjon_xml, opts \\ []) do
    skattemelding_b64 = Base.encode64(skattemelding_xml)
    naering_b64 = Base.encode64(naeringsspesifikasjon_xml)
    dokid = Keyword.get(opts, :dokumentidentifikator, "")
    aar = Keyword.get(opts, :inntektsaar, "")

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <skattemeldingOgNaeringsspesifikasjonRequest xmlns="#{@request_ns}">
      <dokumenter>
        <dokument>
          <type>skattemeldingUpersonlig</type>
          <encoding>utf-8</encoding>
          <content>#{skattemelding_b64}</content>
        </dokument>
        <dokument>
          <type>naeringsspesifikasjon</type>
          <encoding>utf-8</encoding>
          <content>#{naering_b64}</content>
        </dokument>
      </dokumenter>
      <dokumentreferanseTilGjeldendeDokument>
        <dokumenttype>skattemeldingUpersonlig</dokumenttype>
        <dokumentidentifikator>#{escape(dokid)}</dokumentidentifikator>
      </dokumentreferanseTilGjeldendeDokument>
      <inntektsaar>#{aar}</inntektsaar>
      <innsendingsinformasjon>
        <innsendingstype>komplett</innsendingstype>
        <opprettetAv>Kontira</opprettetAv>
      </innsendingsinformasjon>
    </skattemeldingOgNaeringsspesifikasjonRequest>
    """
    |> String.trim()
  end

  # ── Tax calculation ─────────────────────────────────────────────────

  @doc """
  Calculates taxable income and tax amount, applying fritaksmetoden and loss carryforward.

  Returns `{naeringsinntekt, beregnet_skatt}`.
  """
  def beregn_skattepliktig_inntekt(%Resultatregnskap{} = r, %SkattemeldingKonfig{} = konfig) do
    driftsresultat = Resultatregnskap.driftsresultat(r)
    utbytte = r.finansposter.utbytte_fra_datterselskap

    skattepliktig_utbytte =
      if konfig.anvend_fritaksmetoden and utbytte > 0 do
        if konfig.eierandel_datterselskap >= 90 do
          0
        else
          ceil(utbytte * 0.03)
        end
      else
        utbytte
      end

    andre_finansinntekter = r.finansposter.andre_finansinntekter
    fin_kostnader = Finansposter.sum_kostnader(r.finansposter)

    brutto = driftsresultat + skattepliktig_utbytte + andre_finansinntekter - fin_kostnader

    fradrag_underskudd =
      if brutto > 0 and konfig.underskudd_til_fremfoering > 0 do
        min(konfig.underskudd_til_fremfoering, brutto)
      else
        0
      end

    netto = brutto - fradrag_underskudd

    beregnet_skatt =
      if netto > 0 do
        ceil(netto * @skattesats)
      else
        0
      end

    {netto, beregnet_skatt}
  end

  # ── Private helpers ─────────────────────────────────────────────────

  defp driftsinntekt_poster(%Driftsinntekter{} = di) do
    poster = []

    poster =
      if di.salgsinntekter != 0 do
        [inntekt_post(di.salgsinntekter, "3000") | poster]
      else
        poster
      end

    poster =
      if di.andre_driftsinntekter != 0 do
        [inntekt_post(di.andre_driftsinntekter, "3900") | poster]
      else
        poster
      end

    poster |> Enum.reverse() |> Enum.join("\n")
  end

  defp driftskostnad_poster(%Driftskostnader{} = dk) do
    poster = []

    poster =
      if dk.loennskostnader != 0 do
        [kostnad_post(dk.loennskostnader, "5000") | poster]
      else
        poster
      end

    poster =
      if dk.avskrivninger != 0 do
        [kostnad_post(dk.avskrivninger, "6000") | poster]
      else
        poster
      end

    poster =
      if dk.andre_driftskostnader != 0 do
        [kostnad_post(dk.andre_driftskostnader, "6995") | poster]
      else
        poster
      end

    poster |> Enum.reverse() |> Enum.join("\n")
  end

  defp finansinntekt_poster(%Finansposter{} = fp) do
    poster = []

    poster =
      if fp.utbytte_fra_datterselskap != 0 do
        [inntekt_post(fp.utbytte_fra_datterselskap, "8050") | poster]
      else
        poster
      end

    poster =
      if fp.andre_finansinntekter != 0 do
        [inntekt_post(fp.andre_finansinntekter, "8099") | poster]
      else
        poster
      end

    poster |> Enum.reverse() |> Enum.join("\n")
  end

  defp finanskostnad_poster(%Finansposter{} = fp) do
    poster = []

    poster =
      if fp.rentekostnader != 0 do
        [kostnad_post(fp.rentekostnader, "8150") | poster]
      else
        poster
      end

    poster =
      if fp.andre_finanskostnader != 0 do
        [kostnad_post(fp.andre_finanskostnader, "8199") | poster]
      else
        poster
      end

    poster |> Enum.reverse() |> Enum.join("\n")
  end

  defp inntekt_post(beloep, type) do
    """
          <salgsinntekt>
            <inntekt>
              <beloep><beloep><beloep>#{beloep}</beloep></beloep></beloep>
              <id>#{type}</id>
              <type><resultatOgBalanseregnskapstype>#{type}</resultatOgBalanseregnskapstype></type>
            </inntekt>
          </salgsinntekt>
    """
    |> String.trim_trailing()
  end

  defp kostnad_post(beloep, type) do
    """
          <annenDriftskostnad>
            <kostnad>
              <beloep><beloep><beloep>#{beloep}</beloep></beloep></beloep>
              <id>#{type}</id>
              <type><resultatOgBalanseregnskapstype>#{type}</resultatOgBalanseregnskapstype></type>
            </kostnad>
          </annenDriftskostnad>
    """
    |> String.trim_trailing()
  end

  defp escape(str) when is_binary(str) do
    str
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  defp escape(other), do: to_string(other)
end
