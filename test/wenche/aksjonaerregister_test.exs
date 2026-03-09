defmodule Wenche.AksjonaerregisterTest do
  use ExUnit.Case, async: true

  alias Wenche.Aksjonaerregister

  @company %{org_number: "912345678", name: "Aksje AS"}

  describe "generate_xml/3" do
    test "generates valid XML with shareholder data" do
      shareholders = [
        %{
          fodselsnummer: "12345678901",
          name: "Ola Nordmann",
          antall_aksjer: 100,
          aksjeklasse: "A",
          utbytte_utbetalt: Decimal.new("50000"),
          innbetalt_kapital_per_aksje: Decimal.new("100")
        },
        %{
          fodselsnummer: "98765432101",
          name: "Kari Nordmann",
          antall_aksjer: 50,
          aksjeklasse: "A",
          utbytte_utbetalt: Decimal.new("25000"),
          innbetalt_kapital_per_aksje: Decimal.new("100")
        }
      ]

      xml = Aksjonaerregister.generate_xml(2025, @company, shareholders)

      assert xml =~ "Aksjonaerregisteroppgave"
      assert xml =~ "2025"
      assert xml =~ "912345678"
      assert xml =~ "Aksje AS"
      assert xml =~ "Ola Nordmann"
      assert xml =~ "Kari Nordmann"
      assert xml =~ "150"
      assert xml =~ "75000"
    end
  end

  describe "validate_shareholders/1" do
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
