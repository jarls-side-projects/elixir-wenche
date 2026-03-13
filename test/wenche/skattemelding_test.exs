defmodule Wenche.SkattemeldingTest do
  use ExUnit.Case, async: true

  alias Wenche.Skattemelding
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
    SkattemeldingKonfig
  }

  def sample_selskap do
    %Selskap{
      navn: "Test AS",
      org_nummer: "912345678",
      daglig_leder: "Ola Nordmann",
      styreleder: "Kari Nordmann",
      forretningsadresse: "Storgata 1, 0001 Oslo",
      stiftelsesaar: 2020,
      aksjekapital: 30_000
    }
  end

  def sample_regnskap do
    %Aarsregnskap{
      selskap: sample_selskap(),
      regnskapsaar: 2025,
      resultatregnskap: %Resultatregnskap{
        driftsinntekter: %Driftsinntekter{salgsinntekter: 500_000},
        driftskostnader: %Driftskostnader{andre_driftskostnader: 350_000},
        finansposter: %Finansposter{
          andre_finansinntekter: 10_000,
          rentekostnader: 5_000
        }
      },
      balanse: %Balanse{
        eiendeler: %Eiendeler{
          anleggsmidler: %Anleggsmidler{aksjer_i_datterselskap: 200_000},
          omloepmidler: %Omloepmidler{bankinnskudd: 300_000}
        },
        egenkapital_og_gjeld: %EgenkapitalOgGjeld{
          egenkapital: %Egenkapital{aksjekapital: 100_000, annen_egenkapital: 150_000},
          langsiktig_gjeld: %LangsiktigGjeld{laan_fra_aksjonaer: 100_000},
          kortsiktig_gjeld: %KortsiktigGjeld{leverandoergjeld: 150_000}
        }
      }
    }
  end

  describe "generer/2" do
    test "generates a report with company info" do
      konfig = %SkattemeldingKonfig{}
      report = Skattemelding.generer(sample_regnskap(), konfig)

      assert report =~ "Test AS"
      assert report =~ "912345678"
      assert report =~ "2025"
    end

    test "includes RF-1167 section" do
      konfig = %SkattemeldingKonfig{}
      report = Skattemelding.generer(sample_regnskap(), konfig)

      assert report =~ "RF-1167"
      assert report =~ "NÆRINGSOPPGAVE"
      assert report =~ "DRIFTSINNTEKTER"
      assert report =~ "DRIFTSKOSTNADER"
    end

    test "includes RF-1028 section" do
      konfig = %SkattemeldingKonfig{}
      report = Skattemelding.generer(sample_regnskap(), konfig)

      assert report =~ "RF-1028"
      assert report =~ "SKATTEMELDING FOR AS"
      assert report =~ "22 %"
    end

    test "includes balance section" do
      konfig = %SkattemeldingKonfig{}
      report = Skattemelding.generer(sample_regnskap(), konfig)

      assert report =~ "BALANSE"
      assert report =~ "EIENDELER"
      assert report =~ "EGENKAPITAL OG GJELD"
    end

    test "applies fritaksmetoden for subsidiary dividends" do
      regnskap = %{
        sample_regnskap()
        | resultatregnskap: %Resultatregnskap{
            driftsinntekter: %Driftsinntekter{salgsinntekter: 0},
            driftskostnader: %Driftskostnader{andre_driftskostnader: 5_000},
            finansposter: %Finansposter{utbytte_fra_datterselskap: 100_000}
          }
      }

      konfig = %SkattemeldingKonfig{anvend_fritaksmetoden: true, eierandel_datterselskap: 100}
      report = Skattemelding.generer(regnskap, konfig)

      assert report =~ "fritatt"
    end

    test "applies 3% rule for <90% ownership" do
      regnskap = %{
        sample_regnskap()
        | resultatregnskap: %Resultatregnskap{
            driftsinntekter: %Driftsinntekter{salgsinntekter: 0},
            driftskostnader: %Driftskostnader{andre_driftskostnader: 5_000},
            finansposter: %Finansposter{utbytte_fra_datterselskap: 100_000}
          }
      }

      konfig = %SkattemeldingKonfig{anvend_fritaksmetoden: true, eierandel_datterselskap: 50}
      report = Skattemelding.generer(regnskap, konfig)

      assert report =~ "97 %"
      assert report =~ "3 %"
    end

    test "applies loss carryforward" do
      regnskap = %{
        sample_regnskap()
        | resultatregnskap: %Resultatregnskap{
            driftsinntekter: %Driftsinntekter{salgsinntekter: 100_000},
            driftskostnader: %Driftskostnader{andre_driftskostnader: 0},
            finansposter: %Finansposter{}
          }
      }

      konfig = %SkattemeldingKonfig{underskudd_til_fremfoering: 50_000}
      report = Skattemelding.generer(regnskap, konfig)

      assert report =~ "fremf. underskudd"
    end
  end
end
