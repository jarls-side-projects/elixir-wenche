defmodule Wenche.Models do
  @moduledoc """
  Data models for all three submission types: annual accounts, tax return,
  and shareholder register.

  Ported from `wenche/models.py` in the original Python Wenche project.
  """

  # ---------------------------------------------------------------------------
  # Company info
  # ---------------------------------------------------------------------------

  defmodule Selskap do
    @moduledoc "Company information."
    defstruct [
      :navn,
      :org_nummer,
      :daglig_leder,
      :styreleder,
      :forretningsadresse,
      :stiftelsesaar,
      :aksjekapital
    ]

    @type t :: %__MODULE__{
            navn: String.t(),
            org_nummer: String.t(),
            daglig_leder: String.t(),
            styreleder: String.t(),
            forretningsadresse: String.t(),
            stiftelsesaar: integer(),
            aksjekapital: integer()
          }
  end

  # ---------------------------------------------------------------------------
  # Income statement components
  # ---------------------------------------------------------------------------

  defmodule Driftsinntekter do
    @moduledoc "Operating income."
    defstruct salgsinntekter: 0, andre_driftsinntekter: 0

    @type t :: %__MODULE__{
            salgsinntekter: integer(),
            andre_driftsinntekter: integer()
          }

    def sum(%__MODULE__{} = d), do: d.salgsinntekter + d.andre_driftsinntekter
  end

  defmodule Driftskostnader do
    @moduledoc "Operating costs."
    defstruct loennskostnader: 0, avskrivninger: 0, andre_driftskostnader: 0

    @type t :: %__MODULE__{
            loennskostnader: integer(),
            avskrivninger: integer(),
            andre_driftskostnader: integer()
          }

    def sum(%__MODULE__{} = d),
      do: d.loennskostnader + d.avskrivninger + d.andre_driftskostnader
  end

  defmodule Finansposter do
    @moduledoc "Financial items."
    defstruct utbytte_fra_datterselskap: 0,
              andre_finansinntekter: 0,
              rentekostnader: 0,
              andre_finanskostnader: 0

    @type t :: %__MODULE__{
            utbytte_fra_datterselskap: integer(),
            andre_finansinntekter: integer(),
            rentekostnader: integer(),
            andre_finanskostnader: integer()
          }

    def sum_inntekter(%__MODULE__{} = f),
      do: f.utbytte_fra_datterselskap + f.andre_finansinntekter

    def sum_kostnader(%__MODULE__{} = f),
      do: f.rentekostnader + f.andre_finanskostnader
  end

  defmodule Resultatregnskap do
    @moduledoc "Income statement."
    alias Wenche.Models.{Driftsinntekter, Driftskostnader, Finansposter}

    defstruct driftsinntekter: %Driftsinntekter{},
              driftskostnader: %Driftskostnader{},
              finansposter: %Finansposter{}

    @type t :: %__MODULE__{
            driftsinntekter: Driftsinntekter.t(),
            driftskostnader: Driftskostnader.t(),
            finansposter: Finansposter.t()
          }

    def driftsresultat(%__MODULE__{} = r),
      do: Driftsinntekter.sum(r.driftsinntekter) - Driftskostnader.sum(r.driftskostnader)

    def resultat_foer_skatt(%__MODULE__{} = r) do
      driftsresultat(r) +
        Finansposter.sum_inntekter(r.finansposter) -
        Finansposter.sum_kostnader(r.finansposter)
    end

    # For holding companies without taxable income, tax cost = 0
    def aarsresultat(%__MODULE__{} = r), do: resultat_foer_skatt(r)
  end

  # ---------------------------------------------------------------------------
  # Balance sheet components
  # ---------------------------------------------------------------------------

  defmodule Anleggsmidler do
    @moduledoc "Non-current assets."
    defstruct aksjer_i_datterselskap: 0, andre_aksjer: 0, langsiktige_fordringer: 0

    @type t :: %__MODULE__{
            aksjer_i_datterselskap: integer(),
            andre_aksjer: integer(),
            langsiktige_fordringer: integer()
          }

    def sum(%__MODULE__{} = a),
      do: a.aksjer_i_datterselskap + a.andre_aksjer + a.langsiktige_fordringer
  end

  defmodule Omloepmidler do
    @moduledoc "Current assets."
    defstruct kortsiktige_fordringer: 0, bankinnskudd: 0

    @type t :: %__MODULE__{
            kortsiktige_fordringer: integer(),
            bankinnskudd: integer()
          }

    def sum(%__MODULE__{} = o), do: o.kortsiktige_fordringer + o.bankinnskudd
  end

  defmodule Eiendeler do
    @moduledoc "Assets."
    alias Wenche.Models.{Anleggsmidler, Omloepmidler}

    defstruct anleggsmidler: %Anleggsmidler{}, omloepmidler: %Omloepmidler{}

    @type t :: %__MODULE__{
            anleggsmidler: Anleggsmidler.t(),
            omloepmidler: Omloepmidler.t()
          }

    def sum(%__MODULE__{} = e),
      do: Anleggsmidler.sum(e.anleggsmidler) + Omloepmidler.sum(e.omloepmidler)
  end

  defmodule Egenkapital do
    @moduledoc "Equity. annen_egenkapital can be negative for accumulated losses."
    defstruct aksjekapital: 0, overkursfond: 0, annen_egenkapital: 0

    @type t :: %__MODULE__{
            aksjekapital: integer(),
            overkursfond: integer(),
            annen_egenkapital: integer()
          }

    def sum(%__MODULE__{} = e), do: e.aksjekapital + e.overkursfond + e.annen_egenkapital
  end

  defmodule LangsiktigGjeld do
    @moduledoc "Long-term liabilities."
    defstruct laan_fra_aksjonaer: 0, andre_langsiktige_laan: 0

    @type t :: %__MODULE__{
            laan_fra_aksjonaer: integer(),
            andre_langsiktige_laan: integer()
          }

    def sum(%__MODULE__{} = l), do: l.laan_fra_aksjonaer + l.andre_langsiktige_laan
  end

  defmodule KortsiktigGjeld do
    @moduledoc "Short-term liabilities."
    defstruct leverandoergjeld: 0, skyldige_offentlige_avgifter: 0, annen_kortsiktig_gjeld: 0

    @type t :: %__MODULE__{
            leverandoergjeld: integer(),
            skyldige_offentlige_avgifter: integer(),
            annen_kortsiktig_gjeld: integer()
          }

    def sum(%__MODULE__{} = k),
      do: k.leverandoergjeld + k.skyldige_offentlige_avgifter + k.annen_kortsiktig_gjeld
  end

  defmodule EgenkapitalOgGjeld do
    @moduledoc "Equity and liabilities."
    alias Wenche.Models.{Egenkapital, LangsiktigGjeld, KortsiktigGjeld}

    defstruct egenkapital: %Egenkapital{},
              langsiktig_gjeld: %LangsiktigGjeld{},
              kortsiktig_gjeld: %KortsiktigGjeld{}

    @type t :: %__MODULE__{
            egenkapital: Egenkapital.t(),
            langsiktig_gjeld: LangsiktigGjeld.t(),
            kortsiktig_gjeld: KortsiktigGjeld.t()
          }

    def sum(%__MODULE__{} = e) do
      Egenkapital.sum(e.egenkapital) +
        LangsiktigGjeld.sum(e.langsiktig_gjeld) +
        KortsiktigGjeld.sum(e.kortsiktig_gjeld)
    end
  end

  defmodule Balanse do
    @moduledoc "Balance sheet."
    alias Wenche.Models.{Eiendeler, EgenkapitalOgGjeld}

    defstruct eiendeler: %Eiendeler{}, egenkapital_og_gjeld: %EgenkapitalOgGjeld{}

    @type t :: %__MODULE__{
            eiendeler: Eiendeler.t(),
            egenkapital_og_gjeld: EgenkapitalOgGjeld.t()
          }

    def er_i_balanse?(%__MODULE__{} = b),
      do: Eiendeler.sum(b.eiendeler) == EgenkapitalOgGjeld.sum(b.egenkapital_og_gjeld)

    def differanse(%__MODULE__{} = b),
      do: Eiendeler.sum(b.eiendeler) - EgenkapitalOgGjeld.sum(b.egenkapital_og_gjeld)
  end

  # ---------------------------------------------------------------------------
  # Annual accounts
  # ---------------------------------------------------------------------------

  defmodule Aarsregnskap do
    @moduledoc "Full annual accounts."
    alias Wenche.Models.{Selskap, Resultatregnskap, Balanse}

    defstruct [
      :selskap,
      :regnskapsaar,
      :resultatregnskap,
      :balanse,
      :fastsettelsesdato,
      :signatar,
      revideres: false,
      foregaaende_aar_resultat: %Resultatregnskap{},
      foregaaende_aar_balanse: %Balanse{},
      utbytte_utbetalt: 0
    ]

    @type t :: %__MODULE__{
            selskap: Selskap.t(),
            regnskapsaar: integer(),
            resultatregnskap: Resultatregnskap.t(),
            balanse: Balanse.t(),
            fastsettelsesdato: Date.t() | nil,
            signatar: String.t() | nil,
            revideres: boolean(),
            foregaaende_aar_resultat: Resultatregnskap.t(),
            foregaaende_aar_balanse: Balanse.t(),
            utbytte_utbetalt: integer()
          }
  end

  # ---------------------------------------------------------------------------
  # Shareholder register
  # ---------------------------------------------------------------------------

  defmodule Aksjonaer do
    @moduledoc "Individual shareholder."
    defstruct [
      :navn,
      :fodselsnummer,
      :antall_aksjer,
      :aksjeklasse,
      :utbytte_utbetalt,
      :innbetalt_kapital_per_aksje
    ]

    @type t :: %__MODULE__{
            navn: String.t(),
            fodselsnummer: String.t(),
            antall_aksjer: integer(),
            aksjeklasse: String.t(),
            utbytte_utbetalt: integer(),
            innbetalt_kapital_per_aksje: integer()
          }
  end

  defmodule Aksjonaerregisteroppgave do
    @moduledoc "Shareholder register submission (RF-1086)."
    alias Wenche.Models.{Selskap, Aksjonaer}

    defstruct [:selskap, :regnskapsaar, aksjonaerer: []]

    @type t :: %__MODULE__{
            selskap: Selskap.t(),
            regnskapsaar: integer(),
            aksjonaerer: [Aksjonaer.t()]
          }

    def totalt_antall_aksjer(%__MODULE__{} = o),
      do: Enum.reduce(o.aksjonaerer, 0, fn a, acc -> acc + a.antall_aksjer end)

    def totalt_utbytte_utbetalt(%__MODULE__{} = o),
      do: Enum.reduce(o.aksjonaerer, 0, fn a, acc -> acc + (a.utbytte_utbetalt || 0) end)
  end

  # ---------------------------------------------------------------------------
  # Tax return configuration
  # ---------------------------------------------------------------------------

  defmodule SkattemeldingKonfig do
    @moduledoc "Tax return configuration."
    defstruct underskudd_til_fremfoering: 0,
              anvend_fritaksmetoden: true,
              eierandel_datterselskap: 100

    @type t :: %__MODULE__{
            underskudd_til_fremfoering: integer(),
            anvend_fritaksmetoden: boolean(),
            eierandel_datterselskap: integer()
          }
  end
end
