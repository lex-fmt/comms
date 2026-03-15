Document Title

    A document title is a single line of text at the very beginning of the document, followed by a blank line. It serves as the human-readable title for the entire file.

    <document-title> = <title-line> <subtitle-line>? <blank-line>
    <title-line> = <text-span> <line-break>
    <subtitle-line> = <text-span> <line-break>

    A document title may optionally include a subtitle. When the title line ends with a colon, and a second non-blank, non-indented line follows before the blank-line separator, the first line is the title and the second line is the subtitle. The colon at the end of the title line is structural, not part of the title content.

    Rules:
    1. Must be the first element in the document.
    2. Must be followed by at least one blank line.
    3. Must not be indented.
    4. A single line without a trailing colon is a title with no subtitle (the common case).
    5. A line ending with a colon followed by a second line before the blank separator is a title with subtitle.
    6. A line ending with a colon followed directly by a blank line (no second line) is a plain title whose content includes the colon.
    7. Inline formatting is supported in both title and subtitle.

    :: lex ::

    Example: Explicit Title
        My Document Title

        Content starts here.
    :: lex ::

    Example: Title with Subtitle
        My Document Title:
        A Closer Look at the Subject

        Content starts here.
    :: lex ::

    Example: Title with Subtitle and Inline Formatting
        *Sapiens*:
        A Brief History of _Humankind_

        In the beginning, there were humans.
    :: lex ::

    Example: Title Ending with Colon (No Subtitle)
        Warning: Do Not Enter

        Content starts here.
    :: lex ::

    Note on the previous example: the title line ends with a colon, but because the next line is not a subtitle continuation (it is a blank line), the entire line including the colon is the title text. The colon only triggers subtitle parsing when a non-blank, non-indented line immediately follows.

    Example: Not a Title (No blank line)
        Not a title
        Because no blank line follows.
    :: lex ::

    Example: Not a Title (Indented)
        Not a title

        Because it is indented (this would be a code block or continuation).
    :: lex ::

    Disambiguation:
        Title vs. subtitle depends on the combination of trailing colon and the presence of a second line:

        Trailing colon + second line before blank:
            Title with subtitle. The colon is stripped from the title content; the second line becomes the subtitle.

        Trailing colon + blank line immediately after:
            Plain title. The colon is part of the title content. No subtitle.

        No trailing colon:
            Plain title. No subtitle, regardless of what follows.

        This means "Warning: Do Not Enter" is always a plain title (colon is mid-line), and "My Title:" followed by "The Subtitle" on the next line is always a title with subtitle.
