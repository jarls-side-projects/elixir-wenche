# Contributing

Thank you for considering contributing to Wenche!

## Development Setup

1. Clone the repository:

   ```bash
   git clone https://github.com/jarlah/elixir-wenche.git
   cd elixir-wenche
   ```

2. Install dependencies:

   ```bash
   mix deps.get
   ```

3. Run tests:

   ```bash
   MIX_ENV=test mix deps.compile req --force  # Required first time
   mix test
   ```

   The first command recompiles `req` with the `plug` test dependency available. This is only needed once after a fresh clone or after cleaning deps.

## Making Changes

1. Create a feature branch from `master`
2. Make your changes
3. Add tests for new functionality
4. Ensure all tests pass with `mix test`
5. Update `CHANGELOG.md` under the `[Unreleased]` section

## Changelog

All notable changes must be documented in `CHANGELOG.md`. Add your changes under the appropriate category:

- **Added** - New features
- **Changed** - Changes to existing functionality
- **Fixed** - Bug fixes
- **Deprecated** - Features that will be removed
- **Removed** - Removed features
- **Security** - Security fixes

## Pull Requests

1. Ensure tests pass
2. Update `CHANGELOG.md`
3. Write a clear PR description
4. Link any related issues

## Code Style

- Follow standard Elixir conventions
- Run `mix format` before committing
- Keep functions small and focused

## Questions?

Open an issue if you have questions or need help.
