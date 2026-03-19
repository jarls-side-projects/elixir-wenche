# Agent Instructions

## Before Creating a PR

- Update `CHANGELOG.md` with your changes under an `## [Unreleased]` section
- Use the appropriate category: `Added`, `Changed`, `Fixed`, `Deprecated`, `Removed`, `Security`
- Keep entries concise but descriptive

## When Pushing to a PR

- Ensure `CHANGELOG.md` is in sync with all changes in the PR
- Move entries to the correct version section if a release is being prepared
- Squash related changelog entries if they become redundant

## Changelog Format

```markdown
## [Unreleased]

### Added
- New feature description

### Changed
- Change description

### Fixed
- Bug fix description
```

## Release Process

1. Move all `[Unreleased]` entries to a new version section `[X.Y.Z] - YYYY-MM-DD`
2. Publish to Hex with `mix hex.publish`
3. Create a git tag: `git tag -a vX.Y.Z -m "Release X.Y.Z"`
