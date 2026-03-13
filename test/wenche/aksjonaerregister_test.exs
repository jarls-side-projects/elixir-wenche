defmodule Wenche.AksjonaerregisterTest do
  use ExUnit.Case, async: true

  alias Wenche.Aksjonaerregister
  alias Wenche.Models.{Aksjonaerregisteroppgave, Aksjonaer, Selskap}

  def sample_selskap do
    %Selskap{
      navn: "Aksje AS",
      org_nummer: "912345678",
      daglig_leder: "Ola Nordmann",
      styreleder: "Kari Nordmann",
      forretningsadresse: "Storgata 1, 0001 Oslo",
      stiftelsesaar: 2020,
      aksjekapital: 30_000
    }
  end

  describe "generer_xml/1" do
    test "generates valid XML with shareholder data" do
      oppgave = %Aksjonaerregisteroppgave{
        selskap: sample_selskap(),
        regnskapsaar: 2025,
        aksjonaerer: [
          %Aksjonaer{
            fodselsnummer: "12345678901",
            navn: "Ola Nordmann",
            antall_aksjer: 100,
            aksjeklasse: "A",
            utbytte_utbetalt: 50_000,
            innbetalt_kapital_per_aksje: 100
          },
          %Aksjonaer{
            fodselsnummer: "98765432101",
            navn: "Kari Nordmann",
            antall_aksjer: 50,
            aksjeklasse: "A",
            utbytte_utbetalt: 25_000,
            innbetalt_kapital_per_aksje: 100
          }
        ]
      }

      xml = Aksjonaerregister.generer_xml(oppgave)

      assert xml =~ "RF-1086"
      assert xml =~ "2025"
      assert xml =~ "912345678"
      assert xml =~ "Aksje AS"
      assert xml =~ "Ola Nordmann"
      assert xml =~ "Kari Nordmann"
      assert xml =~ "12345678901"
      assert xml =~ "98765432101"
      # Total aksjer
      assert xml =~ "<AntallAksjer>150</AntallAksjer>"
    end

    test "includes utbytte when present" do
      oppgave = %Aksjonaerregisteroppgave{
        selskap: sample_selskap(),
        regnskapsaar: 2025,
        aksjonaerer: [
          %Aksjonaer{
            fodselsnummer: "12345678901",
            navn: "Ola Nordmann",
            antall_aksjer: 100,
            aksjeklasse: "A",
            utbytte_utbetalt: 50_000,
            innbetalt_kapital_per_aksje: 100
          }
        ]
      }

      xml = Aksjonaerregister.generer_xml(oppgave)

      assert xml =~ "<Utbytte>"
      assert xml =~ "<UtbytteBelop>50000</UtbytteBelop>"
    end

    test "omits utbytte when zero" do
      oppgave = %Aksjonaerregisteroppgave{
        selskap: sample_selskap(),
        regnskapsaar: 2025,
        aksjonaerer: [
          %Aksjonaer{
            fodselsnummer: "12345678901",
            navn: "Ola Nordmann",
            antall_aksjer: 100,
            aksjeklasse: "A",
            utbytte_utbetalt: 0,
            innbetalt_kapital_per_aksje: 100
          }
        ]
      }

      xml = Aksjonaerregister.generer_xml(oppgave)

      refute xml =~ "<Utbytte>"
    end
  end

  describe "valider/1" do
    test "returns :ok for valid oppgave" do
      oppgave = %Aksjonaerregisteroppgave{
        selskap: sample_selskap(),
        regnskapsaar: 2025,
        aksjonaerer: [
          %Aksjonaer{
            fodselsnummer: "12345678901",
            navn: "Ola Nordmann",
            antall_aksjer: 100,
            aksjeklasse: "A",
            utbytte_utbetalt: 0,
            innbetalt_kapital_per_aksje: 100
          }
        ]
      }

      assert :ok = Aksjonaerregister.valider(oppgave)
    end

    test "returns error for empty aksjonaerer list" do
      oppgave = %Aksjonaerregisteroppgave{
        selskap: sample_selskap(),
        regnskapsaar: 2025,
        aksjonaerer: []
      }

      assert {:error, errors} = Aksjonaerregister.valider(oppgave)
      assert Enum.any?(errors, &(&1 =~ "Minst én aksjonær"))
    end

    test "returns error for invalid fodselsnummer" do
      oppgave = %Aksjonaerregisteroppgave{
        selskap: sample_selskap(),
        regnskapsaar: 2025,
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
      assert Enum.any?(errors, &(&1 =~ "Ugyldig fødselsnummer"))
    end

    test "returns error when total shares is zero" do
      oppgave = %Aksjonaerregisteroppgave{
        selskap: sample_selskap(),
        regnskapsaar: 2025,
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
  end

  # Legacy API tests
  describe "validate_shareholders/1 (legacy)" do
    test "returns :ok for valid shareholders" do
      shareholders = [
        %{fodselsnummer: "12345678901", antall_aksjer: 100},
        %{fodselsnummer: "98765432101", antall_aksjer: 50}
      ]

      assert :ok = Aksjonaerregister.validate_shareholders(shareholders)
    end

    test "returns error for empty list" do
      assert {:error, :no_shareholders} = Aksjonaerregister.validate_shareholders([])
    end

    test "returns error for invalid fodselsnummer" do
      shareholders = [%{fodselsnummer: "1234", antall_aksjer: 100}]

      assert {:error, :invalid_fodselsnummer} =
               Aksjonaerregister.validate_shareholders(shareholders)
    end

    test "returns error when total shares is zero" do
      shareholders = [%{fodselsnummer: "12345678901", antall_aksjer: 0}]

      assert {:error, :invalid_total_shares} =
               Aksjonaerregister.validate_shareholders(shareholders)
    end
  end
end
