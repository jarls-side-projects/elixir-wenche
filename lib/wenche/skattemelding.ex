defmodule Wenche.Skattemelding do
  @moduledoc """
  Tax return generation for Norwegian AS (RF-1028 and RF-1167).

  Ported from `wenche/skattemelding.py` in the original Python Wenche project.

  Wenche produces a complete pre-filled summary that you use as reference
  when submitting the tax return manually at skatteetaten.no.

  Supports:
  - Standard 22% corporate tax calculation
  - Fritaksmetoden (participation exemption) for subsidiary dividends
  - Loss carryforward deduction
  - Prior year comparison figures
  - Equity reconciliation note
  """

  alias Wenche.Models.{
    Aarsregnskap,
    SkattemeldingKonfig,
    Resultatregnskap,
    Balanse,
    Driftsinntekter,
    Driftskostnader,
    Finansposter,
    Eiendeler,
    Anleggsmidler,
    Omloepmidler,
    Egenkapital,
    EgenkapitalOgGjeld,
    LangsiktigGjeld,
    KortsiktigGjeld
  }

  @skattesats 0.22

  @doc """
  Generates a complete pre-filled summary for RF-1167 and RF-1028.

  Returns the report as a string.
  """
  def generer(%Aarsregnskap{} = regnskap, %SkattemeldingKonfig{} = konfig) do
    r = regnskap.resultatregnskap
    b = regnskap.balanse
    s = regnskap.selskap
    aar = regnskap.regnskapsaar
    fr = regnskap.foregaaende_aar_resultat
    fb = regnskap.foregaaende_aar_balanse

    har_fjoraar =
      fr != %Resultatregnskap{} or fb != %Balanse{}

    # --- RF-1167: Næringsoppgave ---
    driftsinntekter = Driftsinntekter.sum(r.driftsinntekter)
    driftskostnader = Driftskostnader.sum(r.driftskostnader)
    driftsresultat = Resultatregnskap.driftsresultat(r)

    fin_kostnader = Finansposter.sum_kostnader(r.finansposter)
    resultat_foer_skatt = Resultatregnskap.resultat_foer_skatt(r)

    # --- RF-1028: Skatteberegning ---
    utbytte = r.finansposter.utbytte_fra_datterselskap

    {skattepliktig_utbytte, fritatt_utbytte} =
      if konfig.anvend_fritaksmetoden and utbytte > 0 do
        if konfig.eierandel_datterselskap >= 90 do
          {0, utbytte}
        else
          skattepliktig = ceil(utbytte * 0.03)
          {skattepliktig, utbytte - skattepliktig}
        end
      else
        {utbytte, 0}
      end

    andre_finansinntekter = r.finansposter.andre_finansinntekter

    skattepliktig_inntekt_brutto =
      driftsresultat + skattepliktig_utbytte + andre_finansinntekter - fin_kostnader

    fradrag_underskudd =
      if skattepliktig_inntekt_brutto > 0 and konfig.underskudd_til_fremfoering > 0 do
        min(konfig.underskudd_til_fremfoering, skattepliktig_inntekt_brutto)
      else
        0
      end

    skattepliktig_inntekt_netto = skattepliktig_inntekt_brutto - fradrag_underskudd

    nytt_underskudd =
      if skattepliktig_inntekt_brutto < 0 do
        konfig.underskudd_til_fremfoering + abs(skattepliktig_inntekt_brutto)
      else
        konfig.underskudd_til_fremfoering - fradrag_underskudd
      end

    beregnet_skatt =
      if skattepliktig_inntekt_netto > 0 do
        ceil(skattepliktig_inntekt_netto * @skattesats)
      else
        0
      end

    i_balanse = Balanse.er_i_balanse?(b)
    differanse = Balanse.differanse(b)

    linje = String.duplicate("─", 60)
    bred = String.duplicate("═", 60)

    linjer =
      [
        bred,
        "  SKATTEMELDING FOR AS — #{aar}",
        "  #{s.navn}  |  Org.nr. #{s.org_nummer}",
        bred,
        "",
        linje,
        "  RF-1167  NÆRINGSOPPGAVE",
        linje,
        "",
        "  DRIFTSINNTEKTER",
        "    Salgsinntekter               #{nok(r.driftsinntekter.salgsinntekter)}",
        "    Andre driftsinntekter        #{nok(r.driftsinntekter.andre_driftsinntekter)}",
        "  Sum driftsinntekter            #{nok(driftsinntekter)}",
        "",
        "  DRIFTSKOSTNADER",
        "    Lønnskostnader               #{nok(r.driftskostnader.loennskostnader)}",
        "    Avskrivninger                #{nok(r.driftskostnader.avskrivninger)}",
        "    Andre driftskostnader        #{nok(r.driftskostnader.andre_driftskostnader)}",
        "  Sum driftskostnader            #{nok(driftskostnader)}",
        "",
        "  DRIFTSRESULTAT                 #{nok(driftsresultat)}",
        "",
        "  FINANSPOSTER",
        "    Utbytte fra datterselskap    #{nok(utbytte)}",
        "    Andre finansinntekter        #{nok(andre_finansinntekter)}",
        "    Rentekostnader               #{nok(r.finansposter.rentekostnader)}",
        "    Andre finanskostnader        #{nok(r.finansposter.andre_finanskostnader)}",
        "",
        "  RESULTAT FØR SKATT             #{nok(resultat_foer_skatt)}",
        "  Skattekostnad                  #{nok(-beregnet_skatt)}",
        "  ÅRSRESULTAT                    #{nok(resultat_foer_skatt - beregnet_skatt)}",
        "",
        linje,
        "  RF-1028  SKATTEMELDING FOR AS",
        linje,
        "",
        "  INNTEKTER OG FRADRAG",
        "    Driftsresultat               #{nok(driftsresultat)}"
      ] ++
        fritaksmetoden_linjer(konfig, utbytte, fritatt_utbytte, skattepliktig_utbytte) ++
        [
          "    Andre finansinntekter        #{nok(andre_finansinntekter)}",
          "    Finanskostnader             -#{nok(fin_kostnader)}",
          "  Skattepliktig inntekt (brutto) #{nok(skattepliktig_inntekt_brutto)}"
        ] ++
        underskudd_linjer(fradrag_underskudd) ++
        [
          "  SKATTEPLIKTIG INNTEKT (NETTO)  #{nok(skattepliktig_inntekt_netto)}",
          "",
          "  Beregnet skatt (22 %)          #{nok(beregnet_skatt)}",
          ""
        ] ++
        fremforing_linjer(nytt_underskudd) ++
        balanse_linjer(b) ++
        sammenligning_linjer(har_fjoraar, aar, r, fr, b, fb) ++
        egenkapital_note_linjer(har_fjoraar, aar, regnskap, beregnet_skatt) ++
        balanse_kontroll_linjer(i_balanse, differanse) ++
        skatt_varsel_linjer(beregnet_skatt) ++
        neste_steg_linjer(aar, bred)

    Enum.join(linjer, "\n") <> "\n"
  end

  defp fritaksmetoden_linjer(konfig, utbytte, fritatt_utbytte, skattepliktig_utbytte) do
    if konfig.anvend_fritaksmetoden and utbytte > 0 do
      if konfig.eierandel_datterselskap >= 90 do
        ["    Utbytte (100 % fritatt)      #{nok(fritatt_utbytte)}"]
      else
        [
          "    Utbytte (fritatt, 97 %)      #{nok(fritatt_utbytte)}",
          "    Utbytte (sjablonregel, 3 %)  #{nok(skattepliktig_utbytte)}"
        ]
      end
    else
      ["    Utbytte                      #{nok(utbytte)}"]
    end
  end

  defp underskudd_linjer(0), do: []

  defp underskudd_linjer(fradrag) do
    ["  Fradrag: fremf. underskudd  -#{nok(fradrag)}"]
  end

  defp fremforing_linjer(0), do: []

  defp fremforing_linjer(nytt_underskudd) when nytt_underskudd > 0 do
    [
      "  Underskudd til fremføring      #{nok(nytt_underskudd)}",
      "  (føres på skattemeldingen under «Underskudd til fremføring»)",
      ""
    ]
  end

  defp fremforing_linjer(_), do: []

  defp balanse_linjer(b) do
    am = b.eiendeler.anleggsmidler
    om = b.eiendeler.omloepmidler
    ek = b.egenkapital_og_gjeld.egenkapital
    lg = b.egenkapital_og_gjeld.langsiktig_gjeld
    kg = b.egenkapital_og_gjeld.kortsiktig_gjeld
    linje = String.duplicate("─", 60)

    [
      linje,
      "  RF-1167  BALANSE",
      linje,
      "",
      "  EIENDELER",
      "    Anleggsmidler:",
      "      Aksjer i datterselskap      #{nok(am.aksjer_i_datterselskap)}",
      "      Andre aksjer                #{nok(am.andre_aksjer)}",
      "      Langsiktige fordringer      #{nok(am.langsiktige_fordringer)}",
      "    Sum anleggsmidler             #{nok(Anleggsmidler.sum(am))}",
      "",
      "    Omløpsmidler:",
      "      Kortsiktige fordringer      #{nok(om.kortsiktige_fordringer)}",
      "      Bankinnskudd                #{nok(om.bankinnskudd)}",
      "    Sum omløpsmidler              #{nok(Omloepmidler.sum(om))}",
      "",
      "  SUM EIENDELER                  #{nok(Eiendeler.sum(b.eiendeler))}",
      "",
      "  EGENKAPITAL OG GJELD",
      "    Egenkapital:",
      "      Aksjekapital                #{nok(ek.aksjekapital)}",
      "      Overkursfond                #{nok(ek.overkursfond)}",
      "      Annen egenkapital           #{nok(ek.annen_egenkapital)}",
      "    Sum egenkapital               #{nok(Egenkapital.sum(ek))}",
      "",
      "    Langsiktig gjeld:",
      "      Lån fra aksjonær            #{nok(lg.laan_fra_aksjonaer)}",
      "      Andre langsiktige lån       #{nok(lg.andre_langsiktige_laan)}",
      "    Sum langsiktig gjeld          #{nok(LangsiktigGjeld.sum(lg))}",
      "",
      "    Kortsiktig gjeld:",
      "      Leverandørgjeld             #{nok(kg.leverandoergjeld)}",
      "      Skyldige offentlige avgifter #{nok(kg.skyldige_offentlige_avgifter)}",
      "      Annen kortsiktig gjeld      #{nok(kg.annen_kortsiktig_gjeld)}",
      "    Sum kortsiktig gjeld          #{nok(KortsiktigGjeld.sum(kg))}",
      "",
      "  SUM EGENKAPITAL OG GJELD       #{nok(EgenkapitalOgGjeld.sum(b.egenkapital_og_gjeld))}",
      ""
    ]
  end

  defp sammenligning_linjer(false, aar, _r, _fr, _b, _fb) do
    [
      "",
      "  NB: Sammenligningstall for #{aar - 1} er ikke lagt inn.",
      "  Legg til 'foregaaende_aar' i config.yaml (påkrevd, jf. rskl. § 6-6).",
      ""
    ]
  end

  defp sammenligning_linjer(true, aar, r, fr, b, fb) do
    netto_finans_fjor =
      Finansposter.sum_inntekter(fr.finansposter) - Finansposter.sum_kostnader(fr.finansposter)

    linje = String.duplicate("─", 60)

    [
      "",
      linje,
      "  RF-1167  SAMMENLIGNINGSTALL  (rskl. § 6-6)",
      linje,
      "                                 #{pad_right(aar, 12)}   #{pad_right(aar - 1, 12)}",
      "  Sum driftsinntekter          #{nok2(Driftsinntekter.sum(r.driftsinntekter), Driftsinntekter.sum(fr.driftsinntekter))}",
      "  Sum driftskostnader          #{nok2(Driftskostnader.sum(r.driftskostnader), Driftskostnader.sum(fr.driftskostnader))}",
      "  Driftsresultat               #{nok2(Resultatregnskap.driftsresultat(r), Resultatregnskap.driftsresultat(fr))}",
      "  Netto finansposter           #{nok2(Finansposter.sum_inntekter(r.finansposter) - Finansposter.sum_kostnader(r.finansposter), netto_finans_fjor)}",
      "  RESULTAT FØR SKATT           #{nok2(Resultatregnskap.resultat_foer_skatt(r), Resultatregnskap.resultat_foer_skatt(fr))}",
      "  SUM EIENDELER                #{nok2(Eiendeler.sum(b.eiendeler), Eiendeler.sum(fb.eiendeler))}",
      "  SUM EGENKAPITAL OG GJELD     #{nok2(EgenkapitalOgGjeld.sum(b.egenkapital_og_gjeld), EgenkapitalOgGjeld.sum(fb.egenkapital_og_gjeld))}",
      ""
    ]
  end

  defp egenkapital_note_linjer(har_fjoraar, aar, regnskap, beregnet_skatt) do
    linje = String.duplicate("─", 60)
    b = regnskap.balanse
    ek_ub = b.egenkapital_og_gjeld.egenkapital

    aarsresultat =
      Resultatregnskap.resultat_foer_skatt(regnskap.resultatregnskap) - beregnet_skatt

    header_linjer = [
      "",
      linje,
      "  NOTE: EGENKAPITAL  (rskl. § 7-2b)",
      linje,
      "  #{pad_left("", 20)}#{pad_left("AK-kapital", 12)}#{pad_left("Overkursfond", 12)}#{pad_left("Annen EK", 12)}#{pad_left("Sum", 12)}"
    ]

    body_linjer =
      if har_fjoraar do
        fb = regnskap.foregaaende_aar_balanse
        ek_ib = fb.egenkapital_og_gjeld.egenkapital
        delta_ak = ek_ub.aksjekapital - ek_ib.aksjekapital
        delta_ok = ek_ub.overkursfond - ek_ib.overkursfond
        forklart_aek = ek_ib.annen_egenkapital + aarsresultat - regnskap.utbytte_utbetalt
        andre_aek = ek_ub.annen_egenkapital - forklart_aek

        base = [
          ek_rad(
            "EK 01.01.#{aar}",
            ek_ib.aksjekapital,
            ek_ib.overkursfond,
            ek_ib.annen_egenkapital
          ),
          ek_rad("Årsresultat", 0, 0, aarsresultat)
        ]

        utbytte_linje =
          if regnskap.utbytte_utbetalt != 0 do
            [ek_rad("Utbytte utbetalt", 0, 0, -regnskap.utbytte_utbetalt)]
          else
            []
          end

        andre_linje =
          if delta_ak != 0 or delta_ok != 0 or andre_aek != 0 do
            [ek_rad("Andre endringer", delta_ak, delta_ok, andre_aek)]
          else
            []
          end

        slutt = [
          ek_rad(
            "EK 31.12.#{aar}",
            ek_ub.aksjekapital,
            ek_ub.overkursfond,
            ek_ub.annen_egenkapital
          )
        ]

        base ++ utbytte_linje ++ andre_linje ++ slutt
      else
        [
          "  NB: Egenkapitalbevegelse krever foregaaende_aar (rskl. § 7-2b).",
          ek_rad(
            "EK 31.12.#{aar}",
            ek_ub.aksjekapital,
            ek_ub.overkursfond,
            ek_ub.annen_egenkapital
          )
        ]
      end

    header_linjer ++ body_linjer ++ ["  (beløp i hele kroner, NOK)", ""]
  end

  defp balanse_kontroll_linjer(true, _), do: ["  Balansekontroll: OK"]

  defp balanse_kontroll_linjer(false, differanse) do
    ["  ADVARSEL: Balansen stemmer ikke! Differanse: #{nok(differanse)}"]
  end

  defp skatt_varsel_linjer(0), do: []

  defp skatt_varsel_linjer(beregnet_skatt) do
    [
      "",
      "  NB: Beregnet skatt er #{String.trim(nok(beregnet_skatt))}. Husk å føre dette",
      "  som «Skyldig skatt» (konto 2500) under kortsiktig gjeld i balansen,",
      "  og kontroller at balansen fortsatt går opp."
    ]
  end

  defp neste_steg_linjer(aar, bred) do
    [
      "",
      bred,
      "  NESTE STEG",
      bred,
      "",
      "  1. Gå til https://www.skatteetaten.no/ og logg inn med BankID.",
      "  2. Åpne skattemeldingen for AS for #{aar}.",
      "  3. Fyll inn tallene fra RF-1167 og RF-1028 ovenfor.",
      "  4. Kontroller at skatteetaten beregner samme skatt.",
      "  5. Send inn innen 31. mai.",
      "",
      bred
    ]
  end

  defp nok(amount) do
    formatted =
      amount
      |> abs()
      |> Integer.to_string()
      |> String.reverse()
      |> String.to_charlist()
      |> Enum.chunk_every(3)
      |> Enum.join(" ")
      |> String.reverse()

    sign = if amount < 0, do: "-", else: ""
    String.pad_leading("#{sign}#{formatted} kr", 12)
  end

  defp nok2(aarets, fjoraarets) do
    "#{nok(aarets)}   #{nok(fjoraarets)}"
  end

  defp ekk(v) do
    String.pad_leading(Integer.to_string(v) |> add_thousand_sep(), 12)
  end

  defp add_thousand_sep(str) do
    str
    |> String.reverse()
    |> String.to_charlist()
    |> Enum.chunk_every(3)
    |> Enum.join(" ")
    |> String.reverse()
  end

  defp ek_rad(label, ak, ok, aek) do
    s = ak + ok + aek
    "  #{pad_left(label, 20)}#{ekk(ak)}#{ekk(ok)}#{ekk(aek)}#{ekk(s)}"
  end

  defp pad_left(str, width), do: String.pad_leading(to_string(str), width)
  defp pad_right(str, width), do: String.pad_trailing(to_string(str), width)
end
