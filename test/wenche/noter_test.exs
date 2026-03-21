defmodule Wenche.NoterTest do
  use ExUnit.Case, async: true

  alias Wenche.Noter

  alias Wenche.Models.{
    Aarsregnskap,
    Anleggsmidler,
    Balanse,
    Driftsinntekter,
    Driftskostnader,
    Egenkapital,
    EgenkapitalOgGjeld,
    Eiendeler,
    Finansposter,
    KortsiktigGjeld,
    LaanTilNaerstaaende,
    LangsiktigGjeld,
    Noter,
    Omloepmidler,
    Resultatregnskap,
    Selskap
  }

  def sample_selskap do
    %Selskap{
      navn: "Test Holding AS",
      org_nummer: "912345678",
      daglig_leder: "Ola Nordmann",
      styreleder: "Kari Nordmann",
      forretningsadresse: "Storgata 1, 0001 Oslo",
      stiftelsesaar: 2020,
      aksjekapital: 30_000
    }
  end

  def sample_regnskap(opts \\ []) do
    noter = Keyword.get(opts, :noter, %Noter{})

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
      },
      foregaaende_aar_balanse: %Balanse{
        eiendeler: %Eiendeler{
          anleggsmidler: %Anleggsmidler{aksjer_i_datterselskap: 500_000},
          omloepmidler: %Omloepmidler{bankinnskudd: 30_000}
        },
        egenkapital_og_gjeld: %EgenkapitalOgGjeld{
          egenkapital: %Egenkapital{aksjekapital: 30_000, annen_egenkapital: 500_000},
          langsiktig_gjeld: %LangsiktigGjeld{},
          kortsiktig_gjeld: %KortsiktigGjeld{}
        }
      },
      noter: noter
    }
  end

  describe "default_regnskapsprinsipper/0" do
    test "returns non-empty text mentioning små foretak" do
      text = Wenche.Noter.default_regnskapsprinsipper()
      assert text =~ "små foretak"
      assert text =~ "regnskapsloven"
    end
  end

  describe "egenkapital_note/1" do
    test "generates IB and UB rows with prior year" do
      rows = Wenche.Noter.egenkapital_note(sample_regnskap())

      # Should have IB, årsresultat, UB = at least 3 rows
      assert length(rows) >= 3

      # First row is IB
      {label, ak, _ok, aek, _sum} = hd(rows)
      assert label =~ "01.01.2025"
      assert ak == 30_000
      assert aek == 500_000

      # Last row is UB
      {label, ak, _ok, aek, _sum} = List.last(rows)
      assert label =~ "31.12.2025"
      assert ak == 30_000
      assert aek == 595_500
    end

    test "includes utbytte row when utbytte_utbetalt != 0" do
      regnskap = %{sample_regnskap() | utbytte_utbetalt: 50_000}
      rows = Wenche.Noter.egenkapital_note(regnskap)
      labels = Enum.map(rows, fn {label, _, _, _, _} -> label end)
      assert "Utbytte utbetalt" in labels
    end

    test "only UB row when no prior year data" do
      regnskap = %{sample_regnskap() | foregaaende_aar_balanse: %Balanse{}}
      rows = Wenche.Noter.egenkapital_note(regnskap)
      assert length(rows) == 1
      {label, _, _, _, _} = hd(rows)
      assert label =~ "31.12.2025"
    end
  end

  describe "generer_noter_xml/1" do
    test "includes antallAarsverk from noter" do
      regnskap = sample_regnskap(noter: %Noter{antall_ansatte: 3})
      xml = Wenche.Noter.generer_noter_xml(regnskap)
      assert xml =~ "<antallAarsverk orid=\"37467\">3</antallAarsverk>"
    end

    test "includes antallAarsverk 0 by default" do
      xml = Wenche.Noter.generer_noter_xml(sample_regnskap())
      assert xml =~ "<antallAarsverk orid=\"37467\">0</antallAarsverk>"
    end

    test "includes egenkapital note with IB/UB" do
      xml = Wenche.Noter.generer_noter_xml(sample_regnskap())
      assert xml =~ "<noteEgenkapital>"
      assert xml =~ "<egenkapitalAapningsbalanse>"
      assert xml =~ "<egenkapitalAvslutningsbalanse>"
      assert xml =~ "37499"
    end

    test "includes aarsresultat in egenkapital note" do
      xml = Wenche.Noter.generer_noter_xml(sample_regnskap())
      # årsresultat = 0 + 0 - 5000 + 100000 + 500 - 0 - 0 = 95500
      assert xml =~ "<annenEgenkapital orid=\"37509\">95500</annenEgenkapital>"
    end

    test "includes utbytte in egenkapital note when present" do
      regnskap = %{sample_regnskap() | utbytte_utbetalt: 50_000}
      xml = Wenche.Noter.generer_noter_xml(regnskap)
      assert xml =~ "<utbyttePaaVedtatt>"
      assert xml =~ "<annenEgenkapital orid=\"37517\">-50000</annenEgenkapital>"
    end

    test "generates valid XML structure" do
      xml = Wenche.Noter.generer_noter_xml(sample_regnskap())
      assert xml =~ "<noter>"
      assert xml =~ "</noter>"
    end
  end

  describe "generer_noter_tekst/1" do
    test "includes regnskapsprinsipper" do
      notes = Wenche.Noter.generer_noter_tekst(sample_regnskap())
      titles = Enum.map(notes, fn {title, _} -> title end)
      assert "Regnskapsprinsipper" in titles
    end

    test "uses custom regnskapsprinsipper when provided" do
      noter = %Noter{regnskapsprinsipper: "Egendefinerte prinsipper."}
      notes = Wenche.Noter.generer_noter_tekst(sample_regnskap(noter: noter))
      {_, content} = Enum.find(notes, fn {t, _} -> t == "Regnskapsprinsipper" end)
      assert content == "Egendefinerte prinsipper."
    end

    test "includes antall ansatte" do
      noter = %Noter{antall_ansatte: 5}
      notes = Wenche.Noter.generer_noter_tekst(sample_regnskap(noter: noter))
      {_, content} = Enum.find(notes, fn {t, _} -> t == "Antall ansatte" end)
      assert content =~ "5"
    end

    test "includes egenkapital note" do
      notes = Wenche.Noter.generer_noter_tekst(sample_regnskap())
      titles = Enum.map(notes, fn {title, _} -> title end)
      assert "Egenkapital" in titles
    end

    test "includes konsern note when datterselskap exists" do
      notes = Wenche.Noter.generer_noter_tekst(sample_regnskap())
      titles = Enum.map(notes, fn {title, _} -> title end)
      assert "Konsern og tilknyttet selskap" in titles
    end

    test "no konsern note when no datterselskap" do
      regnskap = sample_regnskap()
      regnskap = put_in(regnskap.balanse.eiendeler.anleggsmidler.aksjer_i_datterselskap, 0)
      notes = Wenche.Noter.generer_noter_tekst(regnskap)
      titles = Enum.map(notes, fn {title, _} -> title end)
      refute "Konsern og tilknyttet selskap" in titles
    end

    test "includes negative laan note when no loans" do
      notes = Wenche.Noter.generer_noter_tekst(sample_regnskap())

      {_, content} =
        Enum.find(notes, fn {t, _} -> t == "Lån og sikkerhetsstillelse til nærstående" end)

      assert content =~ "ikke gitt lån"
    end

    test "includes laan details when loans exist" do
      noter = %Noter{
        laan_til_naerstaaende: [
          %LaanTilNaerstaaende{
            navn: "Ola Nordmann",
            rolle: "aksjonær",
            beloep: 100_000,
            rentesats: 3.0
          }
        ]
      }

      notes = Wenche.Noter.generer_noter_tekst(sample_regnskap(noter: noter))

      {_, content} =
        Enum.find(notes, fn {t, _} -> t == "Lån og sikkerhetsstillelse til nærstående" end)

      assert content =~ "Ola Nordmann"
      assert content =~ "aksjonær"
      assert content =~ "100 000"
      assert content =~ "3.0%"
    end

    test "includes fortsatt drift note when usikkerhet" do
      noter = %Noter{
        fortsatt_drift_usikkerhet: true,
        fortsatt_drift_beskrivelse: "Selskapet har negativt driftsresultat."
      }

      notes = Wenche.Noter.generer_noter_tekst(sample_regnskap(noter: noter))
      {_, content} = Enum.find(notes, fn {t, _} -> t == "Fortsatt drift" end)
      assert content =~ "negativt driftsresultat"
    end

    test "no fortsatt drift note when no usikkerhet" do
      notes = Wenche.Noter.generer_noter_tekst(sample_regnskap())
      titles = Enum.map(notes, fn {title, _} -> title end)
      refute "Fortsatt drift" in titles
    end
  end
end
