defmodule Wenche.Noter do
  @moduledoc """
  Generates notes (noter) for annual accounts of small enterprises (små foretak).

  Norwegian accounting law (regnskapsloven §§ 7-35 to 7-46) requires specific
  notes. This module generates both structured XML for BRG underskjema and
  readable text for the iXBRL document.
  """

  alias Wenche.Models.{
    Aarsregnskap,
    Resultatregnskap,
    Egenkapital
  }

  # ---------------------------------------------------------------------------
  # Default templates
  # ---------------------------------------------------------------------------

  @doc """
  Returns default regnskapsprinsipper text for small holding companies.
  """
  def default_regnskapsprinsipper do
    """
    Årsregnskapet er satt opp i samsvar med regnskapsloven og god regnskapsskikk \
    for små foretak. Selskapet er klassifisert som lite foretak etter regnskapsloven § 1-6.\
    """
    |> String.trim()
  end

  # ---------------------------------------------------------------------------
  # Egenkapital note (§7-25 / NRS)
  # ---------------------------------------------------------------------------

  @doc """
  Generates the equity reconciliation note from IB to UB.

  Returns a list of text lines.
  """
  def egenkapital_note(%Aarsregnskap{} = regnskap) do
    aar = regnskap.regnskapsaar
    ek_ub = regnskap.balanse.egenkapital_og_gjeld.egenkapital
    aarsresultat = Resultatregnskap.aarsresultat(regnskap.resultatregnskap)

    har_fjoraar =
      regnskap.foregaaende_aar_balanse != nil and
        regnskap.foregaaende_aar_balanse.egenkapital_og_gjeld.egenkapital.aksjekapital != 0

    if har_fjoraar do
      ek_ib = regnskap.foregaaende_aar_balanse.egenkapital_og_gjeld.egenkapital
      delta_ak = ek_ub.aksjekapital - ek_ib.aksjekapital
      delta_ok = ek_ub.overkursfond - ek_ib.overkursfond
      forklart_aek = ek_ib.annen_egenkapital + aarsresultat - regnskap.utbytte_utbetalt
      andre_aek = ek_ub.annen_egenkapital - forklart_aek

      lines = [
        ek_rad(
          "EK 01.01.#{aar}",
          ek_ib.aksjekapital,
          ek_ib.overkursfond,
          ek_ib.annen_egenkapital
        ),
        ek_rad("Årsresultat", 0, 0, aarsresultat)
      ]

      lines =
        if regnskap.utbytte_utbetalt != 0 do
          lines ++ [ek_rad("Utbytte utbetalt", 0, 0, -regnskap.utbytte_utbetalt)]
        else
          lines
        end

      lines =
        if delta_ak != 0 or delta_ok != 0 or andre_aek != 0 do
          lines ++ [ek_rad("Andre endringer", delta_ak, delta_ok, andre_aek)]
        else
          lines
        end

      lines ++
        [
          ek_rad(
            "EK 31.12.#{aar}",
            ek_ub.aksjekapital,
            ek_ub.overkursfond,
            ek_ub.annen_egenkapital
          )
        ]
    else
      [
        ek_rad("EK 31.12.#{aar}", ek_ub.aksjekapital, ek_ub.overkursfond, ek_ub.annen_egenkapital)
      ]
    end
  end

  defp ek_rad(label, ak, ok, aek) do
    sum = ak + ok + aek
    {label, ak, ok, aek, sum}
  end

  # ---------------------------------------------------------------------------
  # BRG XML noter section
  # ---------------------------------------------------------------------------

  @doc """
  Generates the `<noter>` XML section for BRG underskjema.
  """
  def generer_noter_xml(%Aarsregnskap{} = regnskap) do
    noter = regnskap.noter
    ek_lines = egenkapital_note_xml(regnskap)

    """
        <noter>
          <noteAarsverkTjenestePensjon>
            <antallAarsverk orid="37467">#{noter.antall_ansatte}</antallAarsverk>
          </noteAarsverkTjenestePensjon>
    #{ek_lines}\
        </noter>
    """
    |> String.trim_trailing()
  end

  defp egenkapital_note_xml(%Aarsregnskap{} = regnskap) do
    rows = egenkapital_note(regnskap)

    har_fjoraar = length(rows) > 1

    if not har_fjoraar do
      ""
    else
      ek_ib = regnskap.foregaaende_aar_balanse.egenkapital_og_gjeld.egenkapital
      ek_ub = regnskap.balanse.egenkapital_og_gjeld.egenkapital
      aarsresultat = Resultatregnskap.aarsresultat(regnskap.resultatregnskap)

      utbytte_xml =
        if regnskap.utbytte_utbetalt != 0 do
          """
                <utbyttePaaVedtatt>
                  <aksjekapitalSelskapskapital orid="37515">0</aksjekapitalSelskapskapital>
                  <overkursfond orid="37516">0</overkursfond>
                  <annenEgenkapital orid="37517">#{-regnskap.utbytte_utbetalt}</annenEgenkapital>
                  <sumEgenkapital orid="37518">#{-regnskap.utbytte_utbetalt}</sumEgenkapital>
                </utbyttePaaVedtatt>
          """
        else
          ""
        end

      """
          <noteEgenkapital>
            <egenkapitalAapningsbalanse>
              <aksjekapitalSelskapskapital orid="37499">#{ek_ib.aksjekapital}</aksjekapitalSelskapskapital>
              <overkursfond orid="37500">#{ek_ib.overkursfond}</overkursfond>
              <annenEgenkapital orid="37501">#{ek_ib.annen_egenkapital}</annenEgenkapital>
              <sumEgenkapital orid="37502">#{Egenkapital.sum(ek_ib)}</sumEgenkapital>
            </egenkapitalAapningsbalanse>
            <aarsresultat>
              <aksjekapitalSelskapskapital orid="37507">0</aksjekapitalSelskapskapital>
              <overkursfond orid="37508">0</overkursfond>
              <annenEgenkapital orid="37509">#{aarsresultat}</annenEgenkapital>
              <sumEgenkapital orid="37510">#{aarsresultat}</sumEgenkapital>
            </aarsresultat>
      #{utbytte_xml}\
            <egenkapitalAvslutningsbalanse>
              <aksjekapitalSelskapskapital orid="37527">#{ek_ub.aksjekapital}</aksjekapitalSelskapskapital>
              <overkursfond orid="37528">#{ek_ub.overkursfond}</overkursfond>
              <annenEgenkapital orid="37529">#{ek_ub.annen_egenkapital}</annenEgenkapital>
              <sumEgenkapital orid="37530">#{Egenkapital.sum(ek_ub)}</sumEgenkapital>
            </egenkapitalAvslutningsbalanse>
          </noteEgenkapital>
      """
    end
  end

  # ---------------------------------------------------------------------------
  # iXBRL text notes
  # ---------------------------------------------------------------------------

  @doc """
  Generates readable note text for the iXBRL document.

  Returns a list of `{title, content}` tuples.
  """
  def generer_noter_tekst(%Aarsregnskap{} = regnskap) do
    noter = regnskap.noter

    notes = []

    # §7-35 Regnskapsprinsipper
    prinsipper = noter.regnskapsprinsipper || default_regnskapsprinsipper()
    notes = notes ++ [{"Regnskapsprinsipper", prinsipper}]

    # §7-43 Antall ansatte
    notes =
      notes ++
        [
          {"Antall ansatte",
           "Gjennomsnittlig antall ansatte i regnskapsåret: #{noter.antall_ansatte}."}
        ]

    # Egenkapital note
    ek_rows = egenkapital_note(regnskap)
    ek_text = format_egenkapital_text(ek_rows)
    notes = notes ++ [{"Egenkapital", ek_text}]

    # §7-42 Aksjer/aksjeeiere (for AS)
    aksje_text = "Aksjekapitalen består av #{div(regnskap.selskap.aksjekapital, 1)} aksjer."
    notes = notes ++ [{"Aksjer og aksjeeiere", aksje_text}]

    # §7-36 Konsern (if datterselskap)
    am = regnskap.balanse.eiendeler.anleggsmidler

    notes =
      if am.aksjer_i_datterselskap > 0 do
        konsern_text =
          "Selskapet har investering i datterselskap bokført til #{format_nok(am.aksjer_i_datterselskap)}."

        notes ++ [{"Konsern og tilknyttet selskap", konsern_text}]
      else
        notes
      end

    notes
    |> maybe_add_laan_note(noter)
    |> maybe_add_fortsatt_drift_note(noter)
  end

  defp maybe_add_laan_note(notes, %{laan_til_naerstaaende: []}) do
    notes ++
      [
        {"Lån og sikkerhetsstillelse til nærstående",
         "Det er ikke gitt lån eller stilt sikkerhet til fordel for nærstående parter."}
      ]
  end

  defp maybe_add_laan_note(notes, %{laan_til_naerstaaende: laan}) do
    lines =
      Enum.map(laan, fn l ->
        rente = if l.rentesats, do: " (rente: #{l.rentesats}%)", else: ""
        "#{l.navn} (#{l.rolle}): #{format_nok(l.beloep)}#{rente}"
      end)

    tekst = "Følgende lån er gitt til nærstående:\n" <> Enum.join(lines, "\n")
    notes ++ [{"Lån og sikkerhetsstillelse til nærstående", tekst}]
  end

  defp maybe_add_fortsatt_drift_note(notes, %{fortsatt_drift_usikkerhet: false}), do: notes

  defp maybe_add_fortsatt_drift_note(notes, %{fortsatt_drift_usikkerhet: true} = noter) do
    tekst =
      noter.fortsatt_drift_beskrivelse || "Det foreligger usikkerhet knyttet til fortsatt drift."

    notes ++ [{"Fortsatt drift", tekst}]
  end

  defp format_egenkapital_text(rows) do
    header =
      "#{pad("", 20)}#{pad("Aksjekapital", 14)}#{pad("Overkursfond", 14)}#{pad("Annen EK", 14)}#{pad("Sum", 14)}"

    body =
      Enum.map(rows, fn {label, ak, ok, aek, sum} ->
        "#{pad(label, 20)}#{pad(format_nok(ak), 14)}#{pad(format_nok(ok), 14)}#{pad(format_nok(aek), 14)}#{pad(format_nok(sum), 14)}"
      end)

    Enum.join([header | body], "\n") <> "\n(beløp i hele kroner, NOK)"
  end

  defp pad(str, width) do
    String.pad_trailing(str, width)
  end

  defp format_nok(amount) do
    # Simple NOK formatting
    if amount < 0 do
      "-#{format_nok(-amount)}"
    else
      amount
      |> Integer.to_string()
      |> String.reverse()
      |> String.replace(~r/.{3}(?=.)/, "\\0 ")
      |> String.reverse()
    end
  end
end
