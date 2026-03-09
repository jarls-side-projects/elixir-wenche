defmodule Wenche do
  @moduledoc """
  Elixir library for Norwegian small business filings.

  Ported from the Python CLI tool [Wenche](https://github.com/jarlah/Wenche).

  ## Modules

  - `Wenche.Maskinporten` — JWT-based authentication against Maskinporten + Altinn token exchange
  - `Wenche.AltinnClient` — Altinn 3 platform API client (instances, data upload, completion)
  - `Wenche.BrgXml` — BRG annual statement XML generation (hovedskjema/underskjema)
  - `Wenche.Ixbrl` — Inline XBRL (iXBRL) HTML document generation
  - `Wenche.Skattemelding` — Tax calculation with fritaksmetoden support
  - `Wenche.Aksjonaerregister` — RF-1086 shareholder register XML generation
  """
end
