Document Title

    The document title is a first-class element that identifies the document. Unlike other elements which live inside sessions, the document title exists at the document level and is parsed as its own AST node.

    1. Grammar

        <document-title> = <title-line> <subtitle-line>? <blank-line>+
        <title-line> = <text-span> <colon>? <line-break>
        <subtitle-line> = <text-span> <line-break>

        A document title may optionally include a subtitle. When the title line ends with a colon, and a second non-blank, non-indented line follows before the blank-line separator, the first line is the title and the second line is the subtitle. The colon at the end of the title line is structural, not part of the title content.

    2. Rules

        1. Must be the first non-annotation element in the document.
        2. Must be followed by at least one blank line.
        3. Must not be indented.
        4. Must not be followed by indented content (which would make it a session title).
        5. The title line supports inline formatting (bold, emphasis, code, references).
        6. A single line without a trailing colon is a title with no subtitle (the common case).
        7. A line ending with a colon followed by a second line before the blank separator is a title with subtitle.
        8. A line ending with a colon followed directly by a blank line (no second line) is a plain title whose content includes the colon.
        9. Inline formatting is supported in both title and subtitle.

    3. Disambiguation

        The document title occupies the same syntactic position as a session title or a leading paragraph. The parser distinguishes them as follows:

        Single line + blank line + indented content:
            Session. The indented content is the session's body.

        Single line + blank line + no indented content:
            Document title. The line is promoted to a DocumentTitle node.

        Single line + no blank line (continuation):
            Paragraph. The line is part of a multi-line paragraph.

        The negative lookahead for indented content after the blank line is the key distinguishing rule.

        Title vs. subtitle depends on the combination of trailing colon and the presence of a second line:

        Trailing colon + second line before blank:
            Title with subtitle. The colon is stripped from the title content; the second line becomes the subtitle.

        Trailing colon + blank line immediately after:
            Plain title. The colon is part of the title content. No subtitle.

        No trailing colon:
            Plain title. No subtitle, regardless of what follows.

        This means "Warning: Do Not Enter" is always a plain title (colon is mid-line), and "My Title:" followed by "The Subtitle" on the next line is always a title with subtitle.

    4. AST Representation

        The document title is represented as a dedicated `DocumentTitle` AST node, owned directly by the `Document`:

        Document AST:
            ├── annotations (document-level)
            ├── title: DocumentTitle (optional)
            │   ├── content: TextContent (inline-parsed)
            │   └── subtitle: TextContent (optional, inline-parsed)
            └── root: Session (contains document body)
        :: tree ::

        The `DocumentTitle` node is distinct from session titles. It has its own type, enabling title-specific semantics and validation.

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

        Title with subtitle:
            My Document Title:
            A Closer Look at the Subject

            Content starts here.
        :: lex ::

        Title with subtitle and inline formatting:
            *Sapiens*:
            A Brief History of _Humankind_

            In the beginning, there were humans.
        :: lex ::

        Title ending with colon (no subtitle):
            Warning: Do Not Enter

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
