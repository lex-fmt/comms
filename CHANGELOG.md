# Changelog

## v0.15.0 (2026-05-02)

### Added

- Canonical Lex monochrome theme published at `shared/theming/lex-theme.json`, with a `shared/theming/README.md` describing the schema, intensity/background tiers, and per-editor application semantics (including which editors can/cannot honor the optional background hint). Editor packages (nvim, lexed, vscode, zed) consume this file via `scripts/gen-theme.py` in their respective repos so theme rules and palettes are baked at generate time from a single source of truth. (#24)

### Changed

- Repo onboarded to the canonical lex-fmt CI standardization: added `.github/CODEOWNERS` and `.github/workflows/copilot-review.yml` to auto-trigger Copilot review on PRs. (#23)

## v0.14.1 (2026-04-25)

### Fixed

- `EDITORS.lex` footnote [4]: corrected the lex-lsp version that ships the "Add missing footnote definition" quickfix from v0.8.6 to v0.8.8 (lex-fmt/lex#463 merged after v0.8.6/v0.8.7 had already shipped).

## v0.14.0 (2026-04-24)

### Breaking

- Annotation reference syntax changed from `[^label]` to `[::label]` (split out from footnotes; `:: notes ::` now an explicit annotation list).

### Added

- New `:: notes ::` annotation spec, split from the footnotes spec; benchmark and spec samples updated to use `:: notes ::`.
- `footnotes.docs/` per-form sample set, including a `footnotes-12-table-scope-does-not-leak` test for table-scoped footnote resolution.
- Proposal: `Includes` feature (`:: lex.include src="..." ::`) for cross-file content composition.
- `EDITORS.lex` rewritten as the editor parity reference, tracking landed parity work (lex-fmt/lex#456) and reflecting the "Add missing footnote definition row" fix landing across all editors.
- Font ligatures and Unicode symbols documentation.
- Documented structural-parser escape rule in `escaping.lex` (lex-fmt/lex#451).
- Documented table cell nesting and non-terminal nature.
- Release infrastructure (`scripts/create-release`, `UNRELEASED.md`, CI workflow).

### Changed

- Spec cleanup: removed redundant `:: lex ::` verbatim wrappers.
