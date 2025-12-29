Lex Project Overview
====================

Lex is a plain text format for structured documents. This repository contains
multiple crates and packages organized as follows:


Directory Structure
-------------------

core/           lex-parser (Rust crate)
editors/        Editor support crates
  lex-lsp/        LSP server
  lex-analysis/   Document analysis library
tools/          CLI and format conversion
  lex-cli/        Command-line interface
  lex-babel/      Format interoperability library
  lex-config/     Configuration loader
lexed/          Standalone desktop editor (Electron)
nvim/           Neovim plugin (Lua)
vscode/         VSCode extension (TypeScript)
comms/          Specifications and documentation


Component Details
-----------------

CORE (core/)

  The lex-parser crate. Transforms Lex source text into an AST.

  Pipeline stages:
    1. Lexing     - Tokenization, semantic indentation, line classification
    2. Tree       - Hierarchical LineContainer structure
    3. Parsing    - Pattern-based semantic analysis producing IR nodes
    4. Building   - AST construction with location tracking
    5. Assembly   - Annotation attachment and reference resolution

  Key modules:
    src/lex/lexing.rs    Token and line processing
    src/lex/parsing.rs   Pattern-based parser
    src/lex/ast.rs       AST node definitions
    src/lex/testing.rs   Testing conventions and fixtures


EDITORS (editors/)

  lex-lsp/ - Language Server Protocol implementation

    Built on tower-lsp. Provides language intelligence to any LSP client.

    Features:
      - Semantic tokens (syntax highlighting)
      - Document symbols (outline/structure)
      - Hover information (footnote/citation preview)
      - Folding ranges
      - Go to definition / Find references
      - Document links
      - Formatting

    Architecture:
      - LSP Layer: JSON-RPC communication, protocol handling
      - Server Layer: Implements LanguageServer trait, thin coordinator
      - Feature Layer: Stateless operations on Lex AST

    Key files:
      src/lib.rs          Module overview and design decisions
      src/server.rs       LanguageServer trait implementation
      src/features/       Individual feature implementations

  lex-analysis/ - Document analysis library

    Stateless semantic analysis for Lex documents. Used by lex-lsp but
    designed to be reusable by CLI tools and other applications.

    Modules:
      semantic_tokens     Token extraction and classification
      document_symbols    Document structure and hierarchy
      hover               Preview text for tooltips
      go_to_definition    Reference resolution
      references          Find all references
      folding_ranges      Foldable regions
      completion          Autocompletion candidates


TOOLS (tools/)

  lex-cli/ - Command-line interface

    Usage:
      lex <file> --to <format>           Convert between formats
      lex inspect <file> [transform]     View internal representations
      lex format <file>                  Format lex document
      lex element-at <file> <row> <col>  Find element at position

    Transforms: ast-treeviz, ast-tag, ast-json, token-core-json, ir-json
    Formats: lex, markdown, html, pdf

  lex-babel/ - Format interoperability

    Converts between Lex and other document formats.

    Architecture:
      - IR layer: Format-agnostic intermediate representation
      - Common layer: Shared flat-to-nested and nested-to-flat algorithms
      - Format layer: Format-specific adapters (never parse/serialize directly)

    Supported formats:
      - Markdown (bidirectional)
      - HTML (export)
      - XML (export)
      - PDF (export)

    Key files:
      ir/             Intermediate representation types
      common/         Core conversion algorithms
      formats/        Format-specific implementations
      format.rs       Format trait definition

  lex-config/ - Configuration loader

    Loads and merges configuration from lex.toml files.
    Embeds defaults and supports layered overrides.


LEXED (lexed/)

  Standalone desktop editor for Lex documents.

  Stack: Electron + React + TypeScript + Monaco Editor

  Architecture:
    - Renderer: React UI with Monaco editor
    - Main: Electron process managing lex-lsp child process
    - LSP: Communication via stdin/stdout with JSON-RPC

  Key features:
    - Monochrome theme (typography-focused, distraction-free)
    - Semantic highlighting via LSP
    - Multi-pane editing
    - Vim mode support

  Key paths:
    src/            React components and editor logic
    electron/       Main process (window management, LSP bridge)
    shared/         Shared types between renderer and main


NVIM (nvim/)

  Neovim plugin providing Lex language support.

  Features:
    - LSP integration via nvim-lspconfig
    - Semantic token highlighting
    - Monochrome theme (or native theme option)
    - Auto-downloads lex-lsp binary

  Key files:
    lua/lex/init.lua      Entry point and setup
    lua/lex/theme.lua     Highlight group definitions
    lua/lex/binary.lua    Binary download management


VSCODE (vscode/)

  VSCode extension for Lex documents.

  Features:
    - LSP client connecting to lex-lsp
    - Semantic tokens, symbols, hover, folding
    - Export commands (Markdown, HTML, PDF)
    - Import from Markdown
    - Live HTML preview
    - Monochrome theme

  Key files:
    src/main.ts           Extension activation
    src/theme.ts          Theme implementation
    src/commands.ts       Export/import commands
    src/preview.ts        Live preview panel


COMMS (comms/)

  Specifications and documentation.

  specs/            Lex grammar specifications and test fixtures
    grammar-core.lex    Core syntax rules
    grammar-inline.lex  Inline formatting rules
    grammar-line.lex    Line-level rules
    elements/           Individual element test files
    trifecta/           Comprehensive test fixtures
    benchmark/          Performance test files

  docs/             Website content (Jekyll)
  assets/           Images and resources


Dependency Flow
---------------

                    comms/specs
                         |
                         v
  core (lex-parser) <----+
         |
         +----------------------+
         |                      |
         v                      v
  editors/lex-analysis    tools/lex-babel
         |                      |
         v                      v
  editors/lex-lsp         tools/lex-cli
         |                      |
         +---------+------------+
                   |
    +--------------+--------------+
    |              |              |
    v              v              v
  lexed          nvim          vscode


Testing Conventions
-------------------

All crates use official sample files from comms/specs for tests:
  - kitchensink: Comprehensive document with all features
  - trifecta: Three focused test files covering edge cases
  - elements/: Isolated tests for individual Lex elements

Tests load fixtures via the testing module in lex-parser.
