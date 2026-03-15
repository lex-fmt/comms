Document Title

    The document title is a first-class element that identifies the document. Unlike other elements which live inside sessions, the document title exists at the document level and is parsed as its own AST node.

    1. Grammar

        <document-title> = <title-line> <blank-line>+
        <title-line> = <text-span> <line-break>

    2. Rules

        1. Must be the first non-annotation element in the document.
        2. Must be a single line of text.
        3. Must be followed by at least one blank line.
        4. Must not be indented.
        5. Must not be followed by indented content (which would make it a session title).
        6. The title line supports inline formatting (bold, emphasis, code, references).

    3. Disambiguation

        The document title occupies the same syntactic position as a session title or a leading paragraph. The parser distinguishes them as follows:

        Single line + blank line + indented content:
            Session. The indented content is the session's body.

        Single line + blank line + no indented content:
            Document title. The line is promoted to a DocumentTitle node.

        Single line + no blank line (continuation):
            Paragraph. The line is part of a multi-line paragraph.

        The negative lookahead for indented content after the blank line is the key distinguishing rule.

    4. AST Representation

        The document title is represented as a dedicated `DocumentTitle` AST node, owned directly by the `Document`:

        Document AST:
            ├── annotations (document-level)
            ├── title: DocumentTitle (optional)
            │   └── content: TextContent (inline-parsed)
            └── root: Session (contains document body)
        :: tree ::

        The `DocumentTitle` node is distinct from session titles. It has its own type, enabling title-specific semantics, validation, and future extensions (subtitles, structured metadata).

    5. Document-Level Annotations

        Document-level annotations may precede the title. These attach to the document itself, not to the title.

        :: author :: Ada Lovelace

        My Document Title

        Content begins here.
    :: lex ::

    6. Absent Title

        A document may have no title. This occurs when:
        - The document is empty.
        - The first element is a session (line + blank + indent).
        - The first element is a multi-line paragraph (no blank line after first line).
        - The first non-blank line is indented.

    7. Examples

        Explicit title:
            My Document Title

            Content starts here.
        :: lex ::

        Not a title (no blank line):
            Not a title
            Because no blank line follows.
        :: lex ::

        Not a title (becomes session):
            Session Title

                This indented content makes it a session, not a document title.
        :: lex ::

        Title with annotations before it:
            :: author :: Ada Lovelace

            Document With Metadata

            This document has a document-level annotation before the title.
        :: lex ::
