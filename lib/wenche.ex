defmodule Wenche do
  @moduledoc """
  Elixir library for Norwegian small business filings.

  Ported from the Python CLI tool [Wenche](https://github.com/olefredrik/Wenche).

  ## Modules

  ### Authentication
  - `Wenche.Maskinporten` — JWT-based authentication against Maskinporten + Altinn token exchange
  - `Wenche.Systembruker` — System user registration and management for Altinn 3

  ### Altinn API
  - `Wenche.AltinnClient` — Altinn 3 platform API client (instances, data upload, completion)

  ### Annual Accounts (Årsregnskap)
  - `Wenche.Aarsregnskap` — Annual accounts submission flow (config reading, validation, submission)
  - `Wenche.BrgXml` — BRG annual statement XML generation (hovedskjema/underskjema)
  - `Wenche.Ixbrl` — Inline XBRL (iXBRL) HTML document generation

  ### Tax Return (Skattemelding)
  - `Wenche.Skattemelding` — Tax calculation with fritaksmetoden (RF-1028/RF-1167)

  ### Shareholder Register (Aksjonærregister)
  - `Wenche.Aksjonaerregister` — RF-1086 shareholder register XML generation (Hovedskjema + Underskjema)
  - `Wenche.SkdClient` — SKD REST API client for aksjonærregisteroppgave submission

  ### Data Models
  - `Wenche.Models` — All data structures (Selskap, Aarsregnskap, Resultatregnskap, Balanse, etc.)
  """
end
