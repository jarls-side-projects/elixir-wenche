defmodule Wenche.IxbrlTest do
  use ExUnit.Case, async: true

  alias Wenche.Ixbrl
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
    KortsiktigGjeld
  }

  def sample_regnskap do
    %Aarsregnskap{
      selskap: %Selskap{
        navn: "Test AS",
        org_nummer: "912345678",
        daglig_leder: "Ola Nordmann",
        styreleder: "Kari Nordmann",
        forretningsadresse: "Storgata 1, 0001 Oslo",
        stiftelsesaar: 2020,
        aksjekapital: 30_000
      },
      regnskapsaar: 2025,
      resultatregnskap: %Resultatregnskap{
        driftsinntekter: %Driftsinntekter{salgsinntekter: 500_000, andre_driftsinntekter: 0},
        driftskostnader: %Driftskostnader{
          loennskostnader: 200_000,
          avskrivninger: 50_000,
          andre_driftskostnader: 100_000
        },
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
          egenkapital: %Egenkapital{
            aksjekapital: 100_000,
            overkursfond: 0,
            annen_egenkapital: 150_000
          },
          langsiktig_gjeld: %LangsiktigGjeld{laan_fra_aksjonaer: 100_000},
          kortsiktig_gjeld: %KortsiktigGjeld{leverandoergjeld: 150_000}
        }
      }
    }
  end

  describe "generer_ixbrl/1" do
    test "generates valid HTML document" do
      html = Ixbrl.generer_ixbrl(sample_regnskap())

      assert html =~ "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
      assert html =~ "<html"
      assert html =~ "</html>"
    end

    test "includes XBRL namespaces" do
      html = Ixbrl.generer_ixbrl(sample_regnskap())

      assert html =~ "xmlns:ix="
      assert html =~ "xmlns:xbrli="
      assert html =~ "xmlns:iso4217="
      assert html =~ "xmlns:no-gaap="
    end

    test "includes context c1 (instant/balance date)" do
      html = Ixbrl.generer_ixbrl(sample_regnskap())

      assert html =~ ~s(id="c1")
      assert html =~ "<xbrli:instant>2025-12-31</xbrli:instant>"
    end

    test "includes context c2 (period/fiscal year)" do
      html = Ixbrl.generer_ixbrl(sample_regnskap())

      assert html =~ ~s(id="c2")
      assert html =~ "<xbrli:startDate>2025-01-01</xbrli:startDate>"
      assert html =~ "<xbrli:endDate>2025-12-31</xbrli:endDate>"
    end

    test "includes NOK unit definition" do
      html = Ixbrl.generer_ixbrl(sample_regnskap())

      assert html =~ ~s(id="NOK")
      assert html =~ "iso4217:NOK"
    end

    test "includes ix:nonFraction tags with correct concepts" do
      html = Ixbrl.generer_ixbrl(sample_regnskap())

      assert html =~ ~s(name="no-gaap:SalesRevenue" contextRef="c2")
      assert html =~ ~s(name="no-gaap:WagesAndSalaries" contextRef="c2")
      assert html =~ ~s(name="no-gaap:ProfitLoss" contextRef="c2")
      assert html =~ ~s(name="no-gaap:Assets" contextRef="c1")
      assert html =~ ~s(name="no-gaap:Equity" contextRef="c1")
    end

    test "contains company information" do
      html = Ixbrl.generer_ixbrl(sample_regnskap())

      assert html =~ "Test AS"
      assert html =~ "912345678"
      assert html =~ "2025"
    end

    test "escapes HTML in company name" do
      regnskap = sample_regnskap()
      regnskap = %{regnskap | selskap: %{regnskap.selskap | navn: "Test & <Company>"}}
      html = Ixbrl.generer_ixbrl(regnskap)

      assert html =~ "Test &amp; &lt;Company&gt;"
      refute html =~ "Test & <Company>"
    end
  end
end
