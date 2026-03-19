# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-03-19

### Fixed

- Corrected GitHub repository URL in package metadata

## [0.1.0] - 2026-03-19

Initial release. This is an Elixir port of [Wenche](https://github.com/olefredrik/Wenche) (Python).

### Added

- Maskinporten authentication with JWT token generation
- Altinn 3 API client for instance management and form submission
- System user registration and rights management
- Annual accounts (årsregnskap) submission to BRG
  - BRG XML generation
  - Inline XBRL (iXBRL) generation
  - Notes (noter) for small enterprises
- Tax calculation (skattemelding) for RF-1028/RF-1167
  - Standard corporate tax calculation
  - Participation exemption (fritaksmetoden)
- Shareholder register (aksjonærregister) for RF-1086
  - SKD REST API client
  - Support for personal and company shareholders
