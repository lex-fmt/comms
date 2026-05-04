<!-- Release notes for the next version. -->
<!-- Updated as work is done; consumed by scripts/create-release. -->

### Changed

- Includes proposal (`specs/proposals/includes.lex`) revised: splice into the parent container at the include site instead of into the include annotation's children slot (which conflicted with the `GeneralContainer` typed-content policy when the included file contained Sessions); resolver moved to `lex-core` (with an injected `Loader` so the crate itself does no filesystem I/O); included file's doc title and document-level annotations are converted to a `Paragraph` and regular annotations rather than dropped, matching what a textual paste with indent-shift would produce; container-policy validation at splice time; root discovery via nearest `lex.toml` walking upward from the entry-point document. Implementation will land across `feat/includes/*` PRs in the lex repo over 10 PRs (release model B: batched foundation, then user-visible release, then LSP follow-ups).
