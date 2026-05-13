<!-- Release notes for the next version. -->
<!-- Updated as work is done; consumed by scripts/create-release. -->

### Added

- `specs/general.lex` §4 — new top-level "Label Namespaces" section formalizes the label namespace model the language ships with. Four namespace classes: reserved-canonical (`lex.*`), reserved-forbidden (`doc.*`), blessed user-facing (bare names + prefix-stripped forms, aliased to `lex.*` via two rules), and community (`owner.repo`). §4.2 covers the prefix-strip and curated-shortcut alias rules, including the normative shortcut table (`table`, `image`, `video`, `audio`, `author`, `title`, `tags`, `date`, `include`). §4.3 documents the form-preserving roundtrip contract: parsers categorize each label site as Canonical/Stripped/Shortcut and formatters emit the same form back, so user choice survives every save. §4.5 sets the documentation voice: examples lead with the shortest accepted form. Supersedes the single-paragraph `lex.*` reservation that previously lived in §3.1.

### Changed

- `specs/general.lex` §3.1: the one-paragraph namespace reservation language now points to §4 for the full model; the substantive content moved there.
- `specs/elements/lex.include.lex`: intro paragraph names `include` as the user-facing shortcut (canonical `lex.include` mentioned once for wire transparency); example snippets switched from `:: lex.include src="..." ::` to `:: include src="..." ::` to match the new documentation voice.
- `specs/proposals/lex-extension-wire.lex`: bump `wire_version` from `1` to `2`. Two breaking wire-AST changes plus one additive hook landed in the same revision; §6.1 documents the transition.
  - `table.align` (single string applied to every cell on the reverse codec) → `table.column_aligns` (array of string, one entry per column). The single-string form lost per-column alignment on round-trip.
  - Three new typed block kinds — `image`, `video`, `audio` — join the closed set. Before v2 these flowed through `verbatim` with the same data flattened into `params`, leaving `on_resolve` handlers for `lex.media.*` with no typed return shape that differed from their input.
  - New `on_format` hook documented at §4.8. The hook is the reverse of `on_resolve`: given a typed `WireNode` previously produced by `on_resolve`, the handler returns a `LexAnnotationOut` describing the Lex-source form. Implemented in the `lex-extension` Rust crate already; this revision backfills the spec to match.
