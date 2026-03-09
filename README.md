# Wenche (Elixir)

Elixir library for Norwegian small business filings — Maskinporten authentication,
Altinn 3 API client, BRG XML/iXBRL generation, tax calculation, and shareholder
register XML generation.

Ported from the Python CLI tool [Wenche](https://github.com/olefredrik/Wenche).

## Modules

| Module | Description | Origin |
|---|---|---|
| `Wenche.Maskinporten` | JWT-based auth against Maskinporten + Altinn token exchange | `wenche/auth.py` |
| `Wenche.AltinnClient` | Altinn 3 API client (instances, data upload, completion) | `wenche/altinn_client.py` |
| `Wenche.BrgXml` | BRG annual statement XML (hovedskjema/underskjema) | `wenche/brg_xml.py` |
| `Wenche.Ixbrl` | Inline XBRL (iXBRL) HTML document generation | `wenche/xbrl.py` |
| `Wenche.Skattemelding` | Tax calculation with fritaksmetoden (RF-1028/RF-1167) | `wenche/skattemelding.py` |
| `Wenche.Aksjonaerregister` | RF-1086 shareholder register XML generation | `wenche/aksjonaerregister.py` |

## Installation

Add `wenche` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:wenche, "~> 0.1.0"}
  ]
end
```

## Usage

### Maskinporten Authentication

```elixir
config = [
  client_id: "your-client-id",
  kid: "your-key-id",
  private_key_pem: File.read!("maskinporten_privat.pem"),
  env: "prod"
]

{:ok, token} = Wenche.Maskinporten.get_altinn_token(config, "altinn:instances.read altinn:instances.write")
```

### Submitting Annual Statement

```elixir
# Build financial data (from your accounting system)
financial_data = %{
  year: 2025,
  resultatregnskap: %{
    driftsinntekter: Decimal.new("500000"),
    driftskostnader: Decimal.new("350000"),
    driftsresultat: Decimal.new("150000"),
    finansinntekter: Decimal.new("10000"),
    finanskostnader: Decimal.new("5000"),
    resultat_foer_skatt: Decimal.new("155000"),
    skattekostnad: Decimal.new("34100"),
    aarsresultat: Decimal.new("120900")
  },
  balanse: %{
    anleggsmidler: Decimal.new("200000"),
    omloepsmidler: Decimal.new("300000"),
    sum_eiendeler: Decimal.new("500000"),
    innskutt_egenkapital: Decimal.new("100000"),
    opptjent_egenkapital: Decimal.new("150000"),
    sum_egenkapital: Decimal.new("250000"),
    langsiktig_gjeld: Decimal.new("100000"),
    kortsiktig_gjeld: Decimal.new("150000"),
    sum_gjeld: Decimal.new("250000")
  }
}

company = %{org_number: "912345678", name: "Mitt Selskap AS"}

{:ok, hovedskjema} = Wenche.BrgXml.generate_hovedskjema(financial_data, company)
{:ok, underskjema} = Wenche.BrgXml.generate_underskjema(financial_data, company)
{:ok, ixbrl_html} = Wenche.Ixbrl.generate(financial_data, company)
```

### Tax Calculation

```elixir
calc = Wenche.Skattemelding.calculate_tax(financial_data, 22,
  apply_exemption_method: true,
  subsidiary_dividends: Decimal.new("100000")
)

report = Wenche.Skattemelding.format_report(2025, company, calc)
```

### Shareholder Register (RF-1086)

```elixir
shareholders = [
  %{
    fodselsnummer: "12345678901",
    name: "Ola Nordmann",
    antall_aksjer: 100,
    aksjeklasse: "A",
    utbytte_utbetalt: Decimal.new("50000"),
    innbetalt_kapital_per_aksje: Decimal.new("100")
  }
]

:ok = Wenche.Aksjonaerregister.validate_shareholders(shareholders)
xml = Wenche.Aksjonaerregister.generate_xml(2025, company, shareholders)
```

## License

MIT — see [LICENSE](LICENSE).

This project is an Elixir port of the Python tool
[Wenche](https://github.com/olefredrik/Wenche), originally licensed under the MIT License.
