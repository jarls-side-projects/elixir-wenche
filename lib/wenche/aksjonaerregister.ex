defmodule Wenche.Aksjonaerregister do
  @moduledoc """
  RF-1086 (Aksjonærregisteroppgave) XML generation and validation.

  Ported from `wenche/aksjonaerregister.py` in the original Python Wenche project.

  The shareholder register report is filed annually by January 31st to the
  Norwegian Tax Authority via SKD's own REST API (not Altinn instance flow).

  Submission flow (SKD REST API):
    1. POST Hovedskjema (RF-1086)   — company info and share capital
    2. POST Underskjema (RF-1086-U) — one per shareholder with holdings and transactions
    3. POST bekreft                  — confirm all sub-forms submitted
  """

  alias Wenche.Models.{Aksjonaerregisteroppgave, Aksjonaer}

  @doc """
  Generates RF-1086 Hovedskjema XML for SKD's API.

  Contains company info, share capital, and issuance at founding.
  Validates against: aksjonaerregisteroppgaveHovedskjema.xsd

  Returns the XML as a string.
  """
  def generer_hovedskjema_xml(%Aksjonaerregisteroppgave{} = oppgave) do
    s = oppgave.selskap
    aar = oppgave.regnskapsaar
    total_aksjer = Aksjonaerregisteroppgave.totalt_antall_aksjer(oppgave)
    paalydende = if total_aksjer > 0, do: div(s.aksjekapital, total_aksjer), else: 0
    stiftelsesdato = "#{s.stiftelsesaar}-01-01T00:00:00"

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <Skjema skjemanummer="890" spesifikasjonsnummer="12144"
            blankettnummer="RF-1086" gruppeid="2586" etatid="974761076">
        <GenerellInformasjon-grp-2587 gruppeid="2587">
            <Selskap-grp-2588 gruppeid="2588">
                <EnhetOrganisasjonsnummer-datadef-18 orid="18">#{escape(s.org_nummer)}</EnhetOrganisasjonsnummer-datadef-18>
                <EnhetNavn-datadef-1 orid="1">#{escape(s.navn)}</EnhetNavn-datadef-1>
                <EnhetAdresse-datadef-15 orid="15">#{escape(s.forretningsadresse)}</EnhetAdresse-datadef-15>
                <AksjeType-datadef-17659 orid="17659">01</AksjeType-datadef-17659>
                <Inntektsar-datadef-692 orid="692">#{aar}</Inntektsar-datadef-692>
            </Selskap-grp-2588>
            <Kontaktperson-grp-3442 gruppeid="3442">
                <KontaktpersonSkjemaEPost-datadef-30533 orid="30533">#{escape(s.kontakt_epost)}</KontaktpersonSkjemaEPost-datadef-30533>
            </Kontaktperson-grp-3442>
            <AnnenKontaktperson-grp-5384 gruppeid="5384"></AnnenKontaktperson-grp-5384>
        </GenerellInformasjon-grp-2587>
        <Selskapsopplysninger-grp-2589 gruppeid="2589">
            <AksjekapitalForHeleSelskapet-grp-3443 gruppeid="3443">
                <AksjekapitalFjoraret-datadef-7129 orid="7129">0</AksjekapitalFjoraret-datadef-7129>
                <Aksjekapital-datadef-87 orid="87">#{s.aksjekapital}</Aksjekapital-datadef-87>
            </AksjekapitalForHeleSelskapet-grp-3443>
            <AksjekapitalIDenneAksjeklassen-grp-3444 gruppeid="3444">
                <AksjekapitalISINAksjetypeFjoraret-datadef-17663 orid="17663">0</AksjekapitalISINAksjetypeFjoraret-datadef-17663>
                <AksjekapitalISINAksjetype-datadef-17664 orid="17664">#{s.aksjekapital}</AksjekapitalISINAksjetype-datadef-17664>
            </AksjekapitalIDenneAksjeklassen-grp-3444>
            <PalydendePerAksje-grp-3447 gruppeid="3447">
                <AksjeMvPalydendeFjoraret-datadef-23944 orid="23944">0</AksjeMvPalydendeFjoraret-datadef-23944>
                <AksjeMvPalydende-datadef-23945 orid="23945">#{paalydende}</AksjeMvPalydende-datadef-23945>
            </PalydendePerAksje-grp-3447>
            <AntallAksjerIDenneAksjeklassen-grp-3445 gruppeid="3445">
                <AksjerMvAntallFjoraret-datadef-29166 orid="29166">0</AksjerMvAntallFjoraret-datadef-29166>
                <AksjerMvAntall-datadef-29167 orid="29167">#{total_aksjer}</AksjerMvAntall-datadef-29167>
            </AntallAksjerIDenneAksjeklassen-grp-3445>
            <InnbetaltAksjekapitalIDenneAksjeklassen-grp-3446 gruppeid="3446">
                <AksjekapitalInnbetaltFjoraret-datadef-8020 orid="8020">0</AksjekapitalInnbetaltFjoraret-datadef-8020>
                <AksjekapitalInnbetalt-datadef-5867 orid="5867">#{s.aksjekapital}</AksjekapitalInnbetalt-datadef-5867>
            </InnbetaltAksjekapitalIDenneAksjeklassen-grp-3446>
            <InnbetaltOverkursIDenneAksjeklassen-grp-3448 gruppeid="3448">
                <AksjeOverkursISINAksjetypeFjoraret-datadef-17662 orid="17662">0</AksjeOverkursISINAksjetypeFjoraret-datadef-17662>
                <AksjeOverkursISINAksjetype-datadef-17661 orid="17661">0</AksjeOverkursISINAksjetype-datadef-17661>
            </InnbetaltOverkursIDenneAksjeklassen-grp-3448>
        </Selskapsopplysninger-grp-2589>
        <Utbytte-grp-3449 gruppeid="3449">
            <UtdeltSkatterettsligUtbytteILopetAvInntektsaret-grp-3451 gruppeid="3451"></UtdeltSkatterettsligUtbytteILopetAvInntektsaret-grp-3451>
        </Utbytte-grp-3449>
        <UtstedelseAvAksjerIfmStiftelseNyemisjonMv-grp-3452 gruppeid="3452">
            <AntallNyutstedteAksjer-grp-3453 gruppeid="3453">
                <AksjerNyutstedteStiftelseMvAntall-datadef-17668 orid="17668">#{total_aksjer}</AksjerNyutstedteStiftelseMvAntall-datadef-17668>
                <AksjerStiftelseMvAntall-datadef-17669 orid="17669">#{total_aksjer}</AksjerStiftelseMvAntall-datadef-17669>
                <AksjerNyutstedteStiftelseMvType-datadef-17670 orid="17670">N</AksjerNyutstedteStiftelseMvType-datadef-17670>
                <AksjerNyutstedteStiftelseMvTidspunkt-datadef-17671 orid="17671">#{stiftelsesdato}</AksjerNyutstedteStiftelseMvTidspunkt-datadef-17671>
                <AksjerNyutstedteStiftelseMvPalydende-datadef-23947 orid="23947">#{paalydende}</AksjerNyutstedteStiftelseMvPalydende-datadef-23947>
            </AntallNyutstedteAksjer-grp-3453>
        </UtstedelseAvAksjerIfmStiftelseNyemisjonMv-grp-3452>
        <UtstedelseAvAksjerIfmFondsemisjonSplittMv-grp-3454 gruppeid="3454">
            <NyutstedteAksjerOmfordeling-grp-3455 gruppeid="3455"></NyutstedteAksjerOmfordeling-grp-3455>
        </UtstedelseAvAksjerIfmFondsemisjonSplittMv-grp-3454>
        <SlettingAvAksjerIfmLikvidasjonPartiellLikvidasjonMv-grp-3456 gruppeid="3456">
            <SlettedeAksjerAvgang-grp-3457 gruppeid="3457"></SlettedeAksjerAvgang-grp-3457>
        </SlettingAvAksjerIfmLikvidasjonPartiellLikvidasjonMv-grp-3456>
        <SlettingAvAksjerIfmSpleisSkattefriFusjonFisjon-grp-3458 gruppeid="3458">
            <SlettedeAksjerOmfordeling-grp-3459 gruppeid="3459"></SlettedeAksjerOmfordeling-grp-3459>
        </SlettingAvAksjerIfmSpleisSkattefriFusjonFisjon-grp-3458>
        <EndringerIAksjekapitalOgOverkurs-grp-3460 gruppeid="3460">
            <NedsettelseAvInnbetaltOverkursMedTilbakebetalingTilAksjonarene-grp-3461 gruppeid="3461"></NedsettelseAvInnbetaltOverkursMedTilbakebetalingTilAksjonarene-grp-3461>
            <ForhoyelseAvAKVedOkningAvPalydende-grp-3462 gruppeid="3462"></ForhoyelseAvAKVedOkningAvPalydende-grp-3462>
            <ForhoyelseAvAKVedOkningAvPalydende-grp-3463 gruppeid="3463"></ForhoyelseAvAKVedOkningAvPalydende-grp-3463>
            <NedsettelseAvInnbetaltOgFondsemittertAK-grp-3464 gruppeid="3464"></NedsettelseAvInnbetaltOgFondsemittertAK-grp-3464>
            <NedsettelseAKVedReduksjonAvPalydende-grp-3465 gruppeid="3465"></NedsettelseAKVedReduksjonAvPalydende-grp-3465>
            <NedsettelseAvAKVedReduksjonUtfisjonering-grp-3466 gruppeid="3466"></NedsettelseAvAKVedReduksjonUtfisjonering-grp-3466>
        </EndringerIAksjekapitalOgOverkurs-grp-3460>
    </Skjema>
    """
    |> String.trim()
  end

  @doc """
  Generates RF-1086-U Underskjema XML for a single shareholder.

  Contains shareholder identification, holdings, and acquisition transaction.
  Validates against: aksjonaerregisteroppgaveUnderskjema.xsd

  Returns the XML as a string.
  """
  def generer_underskjema_xml(%Aksjonaer{} = aksjonaer, %Aksjonaerregisteroppgave{} = oppgave) do
    s = oppgave.selskap
    aar = oppgave.regnskapsaar
    anskaffelsesverdi = aksjonaer.innbetalt_kapital_per_aksje * aksjonaer.antall_aksjer
    stiftelsesdato = "#{s.stiftelsesaar}-01-01T00:00:00"

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <Skjema skjemanummer="923" spesifikasjonsnummer="12232"
            blankettnummer="RF-1086-U" tittel="Aksjonærregisteroppgaven - underskjema"
            gruppeid="3983" etatid="974761076">
        <SelskapsOgAksjonaropplysninger-grp-3987 gruppeid="3987">
            <Selskapsidentifikasjon-grp-3986 gruppeid="3986">
                <EnhetOrganisasjonsnummer-datadef-18 orid="18">#{escape(s.org_nummer)}</EnhetOrganisasjonsnummer-datadef-18>
                <AksjeType-datadef-17659 orid="17659">01</AksjeType-datadef-17659>
                <Inntektsar-datadef-692 orid="692">#{aar}</Inntektsar-datadef-692>
            </Selskapsidentifikasjon-grp-3986>
            <NorskUtenlandskAksjonar-grp-3988 gruppeid="3988">
                #{shareholder_identification_xml(aksjonaer)}
                <Adresse-grp-7722 gruppeid="7722"></Adresse-grp-7722>
            </NorskUtenlandskAksjonar-grp-3988>
        </SelskapsOgAksjonaropplysninger-grp-3987>
        <AntallAksjerUtbytteOgTilbakebetalingAvTidligereInnbetaltKapit-grp-3990 gruppeid="3990">
            <AntallAksjerPerAksjonar-grp-3989 gruppeid="3989">
                <AksjerAntallFjoraret-datadef-29168 orid="29168">0</AksjerAntallFjoraret-datadef-29168>
                <AksjonarAksjerAntall-datadef-17741 orid="17741">#{aksjonaer.antall_aksjer}</AksjonarAksjerAntall-datadef-17741>
            </AntallAksjerPerAksjonar-grp-3989>
            <UtdeltUtbyttePerAksjonar-grp-3991 gruppeid="3991">
                <AutomatiskMotregningOnskerIkke-datadef-37159 orid="37159">0</AutomatiskMotregningOnskerIkke-datadef-37159>
            </UtdeltUtbyttePerAksjonar-grp-3991>
            <UtdeltUtbytteKildeskatt-grp-9347 gruppeid="9347"></UtdeltUtbytteKildeskatt-grp-9347>
            <TilbakebetalingAvTidligereInnbetaltKapital-grp-7633 gruppeid="7633">
                <TilbakebetalingAvTidligereInnbetaltKapital-grp-7865 gruppeid="7865"></TilbakebetalingAvTidligereInnbetaltKapital-grp-7865>
            </TilbakebetalingAvTidligereInnbetaltKapital-grp-7633>
        </AntallAksjerUtbytteOgTilbakebetalingAvTidligereInnbetaltKapit-grp-3990>
        <Transaksjoner-grp-3992 gruppeid="3992">
            <KjopArvGaveStiftelseNyemisjonMv-grp-3993 gruppeid="3993">
                <AntallAksjerITilgang-grp-3998 gruppeid="3998">
                    <AksjerKjopAntall-datadef-12153 orid="12153">#{aksjonaer.antall_aksjer}</AksjerKjopAntall-datadef-12153>
                    <AksjeErvervType-datadef-17745 orid="17745">N</AksjeErvervType-datadef-17745>
                    <AksjerErvervsdato-datadef-17746 orid="17746">#{stiftelsesdato}</AksjerErvervsdato-datadef-17746>
                    <AksjeAnskaffelsesverdi-datadef-17636 orid="17636">#{anskaffelsesverdi}</AksjeAnskaffelsesverdi-datadef-17636>
                </AntallAksjerITilgang-grp-3998>
            </KjopArvGaveStiftelseNyemisjonMv-grp-3993>
        </Transaksjoner-grp-3992>
        <FondsemisjonSplittSkattefriFusjonFisjonSammenslaingDelingAv-grp-3994 gruppeid="3994">
            <AntallAksjerITilgangIfmOmfordeling-grp-3999 gruppeid="3999"></AntallAksjerITilgangIfmOmfordeling-grp-3999>
        </FondsemisjonSplittSkattefriFusjonFisjonSammenslaingDelingAv-grp-3994>
        <SalgArvGaveLikvidasjonPartiellLikvidasjonMv-grp-3995 gruppeid="3995">
            <AksjerIAvgang-grp-4002 gruppeid="4002"></AksjerIAvgang-grp-4002>
        </SalgArvGaveLikvidasjonPartiellLikvidasjonMv-grp-3995>
        <SpleisSkattefriFusjonOgSkattefriFisjon-grp-3996 gruppeid="3996">
            <AntallAksjerIAvgangVedOmfordeling-grp-4003 gruppeid="4003"></AntallAksjerIAvgangVedOmfordeling-grp-4003>
        </SpleisSkattefriFusjonOgSkattefriFisjon-grp-3996>
        <EndringerIAksjekapitalOgOverkurs-grp-3997 gruppeid="3997">
            <TilbakebetaltInnbetaltOgFondsemittertAKVedReduksjonAvPalydende-grp-4000 gruppeid="4000"></TilbakebetaltInnbetaltOgFondsemittertAKVedReduksjonAvPalydende-grp-4000>
            <TilbakebetaltTidligereInnbetaltOverkursForAksjen-grp-4001 gruppeid="4001"></TilbakebetaltTidligereInnbetaltOverkursForAksjen-grp-4001>
            <ForhoyelseAvInnbetaltAksjekapitalVedOkning-grp-4987 gruppeid="4987"></ForhoyelseAvInnbetaltAksjekapitalVedOkning-grp-4987>
            <ReduksjonInnbetaltAksjekapital-grp-9857 gruppeid="9857"></ReduksjonInnbetaltAksjekapital-grp-9857>
        </EndringerIAksjekapitalOgOverkurs-grp-3997>
    </Skjema>
    """
    |> String.trim()
  end

  @doc """
  Validates a shareholder register submission.

  Returns `:ok` or `{:error, reasons}` where reasons is a list of error strings.
  """
  def valider(%Aksjonaerregisteroppgave{} = oppgave) do
    errors = []

    errors =
      if Enum.empty?(oppgave.aksjonaerer) do
        ["Minst én aksjonær må være registrert." | errors]
      else
        errors
      end

    errors =
      if (oppgave.selskap.kontakt_epost || "") == "" do
        ["kontakt_epost mangler. Påkrevd av SKDs API." | errors]
      else
        errors
      end

    id_errors =
      oppgave.aksjonaerer
      |> Enum.filter(fn a -> not valid_shareholder_id?(a) end)
      |> Enum.map(fn a ->
        "Ugyldig identifikasjon for #{a.navn}: fødselsnummer må være 11 siffer, organisasjonsnummer må være 9 siffer."
      end)

    errors = id_errors ++ errors

    total_aksjer = Aksjonaerregisteroppgave.totalt_antall_aksjer(oppgave)

    errors =
      if total_aksjer <= 0 do
        ["Totalt antall aksjer må være større enn 0." | errors]
      else
        errors
      end

    if Enum.empty?(errors) do
      :ok
    else
      {:error, Enum.reverse(errors)}
    end
  end

  @doc """
  Validates a list of shareholders (legacy API).

  Supports both person shareholders (fodselsnummer - 11 digits) and
  company shareholders (organisasjonsnummer - 9 digits).

  Returns `:ok` or `{:error, reason}`.
  """
  def validate_shareholders([]), do: {:error, :no_shareholders}

  def validate_shareholders(shareholders) when is_list(shareholders) do
    total_shares = Enum.reduce(shareholders, 0, fn s, acc -> acc + s.antall_aksjer end)

    cond do
      total_shares <= 0 ->
        {:error, :invalid_total_shares}

      Enum.any?(shareholders, fn s -> not valid_shareholder_id?(s) end) ->
        {:error, :invalid_identification}

      true ->
        :ok
    end
  end

  # Validates shareholder has valid identification (either fnr or org.nr)
  defp valid_shareholder_id?(%{organisasjonsnummer: org}) when is_binary(org) and org != "" do
    org_clean = String.replace(org, " ", "")
    String.length(org_clean) == 9 and String.match?(org_clean, ~r/^\d+$/)
  end

  defp valid_shareholder_id?(%{fodselsnummer: fnr}) when is_binary(fnr) and fnr != "" do
    fnr_clean = String.replace(fnr, " ", "")
    String.length(fnr_clean) == 11 and String.match?(fnr_clean, ~r/^\d+$/)
  end

  defp valid_shareholder_id?(_), do: false

  # Generates the appropriate identification XML element based on shareholder type
  defp shareholder_identification_xml(%{organisasjonsnummer: org})
       when is_binary(org) and org != "" do
    "<AksjonarOrganisasjonsnummer-datadef-7597 orid=\"7597\">#{escape(org)}</AksjonarOrganisasjonsnummer-datadef-7597>"
  end

  defp shareholder_identification_xml(%{fodselsnummer: fnr})
       when is_binary(fnr) and fnr != "" do
    "<AksjonarFodselsnummer-datadef-1156 orid=\"1156\">#{escape(fnr)}</AksjonarFodselsnummer-datadef-1156>"
  end

  defp shareholder_identification_xml(_), do: ""

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
