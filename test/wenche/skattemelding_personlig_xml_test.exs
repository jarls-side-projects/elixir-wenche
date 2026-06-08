defmodule Wenche.SkattemeldingPersonligXmlTest do
  use ExUnit.Case, async: true

  alias Wenche.SkattemeldingPersonligXml
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
    Selskap
  }

  @v13_ns "urn:no:skatteetaten:fastsetting:formueinntekt:skattemelding:ekstern:v13"

  # An ENK (enkeltpersonforetak): the "selskap" carries the owner's sole
  # proprietorship org number; there is no aksjekapital / datterselskap.
  def sample_enk do
    %Selskap{
      navn: "Ola Nordmann ENK",
      org_nummer: "912345678",
      forretningsadresse: "Storgata 1, 0001 Oslo",
      stiftelsesaar: 2022,
      aksjekapital: 0
    }
  end

  def sample_regnskap do
    %Aarsregnskap{
      selskap: sample_enk(),
      regnskapsaar: 2025,
      resultatregnskap: %Resultatregnskap{
        driftsinntekter: %Driftsinntekter{salgsinntekter: 400_000, andre_driftsinntekter: 0},
        driftskostnader: %Driftskostnader{
          loennskostnader: 0,
          avskrivninger: 0,
          andre_driftskostnader: 150_000
        },
        finansposter: %Finansposter{
          utbytte_fra_datterselskap: 0,
          andre_finansinntekter: 0,
          rentekostnader: 2_000,
          andre_finanskostnader: 0
        }
      },
      balanse: %Balanse{
        eiendeler: %Eiendeler{
          anleggsmidler: %Anleggsmidler{
            aksjer_i_datterselskap: 0,
            andre_aksjer: 0,
            langsiktige_fordringer: 0
          },
          omloepmidler: %Omloepmidler{
            kortsiktige_fordringer: 20_000,
            bankinnskudd: 130_000
          }
        },
        egenkapital_og_gjeld: %EgenkapitalOgGjeld{
          egenkapital: %Egenkapital{
            aksjekapital: 0,
            overkursfond: 0,
            annen_egenkapital: 120_000
          },
          langsiktig_gjeld: %LangsiktigGjeld{
            laan_fra_aksjonaer: 0,
            andre_langsiktige_laan: 0
          },
          kortsiktig_gjeld: %KortsiktigGjeld{
            leverandoergjeld: 30_000,
            skyldige_offentlige_avgifter: 0,
            annen_kortsiktig_gjeld: 0
          }
        }
      }
    }
  end

  describe "generer_skattemelding_personlig_xml/2" do
    test "produces minimal personlig XML with the v13 namespace" do
      xml = SkattemeldingPersonligXml.generer_skattemelding_personlig_xml(sample_regnskap())

      assert xml =~ ~s(xmlns="#{@v13_ns}")
      assert xml =~ "<skattemelding"
      assert xml =~ "</skattemelding>"
    end

    test "emits partsreferanse and inntektsaar" do
      xml = SkattemeldingPersonligXml.generer_skattemelding_personlig_xml(sample_regnskap())

      assert xml =~ "<partsreferanse>912345678</partsreferanse>"
      assert xml =~ "<inntektsaar>2025</inntektsaar>"
    end

    test "uses :partsreferanse override when provided" do
      xml =
        SkattemeldingPersonligXml.generer_skattemelding_personlig_xml(sample_regnskap(),
          partsreferanse: 4_711
        )

      assert xml =~ "<partsreferanse>4711</partsreferanse>"
      refute xml =~ "<partsreferanse>912345678</partsreferanse>"
    end

    test "does not emit upersonlig-only elements" do
      xml = SkattemeldingPersonligXml.generer_skattemelding_personlig_xml(sample_regnskap())

      refute xml =~ "<partsnummer>"
      refute xml =~ "inntektOgUnderskudd"
    end
  end

  describe "naeringsspesifikasjon with skattepliktig_type: :personlig" do
    setup do
      xml =
        SkattemeldingXml.generer_naeringsspesifikasjon_xml(sample_regnskap(),
          skattepliktig_type: :personlig
        )

      %{xml: xml}
    end

    test "uses enkeltpersonforetak / begrensetRegnskapsplikt", %{xml: xml} do
      assert xml =~ "<virksomhetstype>enkeltpersonforetak</virksomhetstype>"
      assert xml =~ "<regnskapspliktstype>begrensetRegnskapsplikt</regnskapspliktstype>"
      refute xml =~ "oevrigSelskap"
      refute xml =~ "fullRegnskapsplikt"
    end

    test "allocates næringsinntekt to the innehaver (personlig fordelt block)", %{xml: xml} do
      assert xml =~ "<fordeltBeregnetNaeringsinntektForPersonligSkattepliktigEllerSdf>"
      refute xml =~ "fordeltBeregnetNaeringsinntektForUpersonligSkattepliktig"
    end

    test "omits the optional regeltypeForAarsregnskap for ENK", %{xml: xml} do
      refute xml =~ "regeltypeForAarsregnskap"
    end
  end

  describe "upersonlig naeringsspesifikasjon stays unchanged (default)" do
    test "still emits oevrigSelskap / upersonlig allocation" do
      xml = SkattemeldingXml.generer_naeringsspesifikasjon_xml(sample_regnskap())

      assert xml =~ "<virksomhetstype>oevrigSelskap</virksomhetstype>"
      assert xml =~ "<regnskapspliktstype>fullRegnskapsplikt</regnskapspliktstype>"
      assert xml =~ "fordeltBeregnetNaeringsinntektForUpersonligSkattepliktig"
    end
  end

  describe "request envelope with skattemelding_dokumenttype: skattemeldingPersonlig" do
    test "sets the skattemelding dokument type to skattemeldingPersonlig" do
      sm = SkattemeldingPersonligXml.generer_skattemelding_personlig_xml(sample_regnskap())

      ne =
        SkattemeldingXml.generer_naeringsspesifikasjon_xml(sample_regnskap(),
          skattepliktig_type: :personlig
        )

      req =
        SkattemeldingXml.generer_request_xml(sm, ne,
          inntektsaar: 2025,
          tin: "912345678",
          skattemelding_dokumenttype: "skattemeldingPersonlig"
        )

      assert req =~ "<type>skattemeldingPersonlig</type>"
      refute req =~ "<type>skattemeldingUpersonlig</type>"
      assert req =~ "<type>naeringsspesifikasjon</type>"
    end

    test "rejects an unknown skattemelding dokument type" do
      assert_raise ArgumentError, ~r/skattemelding_dokumenttype/, fn ->
        SkattemeldingXml.generer_request_xml("<a/>", "<b/>",
          inntektsaar: 2025,
          skattemelding_dokumenttype: "tull"
        )
      end
    end
  end

  describe "hent_partsreferanse/1" do
    test "extracts the integer partsreferanse" do
      xml = SkattemeldingPersonligXml.generer_skattemelding_personlig_xml(sample_regnskap())
      assert {:ok, 912_345_678} = SkattemeldingPersonligXml.hent_partsreferanse(xml)
    end

    test "handles namespace-prefixed elements" do
      xml = ~s(<ns:skattemelding><ns:partsreferanse>4711</ns:partsreferanse></ns:skattemelding>)
      assert {:ok, 4_711} = SkattemeldingPersonligXml.hent_partsreferanse(xml)
    end

    test "returns an error when partsreferanse is absent" do
      assert {:error, :partsreferanse_not_found} =
               SkattemeldingPersonligXml.hent_partsreferanse("<skattemelding/>")
    end
  end

  describe "XSD validation (requires xmllint; XSDs vendored at priv/xsd/skatteetaten)" do
    @xsd_dir Path.join(:code.priv_dir(:wenche), "xsd/skatteetaten")

    @tag :xsd
    test "personlig skattemelding (v13) validates" do
      xml = SkattemeldingPersonligXml.generer_skattemelding_personlig_xml(sample_regnskap())
      assert_xml_valid!(xml, "#{@xsd_dir}/skattemelding_v13_ekstern.xsd")
    end

    @tag :xsd
    test "ENK naeringsspesifikasjon (v6, personlig) validates" do
      xml =
        SkattemeldingXml.generer_naeringsspesifikasjon_xml(sample_regnskap(),
          skattepliktig_type: :personlig
        )

      assert_xml_valid!(xml, "#{@xsd_dir}/naeringsspesifikasjon_v6_ekstern.xsd")
    end

    @tag :xsd
    test "personlig request envelope (v2) validates" do
      sm = SkattemeldingPersonligXml.generer_skattemelding_personlig_xml(sample_regnskap())

      ne =
        SkattemeldingXml.generer_naeringsspesifikasjon_xml(sample_regnskap(),
          skattepliktig_type: :personlig
        )

      req =
        SkattemeldingXml.generer_request_xml(sm, ne,
          inntektsaar: 2025,
          tin: "912345678",
          skattemelding_dokumenttype: "skattemeldingPersonlig"
        )

      assert_xml_valid!(req, "#{@xsd_dir}/skattemeldingognaeringsspesifikasjonrequest_v2.xsd")
    end

    defp assert_xml_valid!(xml, schema_path) do
      unless File.exists?(schema_path), do: flunk("Schema not found: #{schema_path}")

      path =
        Path.join(
          System.tmp_dir!(),
          "wenche_personlig_xsd_test_#{System.unique_integer([:positive])}.xml"
        )

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
