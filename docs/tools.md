---
layout: default
title: Tools
---

# lex CLI

Command-line tool for converting, formatting, and inspecting lex documents.

## Installation

From source:
```bash
git clone https://github.com/lex-fmt/tools
cd tools
cargo build --release
# Binary at target/release/lex
```

## Commands

### Convert

Convert between document formats. This is the default command.

```bash
# Convert lex to markdown (output to stdout)
lex document.lex --to markdown

# Convert lex to HTML
lex document.lex --to html -o output.html

# Convert lex to PDF
lex document.lex --to pdf -o output.pdf

# Convert markdown to lex
lex document.md --to lex

# Explicit convert subcommand
lex convert document.lex --to html
```

The source format is auto-detected from the file extension. Use `--from` to override.

### Format

Format a lex document using standard formatting rules.

```bash
# Format to stdout
lex format document.lex

# Redirect to file
lex format document.lex > formatted.lex
```

### Inspect

View internal representations at different parsing stages. Useful for debugging and development.

```bash
# AST tree visualization (default)
lex inspect document.lex

# AST as XML-like tags
lex inspect document.lex ast-tag

# AST as JSON
lex inspect document.lex ast-json

# Token stream
lex inspect document.lex token-core-json

# Show all AST properties
lex inspect document.lex --extra-ast-full
```

Available transforms:
- `ast-treeviz` - Tree visualization (default)
- `ast-tag` - XML-like tag format
- `ast-json` - JSON output
- `ast-nodemap` - Character/color map
- `token-core-json` - Core tokens as JSON
- `token-line-json` - Line tokens as JSON
- `ir-json` - Intermediate representation

### Element At

Find the element at a specific position in a document.

```bash
# Get element at row 10, column 5
lex element-at document.lex 10 5

# Show all ancestors
lex element-at document.lex 10 5 --all
```

## Supported Formats

| Format | Import | Export | Extension |
|--------|:------:|:------:|-----------|
| lex | ✓ | ✓ | `.lex` |
| Markdown | ✓ | ✓ | `.md` |
| HTML | - | ✓ | `.html` |
| PDF | - | ✓ | `.pdf` |

## Configuration

The CLI reads configuration from `lex.toml` files. Use `--config` to specify an explicit path.

```bash
lex document.lex --to html --config ./my-lex.toml
```

### Format-Specific Options

Pass format-specific parameters with `--extra-<name>`:

```bash
# HTML with dark theme
lex document.lex --to html --extra-theme dark

# PDF with mobile page size
lex document.lex --to pdf --extra-size-mobile -o out.pdf

# Inspect with full AST properties
lex inspect document.lex --extra-ast-full
```

### Configuration File

Example `lex.toml`:

```toml
[formatting.rules]
session_blank_lines_before = 2
session_blank_lines_after = 1
normalize_seq_markers = true
indent_string = "    "

[convert.html]
theme = "default"

[convert.pdf]
size = "default"  # or "mobile" or "lexed"

[inspect.ast]
include_all_properties = false
show_line_numbers = true
```

## lex-babel Library

The conversion functionality is provided by the `lex-babel` crate, which can be used programmatically:

```rust
use lex_babel::FormatRegistry;

let registry = FormatRegistry::default();

// Parse from markdown
let doc = registry.parse(&markdown_source, "markdown")?;

// Serialize to HTML
let html = registry.serialize(&doc, "html")?;
```

The library architecture:
- **IR layer**: Format-agnostic intermediate representation
- **Common layer**: Shared flat-to-nested and nested-to-flat algorithms
- **Format layer**: Format-specific adapters

This design ensures consistent behavior across all format conversions.
