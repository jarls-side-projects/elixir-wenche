defmodule Wenche.Aarsregnskap do
  @moduledoc """
  Annual accounts submission to Brønnøysundregistrene via Altinn 3.

  Ported from `wenche/aarsregnskap.py` in the original Python Wenche project.

  Handles config reading, validation, and submission of annual accounts.
  """

  alias Wenche.Models.{
    Aarsregnskap,
    Selskap,
    Resultatregnskap,
    Balanse,
    Driftsinntekter,
    Driftskostnader,
    Finansposter,
    Eiendeler,
    Anleggsmidler,
    Omloepmidler,
    EgenkapitalOgGjeld,
    Egenkapital,
    LangsiktigGjeld,
    KortsiktigGjeld,
    Noter,
    LaanTilNaerstaaende
  }

  alias Wenche.{AltinnClient, BrgXml}

  @doc """
  Reads a config.yaml file and returns an Aarsregnskap struct.

  Returns `{:ok, aarsregnskap}` or `{:error, reason}`.
  """
  def les_config(config_fil) do
    with {:ok, content} <- File.read(config_fil),
         {:ok, cfg} <- YamlElixir.read_from_string(content) do
      {:ok, parse_config(cfg)}
    end
  end

  @doc """
  Validates the accounts and returns a list of error messages.

  Empty list means OK.
  """
  def valider(%Aarsregnskap{} = regnskap) do
    errors = []

    errors =
      if not Balanse.er_i_balanse?(regnskap.balanse) do
        diff = Balanse.differanse(regnskap.balanse)

        [
          "Balansen går ikke opp: eiendeler og egenkapital+gjeld avviker med #{diff} NOK."
          | errors
        ]
      else
        errors
      end

    org = String.replace(regnskap.selskap.org_nummer, " ", "")

    errors =
      if String.length(org) != 9 do
        ["Organisasjonsnummeret må være 9 siffer." | errors]
      else
        errors
      end

    noter = regnskap.noter

    errors =
      if noter.antall_ansatte == 0 and
           regnskap.resultatregnskap.driftskostnader.loennskostnader > 0 do
        ["Advarsel: Lønnskostnader > 0 men antall ansatte er 0 i noter." | errors]
      else
        errors
      end

    errors =
      if regnskap.balanse.egenkapital_og_gjeld.langsiktig_gjeld.laan_fra_aksjonaer > 0 and
           noter.laan_til_naerstaaende == [] do
        [
          "Advarsel: Lån fra aksjonær i balansen men ingen lån til nærstående i noter (§7-45)."
          | errors
        ]
      else
        errors
      end

    Enum.reverse(errors)
  end

  @doc """
  Submits the annual accounts to Brønnøysundregistrene via Altinn.

  ## Options

  - `:dry_run` — if true, writes XML files locally without sending to Altinn (default: false)

  Returns `{:ok, inbox_url}` or `{:error, reason}`.
  """
  def send_inn(%Aarsregnskap{} = regnskap, %AltinnClient{} = client, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)

    errors = valider(regnskap)

    if errors != [] do
      {:error, {:validation_failed, errors}}
    else
      hovedskjema = BrgXml.generer_hovedskjema(regnskap)
      underskjema = BrgXml.generer_underskjema(regnskap)
      org = regnskap.selskap.org_nummer
      aar = regnskap.regnskapsaar

      if dry_run do
        hoved_fil = "aarsregnskap_#{aar}_#{org}_hovedskjema.xml"
        under_fil = "aarsregnskap_#{aar}_#{org}_underskjema.xml"
        File.write!(hoved_fil, hovedskjema)
        File.write!(under_fil, underskjema)

        {:ok, {:dry_run, hoved_fil, under_fil}}
      else
        with {:ok, instans} <- AltinnClient.opprett_instans(client, "aarsregnskap", org),
             {:ok, _} <-
               AltinnClient.oppdater_data_element(
                 client,
                 "aarsregnskap",
                 instans,
                 "Hovedskjema",
                 hovedskjema,
                 "application/xml"
               ),
             {:ok, _} <-
               AltinnClient.oppdater_data_element(
                 client,
                 "aarsregnskap",
                 instans,
                 "Underskjema",
                 underskjema,
                 "application/xml"
               ),
             {:ok, inbox_url} <- AltinnClient.fullfoor_instans(client, "aarsregnskap", instans) do
          {:ok, inbox_url}
        end
      end
    end
  end

  # Private helpers

  defp parse_config(cfg) do
    s = cfg["selskap"]

    selskap = %Selskap{
      navn: s["navn"],
      org_nummer: to_string(s["org_nummer"]),
      daglig_leder: s["daglig_leder"],
      styreleder: s["styreleder"],
      forretningsadresse: s["forretningsadresse"],
      stiftelsesaar: s["stiftelsesaar"],
      aksjekapital: s["aksjekapital"]
    }

    resultat = les_resultat(cfg["resultatregnskap"])
    balanse = les_balanse(cfg["balanse"])

    fa = cfg["foregaaende_aar"] || %{}

    foregaaende_resultat =
      if fa["resultatregnskap"] do
        les_resultat(fa["resultatregnskap"])
      else
        %Resultatregnskap{}
      end

    foregaaende_balanse =
      if fa["balanse"] do
        les_balanse(fa["balanse"])
      else
        %Balanse{}
      end

    utbytte_utbetalt =
      (cfg["aksjonaerer"] || [])
      |> Enum.map(fn a -> a["utbytte_utbetalt"] || 0 end)
      |> Enum.sum()

    noter = les_noter(cfg["noter"] || %{})

    %Aarsregnskap{
      selskap: selskap,
      regnskapsaar: cfg["regnskapsaar"],
      resultatregnskap: resultat,
      balanse: balanse,
      foregaaende_aar_resultat: foregaaende_resultat,
      foregaaende_aar_balanse: foregaaende_balanse,
      utbytte_utbetalt: utbytte_utbetalt,
      noter: noter
    }
  end

  defp les_resultat(r) do
    di = r["driftsinntekter"] || %{}
    dk = r["driftskostnader"] || %{}
    fp = r["finansposter"] || %{}

    %Resultatregnskap{
      driftsinntekter: %Driftsinntekter{
        salgsinntekter: di["salgsinntekter"] || 0,
        andre_driftsinntekter: di["andre_driftsinntekter"] || 0
      },
      driftskostnader: %Driftskostnader{
        loennskostnader: dk["loennskostnader"] || 0,
        avskrivninger: dk["avskrivninger"] || 0,
        andre_driftskostnader: dk["andre_driftskostnader"] || 0
      },
      finansposter: %Finansposter{
        utbytte_fra_datterselskap: fp["utbytte_fra_datterselskap"] || 0,
        andre_finansinntekter: fp["andre_finansinntekter"] || 0,
        rentekostnader: fp["rentekostnader"] || 0,
        andre_finanskostnader: fp["andre_finanskostnader"] || 0
      }
    }
  end

  defp les_balanse(b) do
    ei = b["eiendeler"] || %{}
    am = ei["anleggsmidler"] || %{}
    om = ei["omloepmidler"] || %{}
    eog = b["egenkapital_og_gjeld"] || %{}
    ek = eog["egenkapital"] || %{}
    lg = eog["langsiktig_gjeld"] || %{}
    kg = eog["kortsiktig_gjeld"] || %{}

    %Balanse{
      eiendeler: %Eiendeler{
        anleggsmidler: %Anleggsmidler{
          aksjer_i_datterselskap: am["aksjer_i_datterselskap"] || 0,
          andre_aksjer: am["andre_aksjer"] || 0,
          langsiktige_fordringer: am["langsiktige_fordringer"] || 0
        },
        omloepmidler: %Omloepmidler{
          kortsiktige_fordringer: om["kortsiktige_fordringer"] || 0,
          bankinnskudd: om["bankinnskudd"] || 0
        }
      },
      egenkapital_og_gjeld: %EgenkapitalOgGjeld{
        egenkapital: %Egenkapital{
          aksjekapital: ek["aksjekapital"] || 0,
          overkursfond: ek["overkursfond"] || 0,
          annen_egenkapital: ek["annen_egenkapital"] || 0
        },
        langsiktig_gjeld: %LangsiktigGjeld{
          laan_fra_aksjonaer: lg["laan_fra_aksjonaer"] || 0,
          andre_langsiktige_laan: lg["andre_langsiktige_laan"] || 0
        },
        kortsiktig_gjeld: %KortsiktigGjeld{
          leverandoergjeld: kg["leverandoergjeld"] || 0,
          skyldige_offentlige_avgifter: kg["skyldige_offentlige_avgifter"] || 0,
          annen_kortsiktig_gjeld: kg["annen_kortsiktig_gjeld"] || 0
        }
      }
    }
  end

  defp les_noter(n) do
    laan =
      (n["laan_til_naerstaaende"] || [])
      |> Enum.map(fn l ->
        %LaanTilNaerstaaende{
          navn: l["navn"],
          rolle: l["rolle"],
          beloep: l["beloep"] || 0,
          rentesats: l["rentesats"],
          avdragsplan: l["avdragsplan"]
        }
      end)

    %Noter{
      antall_ansatte: n["antall_ansatte"] || 0,
      regnskapsprinsipper: n["regnskapsprinsipper"],
      laan_til_naerstaaende: laan,
      fortsatt_drift_usikkerhet: n["fortsatt_drift_usikkerhet"] || false,
      fortsatt_drift_beskrivelse: n["fortsatt_drift_beskrivelse"]
    }
  end
end
