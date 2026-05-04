# Changelog

## v0.16.0 (2026-05-04)

### Added

- `specs/elements/lex.include.lex` — canonical reference for the `:: lex.include src="..." ::` annotation: syntax, resolution behaviour, root discovery, container policy, error surface, CLI/LSP integration, what's deliberately out of scope.
- `specs/elements/lex.include.docs/` — fixture set covering the canonical shapes (flat marker, relative path, root-absolute, multiple siblings, inside session, fragment include, quoted-with-escape).
- `specs/general.lex` §3.1 (Annotations) now formally reserves the `lex.*` annotation label prefix for core-defined semantics. Third-party tooling must not author labels in this namespace.

### Changed

- Includes proposal moved from `specs/proposals/includes.lex` to `specs/proposals/done/includes.lex` and prepended with a `:: status ::` annotation marking it as implemented and frozen — kept to preserve design rationale, but not the canonical documentation for the working code (which lives in `specs/elements/lex.include.lex`). This establishes the convention: implemented proposals move to `done/` rather than getting deleted.
- Includes proposal (`specs/proposals/done/includes.lex`) revised earlier in this cycle: splice into the parent container at the include site instead of into the include annotation's children slot (which conflicted with the `GeneralContainer` typed-content policy when the included file contained Sessions); resolver in `lex-core` with an injected `Loader`; included file's doc title and document-level annotations converted to a `Paragraph` and regular annotations rather than dropped (matching what a textual paste with indent-shift would produce); container-policy validation at splice time; root discovery via nearest `.lex.toml`. Implementation landed across `feat/includes/*` PRs in the lex repo over 10 PRs (release model B: batched foundation, then user-visible release, then LSP follow-ups).

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
