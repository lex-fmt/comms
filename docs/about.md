---
layout: default
title: About
---

# About lex

lex is a plain text document format for structured documents. It combines the simplicity of plain text with the power of hierarchical, parsable markup.

## The Format

lex documents use indentation and minimal markers to define structure. The syntax is designed to be "invisible" - you focus on ideas, not formatting.

### Core Elements

**Sessions** - Hierarchical sections with numbered titles:
```
1. Introduction

    Content indented under the title belongs to this section.

    1.1. Subsection

        Nested content at deeper levels.
```

**Definitions** - Term and explanation pairs:
```
Term:
    The definition follows immediately after the colon,
    indented one level.
```

**Lists** - Ordered and unordered:
```
- Unordered item
- Another item

1. Ordered item
2. Another ordered item
    a. Nested alphabetical
    b. Another nested
```

**Verbatim Blocks** - Code and non-lex content:
```
Example Code:
    function hello() {
        return "world";
    }
:: javascript
```

**Annotations** - Metadata attached to content:
```
:: note :: This is a single-line annotation.

:: todo status=open ::
    This is a block annotation
    with multiple lines.
::
```

### Inline Formatting

- `*bold*` for strong emphasis
- `_italic_` for emphasis
- `` `code` `` for inline code
- `#math#` for mathematical notation
- `[reference]` for links, citations, footnotes

### Reference Types

- `[https://example.com]` - URLs
- `[@author2024]` - Citations
- `[42]` or `[^note]` - Footnotes
- `[#2.1]` - Section references
- `[./file.txt]` - File references
- `[TK-placeholder]` - Placeholders

## Implementation

The reference implementation is written in Rust:

| Crate | Description |
|-------|-------------|
| **lex-core** | Parser with five-phase pipeline |
| **lex-babel** | Format conversion (Markdown, HTML, PDF) |
| **lex-analysis** | Document analysis for editor features |
| **lex-lsp** | Language Server Protocol implementation |
| **lex-cli** | Command-line interface |
| **lex-config** | Configuration loader |

All crates are published to [crates.io](https://crates.io/search?q=lex-) under the lex-fmt organization.

## Design Principles

- **Invisible syntax**: Structure through indentation and plain text conventions
- **Graceful degradation**: Unparseable content becomes paragraphs, never errors
- **Complete lifecycle**: From quick notes to finished documents
- **Tool-friendly**: Unambiguous grammar for reliable parsing
- **Future-proof**: Plain Unicode text, no proprietary formats

## License

lex is open source. See the individual repositories for license details.
