# Contributing

Lex is open source and contributions are welcome.

## Repository Structure

The project lives under the [lex-fmt](https://github.com/lex-fmt) organization:

| Repository | Description | Language |
|------------|-------------|----------|
| [lex](https://github.com/lex-fmt/lex) | Unified Rust workspace (parser, LSP, CLI, babel, analysis, config, wasm) | Rust |
| [comms](https://github.com/lex-fmt/comms) | Specs, docs, website | lex/Markdown |
| [lexed](https://github.com/lex-fmt/lexed) | Desktop editor | TypeScript/Electron |
| [vscode](https://github.com/lex-fmt/vscode) | VS Code extension | TypeScript |
| [nvim](https://github.com/lex-fmt/nvim) | Neovim plugin | Lua |

## Dependency Flow

```
                comms/specs
                     |
                     v
              lex-core (parser)
                     |
         +-----------+-----------+
         |                       |
         v                       v
  lex-analysis              lex-babel
         |                       |
         v                       v
      lex-lsp                 lex-cli
         |
    +----+----+----+
    |    |    |    |
    v    v    v    v
 lexed nvim vscode lex-wasm
```

## How to Contribute

1. **Find an issue** or propose a change in the relevant repository
2. **Fork** the repository
3. **Create a branch** for your changes
4. **Submit a PR** with passing tests

### Requirements

- All PRs must have passing tests
- Follow existing code style
- Update relevant documentation

## Development Setup

### Prerequisites

- Git
- Rust toolchain ([rustup.rs](https://rustup.rs))
- Node.js 20+ (for lexed, vscode)

### Clone

```bash
mkdir lex-fmt && cd lex-fmt
for repo in lex comms vscode nvim lexed; do
    gh repo clone lex-fmt/$repo
done
```

### Building

```bash
# All Rust crates
cd lex && cargo build --workspace

# Lexed
cd lexed && npm ci && npm run build

# VS Code extension
cd vscode && npm ci && npm run build
```

### Testing

```bash
# Rust crates
cd lex && cargo nextest run --workspace

# VS Code extension
cd vscode && npm test

# Lexed e2e tests
cd lexed && npm run test:e2e
```

## Local Development (Cross-Component Changes)

To use a local `lex-lsp` build with editor UIs:

```bash
cd lex && cargo build -p lex-lsp
```

Then point editors at the local binary:

```bash
# lexed
LEX_LSP_PATH=lex/target/debug/lex-lsp npm run dev --prefix lexed

# vscode (set before launching Extension Development Host)
export LEX_LSP_PATH="$(pwd)/lex/target/debug/lex-lsp"

# nvim
vim.g.lex_lsp_path = "/path/to/lex-fmt/lex/target/debug/lex-lsp"
```

## Testing Conventions

All crates use official sample files from `comms/specs/` for tests:

- **kitchensink**: Comprehensive document with all features
- **trifecta**: Three focused test files covering edge cases
- **elements/**: Isolated tests for individual lex elements

Tests load fixtures via the testing module in lex-core.

## Releasing

Tag the `lex` repo with `vX.Y.Z` and push. CI publishes crates in dependency order and builds binaries for 6 platforms:

```bash
cd lex && git tag v0.X.Y && git push --tags
```

Editor UIs download pre-built binaries from `lex-fmt/lex` releases. Update `shared/lex-deps.json` in each editor repo to pin to a new version.

## Questions?

Open an issue in the relevant repository or reach out on GitHub Discussions.
