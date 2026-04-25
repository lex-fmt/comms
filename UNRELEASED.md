<!-- Release notes for the next version. -->
<!-- Updated as work is done; consumed by scripts/create-release. -->

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
