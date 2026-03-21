defmodule Wenche.SkattemeldingXmlTest do
  use ExUnit.Case, async: true

  alias Wenche.SkattemeldingXml

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
    LangsiktigGjeld,
    Omloepmidler,
    Resultatregnskap,
    Selskap,
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
        driftsinntekter: %Driftsinntekter{salgsinntekter: 500_000, andre_driftsinntekter: 10_000},
        driftskostnader: %Driftskostnader{
          loennskostnader: 200_000,
          avskrivninger: 20_000,
          andre_driftskostnader: 130_000
        },
        finansposter: %Finansposter{
          utbytte_fra_datterselskap: 50_000,
          andre_finansinntekter: 5_000,
          rentekostnader: 10_000,
          andre_finanskostnader: 2_000
        }
      },
      balanse: %Balanse{
        eiendeler: %Eiendeler{
          anleggsmidler: %Anleggsmidler{
            aksjer_i_datterselskap: 200_000,
            andre_aksjer: 50_000,
            langsiktige_fordringer: 30_000
          },
          omloepmidler: %Omloepmidler{
            kortsiktige_fordringer: 80_000,
            bankinnskudd: 300_000
          }
        },
        egenkapital_og_gjeld: %EgenkapitalOgGjeld{
          egenkapital: %Egenkapital{
            aksjekapital: 100_000,
            overkursfond: 50_000,
            annen_egenkapital: 260_000
          },
          langsiktig_gjeld: %LangsiktigGjeld{
            laan_fra_aksjonaer: 100_000,
            andre_langsiktige_laan: 50_000
          },
          kortsiktig_gjeld: %KortsiktigGjeld{
            leverandoergjeld: 60_000,
            skyldige_offentlige_avgifter: 20_000,
            annen_kortsiktig_gjeld: 20_000
          }
        }
      }
    }
  end

  describe "generer_skattemelding_xml/2" do
    test "produces valid XML with correct namespace" do
      xml = SkattemeldingXml.generer_skattemelding_xml(sample_regnskap(), %SkattemeldingKonfig{})

      assert xml =~
               ~s(xmlns="urn:no:skatteetaten:fastsetting:formueinntekt:skattemelding:upersonlig:ekstern:v5")

      assert xml =~ "<skattemelding"
      assert xml =~ "</skattemelding>"
    end

    test "includes partsnummer and inntektsaar" do
      xml = SkattemeldingXml.generer_skattemelding_xml(sample_regnskap(), %SkattemeldingKonfig{})

      assert xml =~ "<partsnummer>912345678</partsnummer>"
      assert xml =~ "<inntektsaar>2025</inntektsaar>"
    end

    test "maps income data to inntektOgUnderskudd" do
      xml = SkattemeldingXml.generer_skattemelding_xml(sample_regnskap(), %SkattemeldingKonfig{})

      assert xml =~ "<inntektOgUnderskudd>"
      assert xml =~ "<naeringsinntekt>"
      assert xml =~ "<samletInntekt>"
    end

    test "maps balance data to formueOgGjeld" do
      xml = SkattemeldingXml.generer_skattemelding_xml(sample_regnskap(), %SkattemeldingKonfig{})

      assert xml =~ "<formueOgGjeld>"
      assert xml =~ "<bankinnskudd>"
      assert xml =~ "<beloepSomHeltall>300000</beloepSomHeltall>"
      assert xml =~ "<samletGjeld>"
      assert xml =~ "<nettoFormue>"
    end

    test "applies fritaksmetoden for subsidiary dividends" do
      konfig = %SkattemeldingKonfig{
        anvend_fritaksmetoden: true,
        eierandel_datterselskap: 100
      }

      xml = SkattemeldingXml.generer_skattemelding_xml(sample_regnskap(), konfig)

      # With 100% ownership, dividend is fully exempt (fritatt)
      # naeringsinntekt = driftsresultat(160000) + 0(exempt dividend) + 5000 - 12000 = 153000
      assert xml =~
               "<naeringsinntekt><beloepSomHeltall>153000</beloepSomHeltall></naeringsinntekt>"
    end

    test "applies 3% sjablonregel for <90% ownership" do
      konfig = %SkattemeldingKonfig{
        anvend_fritaksmetoden: true,
        eierandel_datterselskap: 50
      }

      xml = SkattemeldingXml.generer_skattemelding_xml(sample_regnskap(), konfig)

      # 3% of 50000 = 1500
      # naeringsinntekt = 160000 + 1500 + 5000 - 12000 = 154500
      assert xml =~
               "<naeringsinntekt><beloepSomHeltall>154500</beloepSomHeltall></naeringsinntekt>"
    end
  end

  describe "generer_naeringsspesifikasjon_xml/1" do
    test "produces valid XML with correct namespace" do
      xml = SkattemeldingXml.generer_naeringsspesifikasjon_xml(sample_regnskap())

      assert xml =~
               ~s(xmlns="urn:no:skatteetaten:fastsetting:formueinntekt:naeringsspesifikasjon:ekstern:v5")

      assert xml =~ "<naeringsspesifikasjon"
      assert xml =~ "</naeringsspesifikasjon>"
    end

    test "includes partsreferanse and inntektsaar" do
      xml = SkattemeldingXml.generer_naeringsspesifikasjon_xml(sample_regnskap())

      assert xml =~ "<partsreferanse>912345678</partsreferanse>"
      assert xml =~ "<inntektsaar>2025</inntektsaar>"
    end

    test "maps resultatregnskap items" do
      xml = SkattemeldingXml.generer_naeringsspesifikasjon_xml(sample_regnskap())

      assert xml =~ "<driftsinntekt>"
      assert xml =~ "<sumDriftsinntekt>"
      assert xml =~ "<driftskostnad>"
      assert xml =~ "<sumDriftskostnad>"
      assert xml =~ "<driftsresultat>"
      assert xml =~ "<aarsresultat>"
    end

    test "includes salgsinntekt line items with account types" do
      xml = SkattemeldingXml.generer_naeringsspesifikasjon_xml(sample_regnskap())

      assert xml =~ "<resultatOgBalanseregnskapstype>3000</resultatOgBalanseregnskapstype>"
      assert xml =~ "<id>3000</id>"
    end

    test "includes virksomhet metadata" do
      xml = SkattemeldingXml.generer_naeringsspesifikasjon_xml(sample_regnskap())

      assert xml =~ "<virksomhet>"
      assert xml =~ "<regnskapsplikttype>fullRegnskapsplikt</regnskapsplikttype>"
      assert xml =~ "<dato>2025-01-01</dato>"
      assert xml =~ "<dato>2025-12-31</dato>"
      assert xml =~ "<virksomhetstype>oevrigSelskap</virksomhetstype>"
      assert xml =~ "<skalBekreftedsAvRevisor>false</skalBekreftedsAvRevisor>"
    end

    test "includes finansinntekt and finanskostnad" do
      xml = SkattemeldingXml.generer_naeringsspesifikasjon_xml(sample_regnskap())

      assert xml =~ "<finansinntekt>"
      assert xml =~ "<finanskostnad>"
      # Sum of utbytte(50000) + andre_finansinntekter(5000) = 55000
      assert xml =~ "<sumFinansinntekt><beloep><beloep>55000</beloep></beloep></sumFinansinntekt>"
      # Sum of rentekostnader(10000) + andre_finanskostnader(2000) = 12000
      assert xml =~ "<sumFinanskostnad><beloep><beloep>12000</beloep></beloep></sumFinanskostnad>"
    end
  end

  describe "generer_request_xml/3" do
    test "wraps inner documents in request envelope" do
      xml =
        SkattemeldingXml.generer_request_xml(
          "<inner1/>",
          "<inner2/>",
          dokumentidentifikator: "abc-123",
          inntektsaar: 2025
        )

      assert xml =~ "<skattemeldingOgNaeringsspesifikasjonRequest"

      assert xml =~
               ~s(xmlns="no:skatteetaten:fastsetting:formueinntekt:skattemeldingognaeringsspesifikasjon:request:v2")
    end

    test "base64-encodes inner documents" do
      xml =
        SkattemeldingXml.generer_request_xml(
          "<skattemelding>test</skattemelding>",
          "<naeringsspesifikasjon>test</naeringsspesifikasjon>",
          inntektsaar: 2025
        )

      expected_b64_1 = Base.encode64("<skattemelding>test</skattemelding>")
      expected_b64_2 = Base.encode64("<naeringsspesifikasjon>test</naeringsspesifikasjon>")

      assert xml =~ "<content>#{expected_b64_1}</content>"
      assert xml =~ "<content>#{expected_b64_2}</content>"
    end

    test "includes document types" do
      xml = SkattemeldingXml.generer_request_xml("<a/>", "<b/>", inntektsaar: 2025)

      assert xml =~ "<type>skattemeldingUpersonlig</type>"
      assert xml =~ "<type>naeringsspesifikasjon</type>"
    end

    test "includes dokumentreferanse and innsendingsinformasjon" do
      xml =
        SkattemeldingXml.generer_request_xml(
          "<a/>",
          "<b/>",
          dokumentidentifikator: "ref-123",
          inntektsaar: 2025
        )

      assert xml =~ "<dokumentidentifikator>ref-123</dokumentidentifikator>"
      assert xml =~ "<inntektsaar>2025</inntektsaar>"
      assert xml =~ "<innsendingstype>komplett</innsendingstype>"
      assert xml =~ "<opprettetAv>Kontira</opprettetAv>"
    end
  end

  describe "beregn_skattepliktig_inntekt/2" do
    test "calculates basic taxable income" do
      r = %Resultatregnskap{
        driftsinntekter: %Driftsinntekter{salgsinntekter: 100_000},
        driftskostnader: %Driftskostnader{andre_driftskostnader: 40_000},
        finansposter: %Finansposter{}
      }

      konfig = %SkattemeldingKonfig{}

      {netto, skatt} = SkattemeldingXml.beregn_skattepliktig_inntekt(r, konfig)

      assert netto == 60_000
      assert skatt == 13_200
    end

    test "applies loss carryforward" do
      r = %Resultatregnskap{
        driftsinntekter: %Driftsinntekter{salgsinntekter: 100_000},
        driftskostnader: %Driftskostnader{andre_driftskostnader: 40_000},
        finansposter: %Finansposter{}
      }

      konfig = %SkattemeldingKonfig{underskudd_til_fremfoering: 20_000}

      {netto, skatt} = SkattemeldingXml.beregn_skattepliktig_inntekt(r, konfig)

      assert netto == 40_000
      assert skatt == 8_800
    end

    test "no tax on negative income" do
      r = %Resultatregnskap{
        driftsinntekter: %Driftsinntekter{salgsinntekter: 20_000},
        driftskostnader: %Driftskostnader{andre_driftskostnader: 50_000},
        finansposter: %Finansposter{}
      }

      konfig = %SkattemeldingKonfig{}

      {netto, skatt} = SkattemeldingXml.beregn_skattepliktig_inntekt(r, konfig)

      assert netto == -30_000
      assert skatt == 0
    end
  end
end
