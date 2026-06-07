defmodule Wenche.SkattemeldingPersonligXml do
  @moduledoc """
  XML generation for the **personlig** skattemelding (ENK — enkeltpersonforetak)
  submission to Skatteetaten.

  An ENK owner files a personal tax return. The business numbers go in the same
  `naeringsspesifikasjon` (v6) used for AS, but the outer document is the
  personlig skattemelding (`skattemelding` v13) rather than
  `skattemeldingUpersonlig`. Skatteetaten pre-fills the personal sections
  (bank, housing, employment); kontio only supplies the `naering` data via the
  næringsspesifikasjon, so the personlig shell here is intentionally minimal:
  `partsreferanse` + `inntektsaar`, which is all the XSD requires.

  Per `skattemelding_v13_ekstern.xsd`
  (`urn:no:skatteetaten:fastsetting:formueinntekt:skattemelding:ekstern:v13`,
  "Skattemelding personlige skattepliktige v13", income year 2025).

  The næringsspesifikasjon and request envelope are produced by
  `Wenche.SkattemeldingXml` with `skattepliktig_type: :personlig` and
  `skattemelding_dokumenttype: "skattemeldingPersonlig"` respectively — see
  `Wenche.SkattemeldingPersonlig` for the full orchestration.

  ## Partsreferanse

  `partsreferanse` is Skatteetaten's internal integer ID for the taxpayer. It
  must be fetched from the pre-filled draft API before generating the XML for
  actual submission. When called without `:partsreferanse`, the generator falls
  back to `aarsregnskap.selskap.org_nummer` as a placeholder (passes XSD
  validation, but Skatteetaten rejects the submission unless replaced with the
  real partsreferanse).
  """

  alias Wenche.Models.Aarsregnskap

  @skattemelding_ns "urn:no:skatteetaten:fastsetting:formueinntekt:skattemelding:ekstern:v13"

  @doc """
  Generates the personlig `skattemelding` XML document (v13).

  Minimal by design — `partsreferanse` + `inntektsaar`. The business detail
  lives in the næringsspesifikasjon; the remaining personal sections are
  pre-filled by Skatteetaten.

  ## Options

  - `:partsreferanse` — Skatteetaten's integer ID for the taxpayer. Defaults to
    `aarsregnskap.selskap.org_nummer`.
  """
  @spec generer_skattemelding_personlig_xml(Aarsregnskap.t(), keyword()) :: String.t()
  def generer_skattemelding_personlig_xml(%Aarsregnskap{} = regnskap, opts \\ []) do
    partsreferanse = Keyword.get(opts, :partsreferanse, regnskap.selskap.org_nummer)
    aar = regnskap.regnskapsaar

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <skattemelding xmlns="#{@skattemelding_ns}">
      <partsreferanse>#{partsreferanse}</partsreferanse>
      <inntektsaar>#{aar}</inntektsaar>
    </skattemelding>
    """
    |> String.trim()
  end

  @doc """
  Extracts the `partsreferanse` from a personlig skattemelding XML document.

  Used after fetching the pre-filled draft to learn Skatteetaten's internal ID
  for the taxpayer. The personlig draft uses `<partsreferanse>` where the
  upersonlig draft uses `<partsnummer>`.

  Returns `{:ok, integer}` or `{:error, :partsreferanse_not_found}`.
  """
  @spec hent_partsreferanse(binary()) :: {:ok, integer()} | {:error, :partsreferanse_not_found}
  def hent_partsreferanse(xml) when is_binary(xml) do
    case Regex.run(~r{<(?:\w+:)?partsreferanse[^>]*>\s*(\d+)\s*</(?:\w+:)?partsreferanse>}, xml) do
      [_, value] -> {:ok, String.to_integer(value)}
      _ -> {:error, :partsreferanse_not_found}
    end
  end
end
