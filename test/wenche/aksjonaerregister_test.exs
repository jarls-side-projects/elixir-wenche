defmodule Wenche.AksjonaerregisterTest do
  use ExUnit.Case, async: true

  alias Wenche.Aksjonaerregister
  alias Wenche.Models.{Aksjonaer, Aksjonaerregisteroppgave, Selskap, Tilgang, Utstedelse}

  def sample_selskap do
    %Selskap{
      navn: "Aksje AS",
      org_nummer: "912345678",
      daglig_leder: "Ola Nordmann",
      styreleder: "Kari Nordmann",
      forretningsadresse: "Storgata 1, 0001 Oslo",
      stiftelsesaar: 2024,
      aksjekapital: 30_000,
      kontakt_epost: "post@aksje.no",
      utstedelser: [
        %Utstedelse{
          antall: 100,
          ervervstype: "N",
          dato: "2024-01-01T00:00:00",
          paalydende: 300
        }
      ]
    }
  end

  def sample_aksjonaer do
    %Aksjonaer{
      fodselsnummer: "12345678901",
      navn: "Ola Nordmann",
      antall_aksjer: 100,
      aksjeklasse: "A",
      utbytte_utbetalt: 0,
      antall_aksjer_fjoraret: 0,
      tilganger: [
        %Tilgang{
          ervervstype: "N",
          ervervsdato: "2024-01-01T00:00:00",
          antall: 100,
          anskaffelsesverdi: 30_000
        }
      ]
    }
  end

  def sample_company_aksjonaer do
    %Aksjonaer{
      organisasjonsnummer: "987654321",
      navn: "Holding AS",
      antall_aksjer: 50,
      aksjeklasse: "A",
      utbytte_utbetalt: 0,
      antall_aksjer_fjoraret: 0,
      tilganger: [
        %Tilgang{
          ervervstype: "N",
          ervervsdato: "2024-01-01T00:00:00",
          antall: 50,
          anskaffelsesverdi: 15_000
        }
      ]
    }
  end

  def sample_oppgave do
    %Aksjonaerregisteroppgave{
      selskap: sample_selskap(),
      regnskapsaar: 2024,
      aksjonaerer: [sample_aksjonaer()]
    }
  end

  # ---------------------------------------------------------------------------
  # Hovedskjema — XML structure
  # ---------------------------------------------------------------------------

  describe "generer_hovedskjema_xml/1" do
    test "generates valid XML" do
      xml = Aksjonaerregister.generer_hovedskjema_xml(sample_oppgave())
      assert xml =~ "<?xml version="
      assert xml =~ "<Skjema"
      assert xml =~ "</Skjema>"
    end

    test "has correct skjemanummer and blankettnummer" do
      xml = Aksjonaerregister.generer_hovedskjema_xml(sample_oppgave())
      assert xml =~ ~s(skjemanummer="890")
      assert xml =~ ~s(blankettnummer="RF-1086")
    end

    test "includes org number" do
      xml = Aksjonaerregister.generer_hovedskjema_xml(sample_oppgave())

      assert xml =~
               "<EnhetOrganisasjonsnummer-datadef-18 orid=\"18\">912345678</EnhetOrganisasjonsnummer-datadef-18>"
    end

    test "includes income year" do
      xml = Aksjonaerregister.generer_hovedskjema_xml(sample_oppgave())
      assert xml =~ "<Inntektsar-datadef-692 orid=\"692\">2024</Inntektsar-datadef-692>"
    end

    test "includes aksjekapital" do
      xml = Aksjonaerregister.generer_hovedskjema_xml(sample_oppgave())
      assert xml =~ "<Aksjekapital-datadef-87 orid=\"87\">30000</Aksjekapital-datadef-87>"
    end

    test "includes total number of shares" do
      xml = Aksjonaerregister.generer_hovedskjema_xml(sample_oppgave())

      assert xml =~
               "<AksjerMvAntall-datadef-29167 orid=\"29167\">100</AksjerMvAntall-datadef-29167>"
    end

    test "calculates pålydende per aksje" do
      xml = Aksjonaerregister.generer_hovedskjema_xml(sample_oppgave())
      # 30000 / 100 = 300
      assert xml =~
               "<AksjeMvPalydende-datadef-23945 orid=\"23945\">300</AksjeMvPalydende-datadef-23945>"
    end

    test "includes kontakt epost" do
      xml = Aksjonaerregister.generer_hovedskjema_xml(sample_oppgave())

      assert xml =~
               "<KontaktpersonSkjemaEPost-datadef-30533 orid=\"30533\">post@aksje.no</KontaktpersonSkjemaEPost-datadef-30533>"
    end
  end

  # ---------------------------------------------------------------------------
  # Underskjema — XML structure
  # ---------------------------------------------------------------------------

  describe "generer_underskjema_xml/2" do
    test "generates valid XML" do
      oppgave = sample_oppgave()
      aksjonaer = hd(oppgave.aksjonaerer)
      xml = Aksjonaerregister.generer_underskjema_xml(aksjonaer, oppgave)
      assert xml =~ "<?xml version="
      assert xml =~ "<Skjema"
      assert xml =~ "</Skjema>"
    end

    test "has correct skjemanummer and blankettnummer" do
      oppgave = sample_oppgave()
      aksjonaer = hd(oppgave.aksjonaerer)
      xml = Aksjonaerregister.generer_underskjema_xml(aksjonaer, oppgave)
      assert xml =~ ~s(skjemanummer="923")
      assert xml =~ ~s(blankettnummer="RF-1086-U")
    end

    test "includes fødselsnummer" do
      oppgave = sample_oppgave()
      aksjonaer = hd(oppgave.aksjonaerer)
      xml = Aksjonaerregister.generer_underskjema_xml(aksjonaer, oppgave)

      assert xml =~
               "<AksjonarFodselsnummer-datadef-1156 orid=\"1156\">12345678901</AksjonarFodselsnummer-datadef-1156>"
    end

    test "includes number of shares" do
      oppgave = sample_oppgave()
      aksjonaer = hd(oppgave.aksjonaerer)
      xml = Aksjonaerregister.generer_underskjema_xml(aksjonaer, oppgave)

      assert xml =~
               "<AksjonarAksjerAntall-datadef-17741 orid=\"17741\">100</AksjonarAksjerAntall-datadef-17741>"
    end

    test "calculates anskaffelsesverdi" do
      oppgave = sample_oppgave()
      aksjonaer = hd(oppgave.aksjonaerer)
      xml = Aksjonaerregister.generer_underskjema_xml(aksjonaer, oppgave)
      # 300 * 100 = 30000
      assert xml =~
               "<AksjeAnskaffelsesverdi-datadef-17636 orid=\"17636\">30000</AksjeAnskaffelsesverdi-datadef-17636>"
    end

    test "includes org number" do
      oppgave = sample_oppgave()
      aksjonaer = hd(oppgave.aksjonaerer)
      xml = Aksjonaerregister.generer_underskjema_xml(aksjonaer, oppgave)

      assert xml =~
               "<EnhetOrganisasjonsnummer-datadef-18 orid=\"18\">912345678</EnhetOrganisasjonsnummer-datadef-18>"
    end

    test "includes organisasjonsnummer for company shareholder" do
      oppgave = sample_oppgave()
      company_aksjonaer = sample_company_aksjonaer()
      xml = Aksjonaerregister.generer_underskjema_xml(company_aksjonaer, oppgave)

      assert xml =~
               "<AksjonarOrganisasjonsnummer-datadef-7597 orid=\"7597\">987654321</AksjonarOrganisasjonsnummer-datadef-7597>"

      refute xml =~ "AksjonarFodselsnummer-datadef-1156"
    end

    test "includes fødselsnummer for person shareholder, not organisasjonsnummer" do
      oppgave = sample_oppgave()
      aksjonaer = hd(oppgave.aksjonaerer)
      xml = Aksjonaerregister.generer_underskjema_xml(aksjonaer, oppgave)

      assert xml =~
               "<AksjonarFodselsnummer-datadef-1156 orid=\"1156\">12345678901</AksjonarFodselsnummer-datadef-1156>"

      refute xml =~ "AksjonarOrganisasjonsnummer-datadef-7597"
    end
  end

  # ---------------------------------------------------------------------------
  # Transaction mapping — dates, opening balances, acquisitions
  # ---------------------------------------------------------------------------

  describe "transaction mapping" do
    test "underskjema uses the real acquisition date, not the founding year" do
      # tilgang dated mid-2024, founding year 2024 — date must come from the
      # tilgang verbatim (regression for avvik MTRA_004).
      aksjonaer = %{
        sample_aksjonaer()
        | tilganger: [
            %Tilgang{
              ervervstype: "N",
              ervervsdato: "2024-06-15T00:00:00",
              antall: 100,
              anskaffelsesverdi: 30_000
            }
          ]
      }

      xml = Aksjonaerregister.generer_underskjema_xml(aksjonaer, sample_oppgave())

      assert xml =~
               "<AksjerErvervsdato-datadef-17746 orid=\"17746\">2024-06-15T00:00:00</AksjerErvervsdato-datadef-17746>"
    end

    test "underskjema anskaffelsesverdi is the tilgang value, not zero" do
      # Per-shareholder paid-in capital (post 23) must be non-zero so it can
      # reconcile with the company total (post 9) — regression for MAKH_053.
      xml = Aksjonaerregister.generer_underskjema_xml(sample_aksjonaer(), sample_oppgave())

      assert xml =~
               "<AksjeAnskaffelsesverdi-datadef-17636 orid=\"17636\">30000</AksjeAnskaffelsesverdi-datadef-17636>"

      refute xml =~ "<AksjeAnskaffelsesverdi-datadef-17636 orid=\"17636\">0<"
    end

    test "holdings entirely from a prior year go to Fjoraret with no current-year tilgang" do
      aksjonaer = %{
        sample_aksjonaer()
        | antall_aksjer: 100,
          antall_aksjer_fjoraret: 100,
          tilganger: []
      }

      xml = Aksjonaerregister.generer_underskjema_xml(aksjonaer, sample_oppgave())

      assert xml =~
               "<AksjerAntallFjoraret-datadef-29168 orid=\"29168\">100</AksjerAntallFjoraret-datadef-29168>"

      # No acquisition event when nothing was acquired during the income year.
      refute xml =~ "AntallAksjerITilgang-grp-3998"
    end

    test "multiple acquisitions in the income year each emit their own tilgang block" do
      aksjonaer = %{
        sample_aksjonaer()
        | antall_aksjer: 150,
          antall_aksjer_fjoraret: 0,
          tilganger: [
            %Tilgang{
              ervervstype: "N",
              ervervsdato: "2024-01-01T00:00:00",
              antall: 100,
              anskaffelsesverdi: 30_000
            },
            %Tilgang{
              ervervstype: "N",
              ervervsdato: "2024-09-01T00:00:00",
              antall: 50,
              anskaffelsesverdi: 50_000
            }
          ]
      }

      oppgave = %{sample_oppgave() | aksjonaerer: [aksjonaer]}
      xml = Aksjonaerregister.generer_underskjema_xml(aksjonaer, oppgave)

      tilgang_count =
        xml |> String.split("<AntallAksjerITilgang-grp-3998") |> length() |> Kernel.-(1)

      assert tilgang_count == 2
      assert xml =~ "2024-01-01T00:00:00"
      assert xml =~ "2024-09-01T00:00:00"
    end

    test "hovedskjema issuance uses the real issuance date and opening balances" do
      selskap = %{
        sample_selskap()
        | aksjekapital_fjoraret: 0,
          antall_aksjer_fjoraret: 0,
          utstedelser: [
            %Utstedelse{
              antall: 100,
              ervervstype: "N",
              dato: "2024-06-15T00:00:00",
              paalydende: 300
            }
          ]
      }

      xml = Aksjonaerregister.generer_hovedskjema_xml(%{sample_oppgave() | selskap: selskap})

      assert xml =~
               "<AksjerNyutstedteStiftelseMvTidspunkt-datadef-17671 orid=\"17671\">2024-06-15T00:00:00</AksjerNyutstedteStiftelseMvTidspunkt-datadef-17671>"
    end
  end

  # ---------------------------------------------------------------------------
  # Validation
  # ---------------------------------------------------------------------------

  describe "valider/1" do
    test "returns :ok for valid oppgave" do
      assert :ok = Aksjonaerregister.valider(sample_oppgave())
    end

    test "returns error for empty aksjonaerer list" do
      oppgave = %Aksjonaerregisteroppgave{
        selskap: sample_selskap(),
        regnskapsaar: 2024,
        aksjonaerer: []
      }

      assert {:error, errors} = Aksjonaerregister.valider(oppgave)
      assert Enum.any?(errors, &(&1 =~ "Minst én aksjonær"))
    end

    test "returns error for missing kontakt_epost" do
      selskap = %{sample_selskap() | kontakt_epost: ""}

      oppgave = %Aksjonaerregisteroppgave{
        selskap: selskap,
        regnskapsaar: 2024,
        aksjonaerer: [sample_aksjonaer()]
      }

      assert {:error, errors} = Aksjonaerregister.valider(oppgave)
      assert Enum.any?(errors, &(&1 =~ "kontakt_epost"))
    end

    test "returns error for invalid fodselsnummer" do
      oppgave = %Aksjonaerregisteroppgave{
        selskap: sample_selskap(),
        regnskapsaar: 2024,
        aksjonaerer: [
          %Aksjonaer{
            fodselsnummer: "1234",
            navn: "Ola Nordmann",
            antall_aksjer: 100,
            aksjeklasse: "A",
            utbytte_utbetalt: 0
          }
        ]
      }

      assert {:error, errors} = Aksjonaerregister.valider(oppgave)
      assert Enum.any?(errors, &(&1 =~ "Ugyldig identifikasjon"))
    end

    test "returns error when total shares is zero" do
      oppgave = %Aksjonaerregisteroppgave{
        selskap: sample_selskap(),
        regnskapsaar: 2024,
        aksjonaerer: [
          %Aksjonaer{
            fodselsnummer: "12345678901",
            navn: "Ola Nordmann",
            antall_aksjer: 0,
            aksjeklasse: "A",
            utbytte_utbetalt: 0
          }
        ]
      }

      assert {:error, errors} = Aksjonaerregister.valider(oppgave)
      assert Enum.any?(errors, &(&1 =~ "Totalt antall aksjer må være større enn 0"))
    end

    test "returns :ok for valid company shareholder" do
      oppgave = %Aksjonaerregisteroppgave{
        selskap: sample_selskap(),
        regnskapsaar: 2024,
        aksjonaerer: [sample_company_aksjonaer()]
      }

      assert :ok = Aksjonaerregister.valider(oppgave)
    end

    test "returns :ok for mixed person and company shareholders" do
      oppgave = %Aksjonaerregisteroppgave{
        selskap: sample_selskap(),
        regnskapsaar: 2024,
        aksjonaerer: [sample_aksjonaer(), sample_company_aksjonaer()]
      }

      assert :ok = Aksjonaerregister.valider(oppgave)
    end

    test "returns error for invalid organisasjonsnummer" do
      oppgave = %Aksjonaerregisteroppgave{
        selskap: sample_selskap(),
        regnskapsaar: 2024,
        aksjonaerer: [
          %Aksjonaer{
            organisasjonsnummer: "1234",
            navn: "Invalid Company AS",
            antall_aksjer: 100,
            aksjeklasse: "A",
            utbytte_utbetalt: 0
          }
        ]
      }

      assert {:error, errors} = Aksjonaerregister.valider(oppgave)
      assert Enum.any?(errors, &(&1 =~ "Ugyldig identifikasjon"))
    end

    test "returns error for shareholder with neither fnr nor org.nr" do
      oppgave = %Aksjonaerregisteroppgave{
        selskap: sample_selskap(),
        regnskapsaar: 2024,
        aksjonaerer: [
          %Aksjonaer{
            navn: "No ID Person",
            antall_aksjer: 100,
            aksjeklasse: "A",
            utbytte_utbetalt: 0
          }
        ]
      }

      assert {:error, errors} = Aksjonaerregister.valider(oppgave)
      assert Enum.any?(errors, &(&1 =~ "Ugyldig identifikasjon"))
    end
  end

  # Legacy API tests
  describe "validate_shareholders/1 (legacy)" do
    test "returns :ok for valid person shareholders" do
      shareholders = [
        %{fodselsnummer: "12345678901", antall_aksjer: 100},
        %{fodselsnummer: "98765432101", antall_aksjer: 50}
      ]

      assert :ok = Aksjonaerregister.validate_shareholders(shareholders)
    end

    test "returns :ok for valid company shareholders" do
      shareholders = [
        %{organisasjonsnummer: "987654321", antall_aksjer: 100},
        %{organisasjonsnummer: "123456789", antall_aksjer: 50}
      ]

      assert :ok = Aksjonaerregister.validate_shareholders(shareholders)
    end

    test "returns :ok for mixed person and company shareholders" do
      shareholders = [
        %{fodselsnummer: "12345678901", antall_aksjer: 100},
        %{organisasjonsnummer: "987654321", antall_aksjer: 50}
      ]

      assert :ok = Aksjonaerregister.validate_shareholders(shareholders)
    end

    test "returns error for empty list" do
      assert {:error, :no_shareholders} = Aksjonaerregister.validate_shareholders([])
    end

    test "returns error for invalid fodselsnummer" do
      shareholders = [%{fodselsnummer: "1234", antall_aksjer: 100}]

      assert {:error, :invalid_identification} =
               Aksjonaerregister.validate_shareholders(shareholders)
    end

    test "returns error for invalid organisasjonsnummer" do
      shareholders = [%{organisasjonsnummer: "1234", antall_aksjer: 100}]

      assert {:error, :invalid_identification} =
               Aksjonaerregister.validate_shareholders(shareholders)
    end

    test "returns error when total shares is zero" do
      shareholders = [%{fodselsnummer: "12345678901", antall_aksjer: 0}]

      assert {:error, :invalid_total_shares} =
               Aksjonaerregister.validate_shareholders(shareholders)
    end
  end

  # ---------------------------------------------------------------------------
  # XSD validation — generated XML must conform to the official RF-1086 schemas
  # Skatteetaten's aksjonærregister API validates against. XSDs vendored at
  # priv/xsd/skatteetaten (see NOTICE). Requires xmllint on PATH.
  #
  # NB: the XSDs only check structure/format. The cross-document rule that the
  # company's paid-in capital (hovedskjema) equals the sum across aksjonærer
  # (underskjema), and that acquisition dates fall within the income year, are
  # server-side business rules (avvik MAKH_053 / MTRA_004) the XSD cannot
  # express — so a payload passing here can still be rejected on submission.
  # ---------------------------------------------------------------------------
  describe "XSD validation (requires xmllint; XSDs vendored at priv/xsd/skatteetaten)" do
    @xsd_dir Path.join(:code.priv_dir(:wenche), "xsd/skatteetaten")

    test "hovedskjema validates against aksjonaerregisteroppgaveHovedskjema.xsd" do
      xml = Aksjonaerregister.generer_hovedskjema_xml(sample_oppgave())
      assert_xml_valid!(xml, "#{@xsd_dir}/aksjonaerregisteroppgaveHovedskjema.xsd")
    end

    test "underskjema for a person aksjonær validates against the underskjema XSD" do
      xml = Aksjonaerregister.generer_underskjema_xml(sample_aksjonaer(), sample_oppgave())
      assert_xml_valid!(xml, "#{@xsd_dir}/aksjonaerregisteroppgaveUnderskjema.xsd")
    end

    test "underskjema for a company aksjonær validates against the underskjema XSD" do
      oppgave = %{sample_oppgave() | aksjonaerer: [sample_company_aksjonaer()]}
      xml = Aksjonaerregister.generer_underskjema_xml(sample_company_aksjonaer(), oppgave)
      assert_xml_valid!(xml, "#{@xsd_dir}/aksjonaerregisteroppgaveUnderskjema.xsd")
    end

    test "underskjema with only an opening balance (no tilgang) validates" do
      aksjonaer = %{sample_aksjonaer() | antall_aksjer_fjoraret: 100, tilganger: []}
      xml = Aksjonaerregister.generer_underskjema_xml(aksjonaer, sample_oppgave())
      assert_xml_valid!(xml, "#{@xsd_dir}/aksjonaerregisteroppgaveUnderskjema.xsd")
    end

    defp assert_xml_valid!(xml, schema_path) do
      unless File.exists?(schema_path), do: flunk("Schema not found: #{schema_path}")

      path =
        Path.join(System.tmp_dir!(), "wenche_akv_xsd_#{System.unique_integer([:positive])}.xml")

      File.write!(path, xml)

      {output, status} =
        System.cmd("xmllint", ["--schema", schema_path, path, "--noout"], stderr_to_stdout: true)

      File.rm(path)

      unless status == 0 do
        flunk("XSD validation failed for #{schema_path}:\n#{output}\n\nXML:\n#{xml}")
      end
    end
  end
end
