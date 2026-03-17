defmodule Wenche.AarsregnskapTest do
  use ExUnit.Case, async: true

  alias Wenche.Aarsregnskap

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
    Noter
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
        driftsinntekter: %Driftsinntekter{salgsinntekter: 0, andre_driftsinntekter: 0},
        driftskostnader: %Driftskostnader{andre_driftskostnader: 5_000},
        finansposter: %Finansposter{
          utbytte_fra_datterselskap: 100_000,
          andre_finansinntekter: 500
        }
      },
      balanse: %Balanse{
        eiendeler: %Eiendeler{
          anleggsmidler: %Anleggsmidler{aksjer_i_datterselskap: 500_000},
          omloepmidler: %Omloepmidler{bankinnskudd: 125_500}
        },
        egenkapital_og_gjeld: %EgenkapitalOgGjeld{
          egenkapital: %Egenkapital{aksjekapital: 30_000, annen_egenkapital: 595_500},
          langsiktig_gjeld: %LangsiktigGjeld{},
          kortsiktig_gjeld: %KortsiktigGjeld{}
        }
      }
    }
  end

  describe "valider/1" do
    test "returns empty list for valid regnskap" do
      regnskap = sample_regnskap()
      assert Wenche.Aarsregnskap.valider(regnskap) == []
    end

    test "returns error when balance doesn't balance" do
      regnskap = %{
        sample_regnskap()
        | balanse: %Balanse{
            eiendeler: %Eiendeler{
              anleggsmidler: %Anleggsmidler{aksjer_i_datterselskap: 600_000},
              omloepmidler: %Omloepmidler{bankinnskudd: 100_000}
            },
            egenkapital_og_gjeld: %EgenkapitalOgGjeld{
              egenkapital: %Egenkapital{aksjekapital: 30_000, annen_egenkapital: 100_000},
              langsiktig_gjeld: %LangsiktigGjeld{},
              kortsiktig_gjeld: %KortsiktigGjeld{}
            }
          }
      }

      errors = Wenche.Aarsregnskap.valider(regnskap)
      assert length(errors) == 1
      assert hd(errors) =~ "Balansen går ikke opp"
    end

    test "returns error for invalid org_nummer" do
      selskap = %{sample_selskap() | org_nummer: "12345"}
      regnskap = %{sample_regnskap() | selskap: selskap}

      errors = Wenche.Aarsregnskap.valider(regnskap)
      assert Enum.any?(errors, &(&1 =~ "Organisasjonsnummeret må være 9 siffer"))
    end

    test "warns when loennskostnader > 0 but antall_ansatte is 0" do
      regnskap = %{
        sample_regnskap()
        | resultatregnskap: %Resultatregnskap{
            driftskostnader: %Driftskostnader{loennskostnader: 100_000}
          },
          noter: %Noter{antall_ansatte: 0}
      }

      # Fix balance to match
      regnskap = %{
        regnskap
        | balanse: %Balanse{
            eiendeler: %Eiendeler{
              anleggsmidler: %Anleggsmidler{aksjer_i_datterselskap: 500_000},
              omloepmidler: %Omloepmidler{bankinnskudd: 125_500}
            },
            egenkapital_og_gjeld: %EgenkapitalOgGjeld{
              egenkapital: %Egenkapital{aksjekapital: 30_000, annen_egenkapital: 595_500},
              langsiktig_gjeld: %LangsiktigGjeld{},
              kortsiktig_gjeld: %KortsiktigGjeld{}
            }
          }
      }

      errors = Wenche.Aarsregnskap.valider(regnskap)
      assert Enum.any?(errors, &(&1 =~ "Lønnskostnader > 0 men antall ansatte er 0"))
    end

    test "warns when laan_fra_aksjonaer > 0 but no laan_til_naerstaaende" do
      regnskap = %{
        sample_regnskap()
        | balanse: %Balanse{
            eiendeler: %Eiendeler{
              anleggsmidler: %Anleggsmidler{aksjer_i_datterselskap: 500_000},
              omloepmidler: %Omloepmidler{bankinnskudd: 225_500}
            },
            egenkapital_og_gjeld: %EgenkapitalOgGjeld{
              egenkapital: %Egenkapital{aksjekapital: 30_000, annen_egenkapital: 595_500},
              langsiktig_gjeld: %LangsiktigGjeld{laan_fra_aksjonaer: 100_000},
              kortsiktig_gjeld: %KortsiktigGjeld{}
            }
          },
          noter: %Noter{laan_til_naerstaaende: []}
      }

      errors = Wenche.Aarsregnskap.valider(regnskap)
      assert Enum.any?(errors, &(&1 =~ "Lån fra aksjonær"))
    end
  end
end
