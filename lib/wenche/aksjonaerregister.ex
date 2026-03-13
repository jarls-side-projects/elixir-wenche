defmodule Wenche.Aksjonaerregister do
  @moduledoc """
  RF-1086 (Aksjonærregisteroppgave) XML generation and submission.

  Ported from `wenche/aksjonaerregister.py` in the original Python Wenche project.

  The shareholder register report is filed annually by January 31st to the
  Norwegian Tax Authority via Altinn.
  """

  alias Wenche.Models.{Aksjonaerregisteroppgave, Aksjonaer}

  @doc """
  Generates RF-1086 XML message based on the Tax Authority's specification.

  Returns the XML as a string.
  """
  def generer_xml(%Aksjonaerregisteroppgave{} = oppgave) do
    total_aksjer = Aksjonaerregisteroppgave.totalt_antall_aksjer(oppgave)

    aksjonaer_xml =
      oppgave.aksjonaerer
      |> Enum.map(&aksjonaer_element/1)
      |> Enum.join("\n")

    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <Skjema xmlns="urn:ske:fastsetting:formueinntekt:aksjerekopp:v2"
            skjemanummer="RF-1086"
            innsendingstype="ordinaer">
      <Innsender>
        <Organisasjonsnummer>#{escape(oppgave.selskap.org_nummer)}</Organisasjonsnummer>
        <Navn>#{escape(oppgave.selskap.navn)}</Navn>
      </Innsender>
      <Inntektsaar>#{oppgave.regnskapsaar}</Inntektsaar>
      <Selskap>
        <Organisasjonsnummer>#{escape(oppgave.selskap.org_nummer)}</Organisasjonsnummer>
        <Navn>#{escape(oppgave.selskap.navn)}</Navn>
        <AntallAksjer>#{total_aksjer}</AntallAksjer>
        <Aksjekapital>#{oppgave.selskap.aksjekapital}</Aksjekapital>
      </Selskap>
    #{aksjonaer_xml}
    </Skjema>
    """

    String.trim(xml)
  end

  defp aksjonaer_element(%Aksjonaer{} = a) do
    utbytte_section =
      if (a.utbytte_utbetalt || 0) > 0 do
        """
            <Utbytte>
              <UtbytteBelop>#{a.utbytte_utbetalt}</UtbytteBelop>
            </Utbytte>
        """
      else
        ""
      end

    """
      <Aksjonaer>
        <Fodselsnummer>#{escape(a.fodselsnummer)}</Fodselsnummer>
        <Navn>#{escape(a.navn)}</Navn>
        <Beholdning>
          <Aksjeklasse>#{escape(a.aksjeklasse)}</Aksjeklasse>
          <AntallAksjerUltimo>#{a.antall_aksjer}</AntallAksjerUltimo>
          <InnbetaltKapitalPerAksje>#{a.innbetalt_kapital_per_aksje}</InnbetaltKapitalPerAksje>
        </Beholdning>
    #{utbytte_section}  </Aksjonaer>
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

    fnr_errors =
      oppgave.aksjonaerer
      |> Enum.filter(fn a ->
        fnr = String.replace(a.fodselsnummer, " ", "")
        String.length(fnr) != 11 or not String.match?(fnr, ~r/^\d+$/)
      end)
      |> Enum.map(fn a -> "Ugyldig fødselsnummer for #{a.navn}: må være 11 siffer." end)

    errors = fnr_errors ++ errors

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

  Returns `:ok` or `{:error, reason}`.
  """
  def validate_shareholders([]), do: {:error, :no_shareholders}

  def validate_shareholders(shareholders) when is_list(shareholders) do
    total_shares = Enum.reduce(shareholders, 0, fn s, acc -> acc + s.antall_aksjer end)

    cond do
      total_shares <= 0 ->
        {:error, :invalid_total_shares}

      Enum.any?(shareholders, fn s ->
        fnr = s.fodselsnummer |> to_string() |> String.replace(" ", "")
        not Regex.match?(~r/^\d{11}$/, fnr)
      end) ->
        {:error, :invalid_fodselsnummer}

      true ->
        :ok
    end
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
