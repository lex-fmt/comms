# Lex Monochrome Theme — Canonical Source

`lex-theme.json` is the single source of truth for the Lex monochrome theme. Each
editor repo (`vscode/`, `nvim/`, `lexed/`, `zed-lex/`) carries a `scripts/gen-theme.py`
that reads this file and emits an editor-native form. Generated files are checked
in; the generator's `--check` mode runs in pre-commit and CI to fail on stale output.

## Schema

Pseudo-schema (not literal JSON — annotations describe allowed values):

```text
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
      "intensity":   <intensity name>,
      "styles":      [<zero or more of: "bold", "italic", "underline">],   // optional
      "background":  <background name>                                     // optional
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

There are two contexts for working with this file. Pick the right one:

**Editing the canonical theme** (in this `comms` repo):

1. Edit `lex-theme.json` here.
2. Commit + push to `comms`. Open a PR if your repo workflow requires one.

**Consuming the canonical theme** (in any editor repo that submodules `comms`):

1. Bump the `comms` submodule pointer to a commit that has the change you want
   (`git -C comms pull origin main`, then commit the gitlink in the editor repo).
2. Run `python3 scripts/gen-theme.py` in that editor repo to regenerate.
3. Commit both the bumped submodule pointer and the regenerated file.
4. The editor repo's pre-commit hook and CI run `gen-theme.py --check` to
   guarantee the generated file matches the canonical at that submodule SHA.

Do **not** hand-edit generated files in any editor repo. They will be overwritten
on the next regeneration and the drift will fail CI.
