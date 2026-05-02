<!-- Release notes for the next version. -->
<!-- Updated as work is done; consumed by scripts/create-release. -->

### Added

- Canonical Lex monochrome theme published at `shared/theming/lex-theme.json`, with a `shared/theming/README.md` describing the schema, intensity/background tiers, and per-editor application semantics (including which editors can/cannot honor the optional background hint). Editor packages (nvim, lexed, vscode, zed) consume this file via `scripts/gen-theme.py` in their respective repos so theme rules and palettes are baked at generate time from a single source of truth. (#24)

### Changed

- Repo onboarded to the canonical lex-fmt CI standardization: added `.github/CODEOWNERS` and `.github/workflows/copilot-review.yml` to auto-trigger Copilot review on PRs. (#23)
