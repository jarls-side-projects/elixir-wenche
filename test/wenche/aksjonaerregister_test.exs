defmodule Wenche.AksjonaerregisterTest do
  use ExUnit.Case, async: true

  alias Wenche.Aksjonaerregister
  alias Wenche.Models.{Aksjonaer, Aksjonaerregisteroppgave, Selskap}

  def sample_selskap do
    %Selskap{
      navn: "Aksje AS",
      org_nummer: "912345678",
      daglig_leder: "Ola Nordmann",
      styreleder: "Kari Nordmann",
      forretningsadresse: "Storgata 1, 0001 Oslo",
      stiftelsesaar: 2020,
      aksjekapital: 30_000,
      kontakt_epost: "post@aksje.no"
    }
  end

  def sample_aksjonaer do
    %Aksjonaer{
      fodselsnummer: "12345678901",
      navn: "Ola Nordmann",
      antall_aksjer: 100,
      aksjeklasse: "A",
      utbytte_utbetalt: 0,
      innbetalt_kapital_per_aksje: 300
    }
  end

  def sample_company_aksjonaer do
    %Aksjonaer{
      organisasjonsnummer: "987654321",
      navn: "Holding AS",
      antall_aksjer: 50,
      aksjeklasse: "A",
      utbytte_utbetalt: 0,
      innbetalt_kapital_per_aksje: 300
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
            utbytte_utbetalt: 0,
            innbetalt_kapital_per_aksje: 100
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
            utbytte_utbetalt: 0,
            innbetalt_kapital_per_aksje: 100
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
            utbytte_utbetalt: 0,
            innbetalt_kapital_per_aksje: 100
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
            utbytte_utbetalt: 0,
            innbetalt_kapital_per_aksje: 100
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
end
