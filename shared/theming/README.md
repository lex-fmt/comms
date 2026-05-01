# Lex Monochrome Theme — Canonical Source

`lex-theme.json` is the single source of truth for the Lex monochrome theme. Each
editor repo (`vscode/`, `nvim/`, `lexed/`, `zed-lex/`) carries a `scripts/gen-theme.py`
that reads this file and emits an editor-native form. Generated files are checked
in; the generator's `--check` mode runs in pre-commit and CI to fail on stale output.

## Schema

```jsonc
{
  "version": 1,
  "intensities": {
    "<name>": { "light": "#rrggbb", "dark": "#rrggbb" }
  },
  "backgrounds": {
    "<name>": { "light": "#rrggbb", "dark": "#rrggbb" }
  },
  "tokens": {
    "<TokenId>": {
      "intensity": "<intensity name>",
      "styles":     ["bold" | "italic" | "underline", ...],   // optional
      "background": "<background name>"                         // optional
    }
  }
}
```

- **Token IDs** are the VSCode `semanticTokenTypes` IDs declared in
  `vscode/package.json`. The LSP server emits these names; nvim consumes
  them as `@lsp.type.<TokenId>`; lexed registers them as Monaco token names.
- **Zed** has no LSP-semantic-tokens hook and uses tree-sitter captures
  with a `.lex` suffix; its generator carries an inline
  capture → token-id mapping.
- **Intensity tiers** encode the visual hierarchy: `normal` is reader focus,
  `muted` is structural, `faint` is meta-information, `faintest` is barely
  visible (inline markers).
- **Styles** are an editor-neutral list. Generators translate to the
  target format (e.g., VSCode `"bold underline"`, Lua `bold = true,
  underline = true`).
- **Background** references a key in `backgrounds`. Currently only
  `VerbatimContent` uses one (`code_bg`). Editors that cannot apply a
  background via their syntax-highlighting mechanism silently ignore
  this hint:
  - nvim: applied via `bg = ...` on the highlight group.
  - lexed (Monaco): applied via the rule's `background` field.
  - vscode: ignored (semantic-token customization has no background).
  - zed: ignored (syntax override has no background).

## Workflow

1. Edit `lex-theme.json`.
2. In each editor repo: `python3 scripts/gen-theme.py` to regenerate.
3. Commit both `comms` (via submodule bump) and the regenerated file.
4. Pre-commit runs `gen-theme.py --check`; CI runs the same.

Do **not** hand-edit generated files. They will be overwritten on the next
regeneration and the drift will fail CI.
