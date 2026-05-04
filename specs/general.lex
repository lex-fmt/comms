The lex language

    lex is a lightweight plain text language designed to be a general idea format, that scales down to a single line up to full scientific publishing.

    lex aims to deliver rich functionality, being more expressive than HTML or markdown, while remaining human readable and writable in its raw form, without the need for specialized software.

    The core philosophy of lex is to prioritize human readability and writability, ensuring that documents remain accessible and easy to understand in their raw text form. In order to do this, lex leverages long ago stabilized conventions from publishing, some of which are a few centuries old, and builds on them to create a modern, versatile format.

    Structure is denoted through indentation.

1. General

    lex documents are utf-8 encoded plain text files with the file extension .lex.

    Blank lines are any line that has zero or more non-visible characters (spaces, tabs) and no other content.

    The language makes no assumptions about column width, line length, or page size. These are considered presentation details that are outside the scope of the language.

    The core syntax for the language is multi-line. That is, the same line contents in different groupings can vary in meaning. 
    
    All lexer stages emit tokens paired with their byte-range location (`start..end`). Locations are mandatory for every token, including semantic tokens such as Indent, Dedent, and BlankLine. Downstream tooling must preserve these spans.
     
2. Indentation
    
    An indentation step is represented by spaces in multiples of tab stops, which is 4 by default. Tabs are not recommended, but if used, count as 4 spaces.

    Since lex aims to be flexible and forgiving, lines that have space remainders (as in 10 spaces, which converts to 2 tab stops with 2 spaces remaining) will be parsed with no error. Only two indentation level tokens will be generated, and the remaining whitespaces will be considered part of the text.

3. Elements

    1. Annotations

        Annotations are metadata elements that provide structured non-content information such as author comments, build tool directives, and semantic markers.

	    Annotations are introduced by a :: data node (label + optional parameters) followed by a closing :: marker and optional content.

        Three forms exist: marker form (:: label ::), single-line form (:: label :: content), and block form (:: label :: \n indented content).

        Note: The block form has a single closing :: on the opening line. The indented content that follows is delimited by indentation (indent/dedent), not by a second :: marker.

        Annotation content can include paragraphs, lists, definitions, verbatim blocks, tables, and nested annotations, but cannot contain sessions.

        The `lex.*` annotation label prefix is reserved for core-defined semantics (e.g. `lex.include`, see specs/elements/lex.include.lex). Third-party tooling must not author labels in this namespace; the core may add new `lex.*` labels without coordinating with downstream. Non-reserved labels remain freely available for extensions (`mycompany.review`, `docs.embed`, etc.).

    2. Lists

        Lists are collections of at least two list items.

        List items can mix different decoration styles (remember, they are not content, but formatting). The list style is defined by the style of the first list item.

    3. Definitions

        Definitions consist of a subject line ending with a colon, immediately followed by indented content with no blank line between them.

        The subject line identifies what is being defined, while the indented content provides the definition or explanation.

        Definition content can include paragraphs, lists, nested definitions (recursive), verbatim blocks, tables, and annotations, but cannot contain sessions. This restriction ensures definitions remain focused explanatory units.

    4. Sessions

        Sessions contain a session title line, followed by at least one blank line, then at least one child content, which must be indented relative to the session title.

        Sessions can be arbitrarily nested, with the only requirement that they must have at least one item as content (aside from the title).

    5. Verbatim Blocks

        Verbatim blocks are used to embed non-lex content within a document, such as source code, or to reference binary data. They are analogous to Markdown's fenced code blocks but use indentation for delimitation.

        A verbatim block consists of a subject line, an optional block of raw/unparsed content, and a mandatory closing annotation.

        Two forms exist:
        - Block form (with text content): For embedding raw text like source code
        - Marker form (no content): For referencing external or binary data

    6. Tables

        Tables are a native element for structured, tabular data. They share the outer structure of verbatim blocks (subject line, indented content, closing annotation) but with inline-parsed pipe-delimited content.

        Tables support cell spanning (colspan via `>>`, rowspan via `^^`), multi-line cells (via blank-line-separated row groups), footnotes (scoped numbered lists), and organizational hints (alignment, header count) in the closing annotation parameters.

        The closing annotation label `table` distinguishes tables from verbatim blocks.

    7. Paragraphs

        Paragraphs are one or more consecutive non-blank lines that do not form another element.

        Paragraphs use look-ahead to detect element boundaries: they stop before list starts (2+ list-item-lines) and definition starts (subject-line + indent). This means blank lines between paragraphs and lists or definitions are optional.

        Paragraphs are also the catch-all: if text doesn't match any other element pattern, it's a paragraph. This makes lex forgiving — ambiguous content defaults to paragraph.
