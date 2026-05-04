<!-- Release notes for the next version. -->
<!-- Updated as work is done; consumed by scripts/create-release. -->

### Added

- `specs/elements/lex.include.lex` — canonical reference for the `:: lex.include src="..." ::` annotation: syntax, resolution behaviour, root discovery, container policy, error surface, CLI/LSP integration, what's deliberately out of scope.
- `specs/elements/lex.include.docs/` — fixture set covering the canonical shapes (flat marker, relative path, root-absolute, multiple siblings, inside session, fragment include, quoted-with-escape).
- `specs/general.lex` §3.1 (Annotations) now formally reserves the `lex.*` annotation label prefix for core-defined semantics. Third-party tooling must not author labels in this namespace.

### Changed

- Includes proposal moved from `specs/proposals/includes.lex` to `specs/proposals/done/includes.lex` and prepended with a `:: status ::` annotation marking it as implemented and frozen — kept to preserve design rationale, but not the canonical documentation for the working code (which lives in `specs/elements/lex.include.lex`). This establishes the convention: implemented proposals move to `done/` rather than getting deleted.
- Includes proposal (`specs/proposals/done/includes.lex`) revised earlier in this cycle: splice into the parent container at the include site instead of into the include annotation's children slot (which conflicted with the `GeneralContainer` typed-content policy when the included file contained Sessions); resolver in `lex-core` with an injected `Loader`; included file's doc title and document-level annotations converted to a `Paragraph` and regular annotations rather than dropped (matching what a textual paste with indent-shift would produce); container-policy validation at splice time; root discovery via nearest `.lex.toml`. Implementation landed across `feat/includes/*` PRs in the lex repo over 10 PRs (release model B: batched foundation, then user-visible release, then LSP follow-ups).
