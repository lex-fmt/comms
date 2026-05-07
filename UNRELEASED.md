<!-- Release notes for the next version. -->
<!-- Updated as work is done; consumed by scripts/create-release. -->

### Changed

- `shared/theming/lex-theme.json`: reference inlines (`Reference`,
  `ReferenceCitation`, `ReferenceFootnote`, `ReferenceAnnotation`) now
  use **bold** instead of underline. Underline reads as "follow this
  link" in most editor themes and was producing a heavy visual
  treatment for what is structurally just a typed inline span. Bold
  matches the way references read in printed text and avoids confusion
  with LSP-driven `documentLink` decorations (which editors render as
  underline and reserve for clickable URL/file targets). Per-editor
  theme files are regenerated from this canonical source via each
  editor's `scripts/gen-theme.py`.
