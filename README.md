# Lex Comms

Specs, documentation, and assets for [Lex](https://github.com/lex-fmt/lex) — a plain-text format for structured documents.

**[lex.ing](https://lex.ing)** — project site.

## Contents

- `specs/` — grammar specifications and test fixtures
  - `grammar-core.lex`, `grammar-line.lex`, `grammar-inline.lex` — the format spec
  - `elements/` — per-element test fixtures
  - `trifecta/` — integration test fixtures
  - `benchmark/` — real-world document fixtures
- `docs/` — website content for [lex.ing](https://lex.ing) (source for the deployed site)
- `assets/` — images and resources

## Usage

This repo is submoduled as `comms/` by all Lex repos:

- [`lex-fmt/lex`](https://github.com/lex-fmt/lex) — Rust workspace (parser, LSP, CLI)
- [`lex-fmt/vscode`](https://github.com/lex-fmt/vscode) — VS Code extension
- [`lex-fmt/nvim`](https://github.com/lex-fmt/nvim) — Neovim plugin
- [`lex-fmt/lexed`](https://github.com/lex-fmt/lexed) — Desktop editor

## License

MIT
