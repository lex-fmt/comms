Proposal: The Table Element

    Tables are a native Lex element for structured, tabular data. They replace the current stopgap of markdown pipe tables inside verbatim blocks, gaining inline parsing, cell merging, multi-line cells, footnotes, and organizational hints while staying true to Lex's readability-first, minimal-syntax philosophy.

1. Motivation

    1.1 Pain Points Addressed

        The current stopgap (markdown tables in a `:: doc.table ::` verbatim block) inherits all of markdown's well-documented limitations. The most consistently reported, validated across extension ecosystems, user forums, and specification discussions:

        1. No cell spanning (colspan/rowspan). Merged cells are a pillar of tables. Every serious table format (AsciiDoc, rST, LaTeX, Typst, HTML) supports them. Their absence severely limits real-world usage.
        2. No multi-line cell content. Real tables often need wrapped text, lists, or structured content inside cells. Single-line-per-row forces unreadable long lines or HTML hacks.
        3. Tedious to create and maintain. ASCII-art alignment means editing one cell ripples through every row. Only tolerable with editor auto-formatting.
        4. No captions or titles. Essential for technical and scientific writing. Every major extension added this independently.
        5. No footnotes in cells. Even footnote-capable renderers typically break inside table cells.
        6. Only one header row. Multi-level grouped headers (Q1 spanning Jan/Feb/Mar) need multiple header rows.
        7. Separator line is busywork. The `|---|---|` line serves three functions (detection, header separation, alignment) that can all be solved differently.

    1.2 Design Goals

        - Reuse Lex's existing structural patterns (subject/content/closing-annotation).
        - Support cell spanning, multi-line cells, footnotes, and alignment hints.
        - Keep pipes as column delimiters (familiar, visual, proven).
        - Drop the mandatory separator line.
        - Inline-parse cell content (unlike verbatim, which preserves raw text).
        - Compose with existing Lex elements: references for footnotes, lists for footnote definitions.

2. Element Structure

    Tables follow the common element pattern (head / content / tail), structurally identical to verbatim blocks but with parsed content:

        <subject-line>
            <pipe-rows>
            <blank-line>?
            <footnote-list>?
        :: table <params>? ::
    :: structure ::

    subject-line:
        The table caption. Required. Ends with a colon, like definitions and verbatim blocks.

    pipe-rows:
        One or more lines of pipe-delimited cells, indented at +1 from the subject. This is the table data.

    footnote-list:
        An optional numbered list appearing after the last pipe row, separated by a blank line. Provides definitions for footnote references used in cell content.

    closing annotation:
        `:: table <params>? ::` at the same indentation level as the subject line. Required. The label `table` identifies this block as a table (as opposed to a verbatim block). Parameters carry organizational hints.

    2.1 Minimal Example

        Favorite Pets:
            | Person | Pet  |
            | Bob    | Cats |
            | Alice  | Dogs |
        :: table ::
    :: lex ::

    2.2 Full Example

        Comparative Analysis of Retrieval Methods:
            | Method     | Precision [1] | Recall | F1 Score |
            | BM25       | 0.72          | 0.68   | 0.70     |
            | Dense      | >>            | 0.81   | 0.83     |
            | ^^         | >>            | 0.79   | 0.80     |
            | Hybrid [2] | 0.91          | 0.85   | 0.88     |

            1. Precision measured at k=10
            2. Weighted combination of BM25 and Dense, weights in [#3.2]
        :: table align=lccc ::
    :: lex ::

3. Rows and Cells

    3.1 Basic Syntax

        Each row is a pipe-delimited line. Leading and trailing pipes are required.

            | cell content | another cell | third cell |
        :: lex ::

        - Cells are delimited by `|`.
        - Cell content is trimmed of surrounding whitespace.
        - Empty cells are valid: `|  |` or `| |`.
        - Cell content supports all Lex inlines: `*bold*`, `_italic_`, `` `code` ``, `#math#`, `[references]`.

    3.2 Pipe Alignment

        Visual alignment of pipes across rows is not required by the parser. The formatter will auto-align pipes for readability. Authors are free to align or not.

        Both of these are valid and equivalent:

            | Name  | Score |
            | Alice | 95    |
        :: lex ::

            | Name | Score |
            | Alice | 95 |
        :: lex ::

4. Headers

    4.1 Default: First Row Is Header

        The first row (or first blank-line-delimited group in multi-line mode) is treated as the header. This is the overwhelmingly common case. No separator line is needed.

            | Name  | Age | City     |
            | Alice | 30  | New York |
            | Bob   | 25  | Paris    |
        :: lex ::

        The first row ("Name | Age | City") is the header. No `|---|` required.

    4.2 Multiple Header Rows

        Use `header=N` in the closing annotation parameters to designate N header rows:

            | Region | Q1     | >>     | >>     |
            | ^^     | Jan    | Feb    | Mar    |
            | North  | 10     | 20     | 30     |
            | South  | 15     | 25     | 35     |
        :: table header=2 ::
    :: lex ::

    4.3 No Header

        Use `header=0` for headerless tables:

            | Alice | 95 |
            | Bob   | 87 |
        :: table header=0 ::
    :: lex ::

5. Cell Merging

    Merge markers go in the *absorbed* cell, pointing back toward the content cell. The content always lives in the top-left cell of any merged region.

    5.1 Column Span (>>)

        `>>` as a cell's entire trimmed content means "I belong to my left neighbor."

            | Experiment Results | >>       | Control |
            | Temperature        | Pressure | pH      |
        :: lex ::

        "Experiment Results" spans 2 columns. The `>>` cell is absorbed into it.

        For wider spans, each absorbed column gets its own `>>`:

            | Full Width Title | >>       | >>       | >>       |
            | A                | B        | C        | D        |
        :: lex ::

        This preserves the column grid: every row has the same number of `|` delimiters, so columns always line up visually.

    5.2 Row Span (^^)

        `^^` as a cell's entire trimmed content means "I belong to my upper neighbor."

            | Category | Value |
            | Group A  | 10    |
            | ^^       | 20    |
            | Group B  | 30    |
        :: lex ::

        "Group A" spans 2 rows. The `^^` cell is absorbed into it.

    5.3 Combined Spans

        For rectangular merges, the top-left cell holds the content. Cells to its right in the first row use `>>`. Cells in subsequent rows use `^^`.

            | Merged | >>    | Other |
            | ^^     | ^^    | More  |
        :: lex ::

        This is a 2x2 merge. Chain resolution: cell(2,2) `^^` -> cell(1,2) `>>` -> cell(1,1) = "Merged". The merge region is always rectangular.

    5.4 Practical Example

            | Q1     | >>     | >>     | Q2     | >>     | >>     |
            | Jan    | Feb    | Mar    | Apr    | May    | Jun    |
            | Group  | 10     | 20     | 30     | 40     | 50     |
            | ^^     | 15     | 25     | 35     | 45     | 55     |
        :: table header=2 ::
    :: lex ::

        "Q1" spans 3 columns. "Q2" spans 3 columns. "Group" spans 2 rows.

    5.5 Literal >> and ^^ in Cells

        A cell whose *trimmed* content is exactly `>>` or `^^` is a merge marker. To use these as actual cell text, escape or quote them with an inline marker: `\>>`, `\^^`, `` `>>` `` or `` `^^` ``.

6. Multi-line Cells

    Multi-line cell content is enabled by using blank lines as row separators.

    6.1 Compact Mode (Default)

        When no blank lines appear between pipe rows, each pipe line is an independent row. This is the common case and requires zero overhead:

            Results:
                | Name  | Score |
                | Alice | 95    |
                | Bob   | 87    |
            :: table ::
        :: lex ::

    6.2 Multi-line Mode

        When blank lines appear between pipe groups, consecutive pipe lines within a group form a single row with multi-line cell content:

            Experiment Log:
                | Trial   | Conditions   | Result                |

                | Trial 1 | 20°C, pH 7.2 | Successful growth     |
                |         |              | observed after 48hrs. |

                | Trial 2 | 25°C, pH 6.8 | No growth detected.   |
            :: table ::
        :: lex ::

        Rules:
        - Each blank-line-delimited group of pipe lines forms one row.
        - Within a group, each line contributes text to the corresponding cell (joined with a line break).
        - A cell that is whitespace-only in a continuation line adds nothing to that cell.
        - The header is the first group (before the first blank line).

    6.3 Detection

        Auto-detected based on structure: if any blank lines appear between pipe groups, the table is in multi-line mode. No flags or mode switches needed.

        Mixing is valid: a table where some rows have blank lines between them and others don't. Each blank-line-delimited group is a row, and consecutive pipe lines within a group are continuations.

    6.4 Multi-line and Merge Interaction

        Merge markers (`>>`, `^^`) apply at the row level, not the continuation level. A cell whose content is `^^` across all its continuation lines is a row-span merge. A cell that has `^^` on its first line and additional text on continuation lines is a merge, the continuation text is ignored for the absorbed cell.

        In practice, merge markers should appear alone in their cell without continuations, which is the natural and readable form.

7. Organizational Hints (Parameters)

    Lex draws a hard line between semantic elements and presentation. However, certain table properties are neither cosmetic nor semantic in the traditional sense: they are *organizational*, helping the data be readable and usable. Column alignment is the prime example: centering a "Score" column isn't about looks, it's about data readability.

    These hints live in the closing annotation parameters, outside the content.

    7.1 Column Alignment

        The `align` parameter uses a one-character-per-column shorthand, inspired by LaTeX's `{lcr}` column specification:

        - `l` = left (default)
        - `c` = center
        - `r` = right

            :: table align=lcr ::
        :: lex ::

        This means: first column left, second center, third right. If fewer characters than columns, remaining columns default to left.

        This format is compact, non-fragile (no column numbering), reads left-to-right matching the visual table, and is proven across decades of use in LaTeX.

    7.2 Header Count

        The `header` parameter controls how many rows are treated as headers:

        - `header=1` (default): first row is header
        - `header=0`: no header
        - `header=2`: first two rows are headers

    7.3 Future Parameters

        The parameter mechanism is already general-purpose. Additional organizational hints can be added in future versions without syntax changes. Potential candidates include footer rows (`footer=1`) and column width ratios (`widths=1,2,1`). These are not part of this proposal.

8. Footnotes

    Table footnotes compose two existing Lex features: numbered footnote references (`[1]`, `[2]`) in cell content, and numbered lists for footnote definitions.

    8.1 Syntax

        Footnote references use standard Lex numbered reference syntax inside cell content. Footnote definitions are a numbered list placed after the last pipe row, separated by a blank line, inside the table block:

            Survey Results:
                | Method     | Accuracy [1] | Speed [2] |
                | Approach A | 94.2%        | 120ms     |
                | Approach B | 91.7%        | 45ms      |

                1. Measured on the test split, 10-fold cross-validated
                2. Median latency, p99 was 3x higher for Approach A
            :: table align=lcc ::
        :: lex ::

    8.2 Scoping

        Footnote references inside a table block are table-scoped: they resolve to the footnote list within the same table block, not to document-level footnotes. This is determined structurally by co-occurrence inside the table element.

    8.3 No New Syntax

        This approach introduces zero new syntax. It reuses existing Lex references and lists, with scoping determined by element structure. The `[t1]` prefix proposed in early brainstorming is not needed.

9. Separator Lines

    Lines matching a separator pattern (pipes enclosing only dashes, colons, equals signs, and spaces) are recognized and ignored by the parser. They are cosmetic, never required, always optional.

        | Name  | Score |
        |-------|-------|
        | Alice | 95    |
    :: lex ::

    This eases migration from markdown and allows authors to include visual separators for readability when they prefer them. The parser simply skips these lines during row extraction. No alignment information is derived from separator lines (alignment lives in the `align` parameter).

10. Parsing

    10.1 Detection and Precedence

        Tables use the same head/tail structure as verbatim blocks: subject line ending with colon, indented content, closing `:: label ::` annotation. The parser detects them at the verbatim matching stage.

        When the verbatim matcher encounters a closing annotation with label `table`, it creates a Table node instead of a Verbatim node. The inner content is parsed as table rows with inline parsing, rather than preserved as raw text.

        This keeps the parsing precedence order unchanged. Tables are detected at the verbatim stage (first in precedence), which is correct: both require a closing annotation, and the label determines the interpretation.

    10.2 Inline Parsing

        Cell content is inline-parsed, unlike verbatim content which is preserved raw. This happens at the same stage as paragraph inline parsing: after the block structure is established, each cell's text content is fed through the inline parser to resolve `*bold*`, `_italic_`, `` `code` ``, `#math#`, and `[references]`.

    10.3 Fullwidth Mode

        The existing verbatim fullwidth mode (content starts at column 2 instead of the normal +1 indentation) carries over to tables. Deeply-nested tables would otherwise lose too many columns to indentation. Detection works the same way: when the first non-blank content line starts at column 2, the table is in fullwidth mode.

    10.4 Grammar Rule

        The formal grammar for the table element:

            <table> = <subject-line> <blank-line>? <table-content> <footnote-section>? <closing-annotation>
            <table-content> = <indent> (<table-row> | <separator-line> | <blank-line>)+ <dedent>
            <table-row> = <pipe-line>+
            <pipe-line> = '|' (<cell-content> '|')+ <line-break>
            <cell-content> = <inline-content>*
            <separator-line> = '|' (<dash> | <colon> | <space> | '|')+ '|' <line-break>
            <footnote-section> = <blank-line> <list>
            <closing-annotation> = '::' <whitespace> 'table' (<whitespace> <parameters>)? <whitespace> '::'
        :: grammar ::

11. AST Representation

    The table element introduces a new AST node type. The IR already has `Table`, `TableRow`, and `TableCell` structures. These need to be extended with span fields:

        Table:
            subject (TextContent): the caption, inline-parsed
            rows (Vec<TableRow>): body rows
            header (Vec<TableRow>): header rows
            footnotes (Option<List>): footnote definitions
            annotations (Vec<Annotation>): attached annotations
            parameters: closing annotation parameters (align, header count, etc.)

        TableRow:
            cells (Vec<TableCell>): the cells in this row

        TableCell:
            content (Vec<InlineContent>): inline-parsed cell content
            colspan (usize): number of columns this cell spans (default 1)
            rowspan (usize): number of rows this cell spans (default 1)
            align (TableCellAlignment): Left | Center | Right | None
    :: structure ::

    Merge markers (`>>`, `^^`) are resolved during AST assembly: the content cell gets its colspan/rowspan incremented, and the absorbed cells are removed from the final AST. The serialized AST contains only content cells with their span counts.

12. Interop and Export

    12.1 HTML

        Tables export to standard HTML `<table>` elements with `<thead>`, `<tbody>`, `<th>`, `<td>`, `colspan`, `rowspan`, and `style="text-align: ..."` attributes. Footnotes render as a `<tfoot>` or an ordered list following the table, depending on export configuration.

    12.2 Markdown

        Since markdown lacks spanning and multi-line cells, export to markdown is lossy. The exporter produces GFM pipe tables with alignment markers, flattening spans and joining multi-line content. A comment annotation marks the loss.

    12.3 LaTeX

        Tables export to `tabular` environments with `\multicolumn` and `\multirow` for spans. Footnotes use `\tablefootnote` or equivalent. Alignment maps directly to LaTeX column specifiers.

13. Open Questions (Resolved)

    13.1 Multi-line + Merge Interaction

        Merge markers apply at the row level. A cell with `^^` on its first line and text on continuation lines is treated as a merge. The continuation text is ignored for absorbed cells. In practice, merge cells should contain only the marker with no continuations.

    13.2 Mixed Blank Line Presence

        Valid. Each blank-line-delimited group of pipe lines forms a row. A table can mix single-line rows and multi-line rows freely. The parser does not require uniform structure.

    13.3 Literal Merge Markers in Content

        To include literal `>>` or `^^` as cell text, escape them with a backslash (`\>>`, `\^^`) or wrap in an inline marker (`` `>>` ``, `` `^^` ``). Since the merge detection checks for exact trimmed content match, any inline marker prevents the match.

    13.4 Minimum Row Count

        Tables with a single row (just a header) are valid. Unlike lists which require 2+ items to distinguish from paragraphs, tables have an explicit closing annotation that unambiguously identifies them. Single-row tables are harmless and useful as placeholders during authoring.
