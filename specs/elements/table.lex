Tables

Introduction

	Tables are a native element for structured, tabular data. They use the same outer structure as verbatim blocks (subject line, indented content, closing annotation) but with inline-parsed pipe-delimited content instead of raw text.

	Tables support cell spanning (colspan and rowspan), multi-line cells, footnotes, and organizational hints (alignment, header count) while staying true to lex's readability-first, minimal-syntax philosophy.

Syntax

	Tables follow the common head / content / tail pattern:

		<subject-line>
		    <pipe-rows>
		    <blank-line>?
		    <footnote-list>?
		:: table <params>? ::
	:: structure ::

	Subject line:
		The table caption. Required. Ends with a colon, like definitions and verbatim blocks. The subject text is inline-parsed.

	Pipe rows:
		One or more lines of pipe-delimited cells, indented at +1 from the subject. Each row is a pipe-delimited line with leading and trailing pipes required.

	Footnote list:
		An optional numbered list appearing after the last pipe row, separated by a blank line. Provides definitions for footnote references used in cell content.

	Closing annotation:
		`:: table <params>? ::` at the same indentation level as the subject line. Required. The label `table` identifies this block as a table. Parameters carry organizational hints.

Rows and Cells

	Each row is a pipe-delimited line. Leading and trailing pipes are required:

		| cell content | another cell | third cell |
	:: lex ::

	Rules:
		- Cells are delimited by `|`.
		- Cell content is trimmed of surrounding whitespace.
		- Empty cells are valid: `|  |` or `| |`.
		- Cell content supports all lex inlines: `*bold*`, `_italic_`, `` `code` ``, `#math#`, `[references]`.

	Pipe Alignment:
		Visual alignment of pipes across rows is not required by the parser. The formatter auto-aligns pipes for readability. Both aligned and unaligned forms are valid and equivalent.

	Mismatched Row Lengths:
		If a row has fewer cells than the maximum column count, the parser pads the row with empty cells up to that maximum.

Headers

	Default: first row is header:
		The first row is treated as the header. No separator line is needed.

	Multiple header rows:
		Use `header=N` in the closing annotation parameters to designate N header rows.

	No header:
		Use `header=0` for headerless tables.

Cell Merging

	Merge markers go in the absorbed cell, pointing back toward the content cell. The content always lives in the top-left cell of any merged region.

	Column span (>>):
		`>>` as a cell's entire trimmed content means "belongs to left neighbor." Each absorbed column gets its own `>>`. This preserves the column grid: every row has the same number of `|` delimiters.

	Row span (^^):
		`^^` as a cell's entire trimmed content means "belongs to upper neighbor."

	Combined spans:
		For rectangular merges, the top-left cell holds the content. Cells to its right in the first row use `>>`. Cells in subsequent rows use `^^`.

	Literal >> and ^^:
		To use these as actual cell text, escape or quote them: `\>>`, `\^^`, `` `>>` `` or `` `^^` ``.

Multi-line Cells

	Multi-line cell content is enabled by using blank lines as row separators.

	Compact mode (default):
		When no blank lines appear between pipe rows, each pipe line is an independent row.

	Multi-line mode:
		When blank lines appear between pipe groups, consecutive pipe lines within a group form a single row with multi-line cell content. Each line contributes text to the corresponding cell, joined with a line break.

	Detection:
		Auto-detected based on structure. If any blank lines appear between pipe groups, the table is in multi-line mode. No flags or mode switches needed.

	The header is the first group (before the first blank line) in multi-line mode.

Organizational Hints (Parameters)

	These live in the closing annotation parameters, outside the content.

	Column alignment:
		The `align` parameter uses a one-character-per-column shorthand:
		- `l` = left (default)
		- `c` = center
		- `r` = right

		Example: `:: table align=lcr ::` means first column left, second center, third right. If fewer characters than columns, remaining columns default to left.

	Header count:
		The `header` parameter controls how many rows are treated as headers:
		- `header=1` (default): first row is header
		- `header=0`: no header
		- `header=2`: first two rows are headers

Footnotes

	Table footnotes compose two existing lex features: numbered footnote references in cell content and numbered lists for definitions.

	Footnote references use standard lex numbered reference syntax inside cell content. Definitions are a numbered list placed after the last pipe row, separated by a blank line, inside the table block:

		Survey Results:
		    | Method     | Accuracy [1] | Speed [2] |
		    | Approach A | 94.2%        | 120ms     |
		    | Approach B | 91.7%        | 45ms      |

		    1. Measured on the test split, 10-fold cross-validated
		    2. Median latency, p99 was 3x higher for Approach A
		:: table align=lcc ::
	:: lex ::

	Footnote references inside a table block are table-scoped: they resolve to the footnote list within the same table block.

Separator Lines

	Lines matching a separator pattern (pipes enclosing only dashes, colons, equals signs, and spaces) are recognized and ignored by the parser. They are cosmetic, never required, always optional.

		| Name  | Score |
		|-------|-------|
		| Alice | 95    |
	:: lex ::

	This eases migration from markdown. No alignment information is derived from separator lines; alignment lives in the `align` parameter.

The Indentation Wall

	Tables inherit the same indentation wall rules as verbatim blocks:

	In-flow mode:
		Content is indented relative to the subject line (subject column + 4 spaces). This is the normal case.

	Fullwidth mode:
		When indentation steals too much horizontal space, content can drop to a fixed, absolute wall at column 2 (zero-based index 1). The parser detects this automatically when the first non-blank content line starts at that column.

	The closing annotation stays aligned with the subject in both modes.

Disambiguation from Verbatim Blocks

	Tables and verbatim blocks share identical outer structure (subject line + indented content + closing annotation). The closing annotation label determines the interpretation:
	- Label `table` produces a Table node with inline-parsed pipe content.
	- Any other label produces a Verbatim node with raw preserved content.

	Detection happens at the verbatim matching stage. The parser attempts verbatim/table detection first in precedence order, which is correct: both require a closing annotation, and the label distinguishes them.

Examples

	Minimal table:
		- specs/elements/table.docs/table-01-flat-minimal.lex

	With alignment and footnotes:
		- specs/elements/table.docs/table-06-flat-with-footnotes.lex

	Cell merging:
		- specs/elements/table.docs/table-04-flat-cell-merging.lex

	Multi-line cells:
		- specs/elements/table.docs/table-05-flat-multiline.lex

	Nested in definition:
		- specs/elements/table.docs/table-08-nested-in-definition.lex

	Fullwidth mode:
		- specs/elements/table.docs/table-11-fullwidth.lex

Use Cases

	- Data comparison tables with alignment and spanning headers
	- API endpoint documentation with method, path, and description columns
	- Scientific results with footnoted measurements and multi-level headers
	- Configuration option tables with default values and descriptions
	- Migration from markdown pipe tables (separator lines accepted)

Implementation Notes

	Tables reuse the verbatim block's outer structure: subject line detection, indentation wall handling (in-flow and fullwidth), and closing annotation parsing. The key difference is that table content is inline-parsed rather than preserved raw.

	Merge markers (`>>`, `^^`) are resolved during AST assembly: the content cell gets its colspan/rowspan incremented, and the absorbed cells are removed from the final AST. The serialized AST contains only content cells with their span counts.

	The footnote section check operates on the raw text before inline parsing. If the raw text is exactly `\>>` or `\^^`, the structural span check ignores it; the escape is processed during subsequent inline parsing.
