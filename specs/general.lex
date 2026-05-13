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

        Labels carry namespace semantics that determine who owns them, how they're spelled, and how they round-trip through formatting. See [#4] for the full label-namespace model — reserved prefixes (`lex.*`, `doc.*`), bare-form aliases (the user-facing voice), and the community shape (`owner.repo`). Annotations are the most visible carrier of labels, but the same model applies to verbatim closers and table closers.

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

4. Label Namespaces

    Labels appear on annotation markers (`:: label ::`), on verbatim closers (`:: label ::` after indented content), and on table closers (the special `table` closer). A label is an identifier optionally containing dot-separated segments. The shape of those segments selects a namespace, which determines ownership, allowed authors, and the spelling the parser canonicalizes to.

    Four namespace classes exist:

    - *Reserved-canonical*: `lex.*`. Owned by the core; carries the canonical spelling of built-in semantics.
    - *Reserved-forbidden*: `doc.*`. Held back from third-party authoring; not aliased to anything. Authoring `doc.<anything>` is a parse error.
    - *Blessed user-facing*: bare names (no dots) and prefix-stripped forms (one or more dots, not starting with a reserved prefix). Aliases for the `lex.*` canonical via the rules in [#4.2]. This is the form documentation, examples, and editor output lead with.
    - *Community*: `owner.repo` shape (one or more dots, first segment not reserved). Freely available for extensions (`acme.task`, `mycompany.review`). Owned by whoever publishes them; the registry, when it exists, governs discovery.

    Anything that does not match a reserved namespace, resolve via [#4.2] to a known canonical, or come from a registered community handler is rejected at parse time.

    4.1 Reserved namespaces

        The `lex.*` prefix is reserved for core-defined semantics. The core may add new `lex.*` labels without coordinating with downstream; third-party tooling MUST NOT author labels in this namespace. The canonical spelling is the form transmitted over the extension wire and the form recorded in spec/reference documentation.

        The `doc.*` prefix is reserved and forbidden. It was the pre-extension canonical for core semantics (`doc.table`, `doc.image`, etc.) and is held back to prevent third-party squatting on the historical names. The parser rejects any `doc.<anything>` label with a diagnostic suggesting the blessed equivalent.

    4.2 Bare and stripped forms — the user-facing voice

        Every `lex.*` canonical is reachable via two additional input forms. Both are accepted at parse time, both resolve to the same canonical, both are dispatched identically to the extension registry.

        Rule 1 — prefix strip (universal, mechanical). Every `lex.X.Y.Z` canonical accepts `X.Y.Z` as input. The parser prepends `lex.` and resolves. No curation; the rule applies to every label in the `lex.*` namespace.

        Examples:

        - `metadata.author` resolves to `lex.metadata.author`.
        - `tabular.table` resolves to `lex.tabular.table`.
        - `media.image` resolves to `lex.media.image`.
        - `include` resolves to `lex.include` (single-segment canonical; the strip rule leaves it unchanged).

        Rule 2 — shortcut (curated, opt-in per label). A small hand-picked set of high-traffic labels gets an additional one-segment form. The shortcut table is normative and lives in this specification:

        | Canonical               | Shortcut    |
        | ---                     | ---         |
        | lex.tabular.table       | table       |
        | lex.media.image         | image       |
        | lex.media.video         | video       |
        | lex.media.audio         | audio       |
        | lex.metadata.author     | author      |
        | lex.metadata.title      | title       |
        | lex.metadata.tags       | tags        |
        | lex.metadata.date       | date        |
        | lex.include             | include     |
        :: table align=ll ::

        Labels not listed here have no shortcut form — the prefix-stripped form is still accepted. Skipped on purpose because their bare form would read ambiguously: `lex.metadata.template`, `lex.metadata.category`, `lex.metadata.publishing-date`, `lex.metadata.front-matter`.

        Adding a label to the shortcut table is a minor version bump. Removing a label from the shortcut table is a breaking change and should not happen.

        Resolution order at parse time: try shortcut → try `lex.<input>` (the prefix-strip rule) → try `<input>` as a registered community label → reject.

    4.3 Form preservation

        Lex documents round-trip without rewriting the user's choice of form. A document that uses `:: author ::` formats back as `:: author ::`; one that uses `:: metadata.author ::` formats back as `:: metadata.author ::`; one that uses `:: lex.metadata.author ::` formats back unchanged.

        The parser categorizes each label site as `Canonical`, `Stripped`, or `Shortcut` based on what it saw, and records that classification alongside the resolved canonical. Downstream stages (formatter, hover, diagnostics, code actions) consult the classification when surfacing the label back to the user.

        The form classification is host-side state. The extension wire format always carries the canonical spelling; handlers dispatch on canonical and have no awareness of which form the user originally wrote.

    4.4 Community labels

        Labels not in `lex.*`, not in `doc.*`, and not in the bare/stripped/shortcut input layer fall into the community namespace. Today these are user-defined and registered through the extension system's `Schema.label` field; a future registry will provide discovery.

        Community labels are shape-distinct from blessed forms — they always contain at least one dot, with the first segment naming the owner. A bare label like `task` is never a community label; only `acme.task` is. This separation lets the parser route `task` unambiguously through the shortcut layer (if listed) or stripped-form layer (if `lex.task` exists), without ever colliding with a community label.

    4.5 Documentation voice

        User-facing documentation, examples, and editor output use the shortest accepted form: the shortcut where available, the prefix-stripped form otherwise, the canonical only when neither alias exists. The `lex.*` canonical appears in spec text and reference documentation explaining the alias machinery, and on the extension wire — not in everyday tutorial content.
