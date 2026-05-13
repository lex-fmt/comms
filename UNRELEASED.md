<!-- Release notes for the next version. -->
<!-- Updated as work is done; consumed by scripts/create-release. -->

### Changed

- `specs/proposals/lex-extension-wire.lex`: bump `wire_version` from `1` to `2`. Two breaking wire-AST changes plus one additive hook landed in the same revision; §6.1 documents the transition.
  - `table.align` (single string applied to every cell on the reverse codec) → `table.column_aligns` (array of string, one entry per column). The single-string form lost per-column alignment on round-trip.
  - Three new typed block kinds — `image`, `video`, `audio` — join the closed set. Before v2 these flowed through `verbatim` with the same data flattened into `params`, leaving `on_resolve` handlers for `lex.media.*` with no typed return shape that differed from their input.
  - New `on_format` hook documented at §4.8. The hook is the reverse of `on_resolve`: given a typed `WireNode` previously produced by `on_resolve`, the handler returns a `LexAnnotationOut` describing the Lex-source form. Implemented in the `lex-extension` Rust crate already; this revision backfills the spec to match.
