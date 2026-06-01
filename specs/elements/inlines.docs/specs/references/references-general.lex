:: title :: References General Specification
:: author :: Arthur Debert
:: pub-date :: 2025-01-12

Complete specification for the general reference system - the foundation for linking, cross-referencing, and connecting content within and beyond lex documents.

:: note :: This specification describes the specific characteristics of reference inline elements. For the general inline token pattern, universal grammar, parsing architecture, and AST foundation shared by all inline elements, see [../inlines-general.lex].



1. Purpose

    References provide the mechanism for linking content within documents and connecting to external resources. They enable cross-references to document sections, links to external URLs, file references, and integration with citation systems. The reference system maintains the plain text philosophy while providing powerful connectivity and navigation capabilities.

2. General Reference Form

    2.1. Basic Syntax Pattern

        All references follow the bracket-enclosed pattern:
            [reference-content]
        
        Where:
        - Square brackets immediately surround the reference
        - No spaces between brackets and content
        - Content determines reference type and target
        - References are resolved based on content pattern

        Examples of the general form:
            
        - [section title]
        - [http://example.com]
        - [file.txt]
        - [@citation-key]
         - [::annotation-id]

    2.2. Content-Based Type Resolution

        Reference type determined by content pattern:
        - URL patterns → External links
        - File patterns → File references
        - Citation patterns (`@key`) → Bibliographic citations
        - Footnote patterns (`^id`) → Footnote references
        - Session patterns (`#number`) → Session cross-references
        - Plain text → General document references

    2.3. Implicit Anchors

        In HTML — and therefore Markdown and most markup languages — the analogue of a Lex reference is the link, which carries both a destination (where it points) and an anchor (the text the link is applied to). Lex keeps the destination inside the brackets but derives the anchor *implicitly* from position, so the author never writes the anchor text twice. The motivation is twofold:

        - One of the largest usability problems with Markdown is precisely its link form `[]()` (which part comes first? is there a space?). It is a consistent source of friction.
        - The overwhelming majority of links cover a single word or a single line, and when they do not, little meaning is lost.

        Lex offers two anchor scopes: a word anchor (inline references) and a whole-element anchor (reference lines). The scope is chosen by where the reference sits, never by a separate marker.

    2.3.1. Word anchors (inline references)

        A reference that shares its line with other text is an inline reference, and it anchors a single word:

        - Preceding word (default): the word immediately before the reference.
              the project website [https://lex.ing]   ->  anchor = "website"
        - Following word: when the reference is the first token on the line and text follows it on the same line, the anchor is the word immediately after.
              [https://lex.ing] is the home page       ->  anchor = "is"

        To anchor exactly one word, place the reference directly after it; no surrounding space is required:
              Hello[./file.txt] World                  ->  anchor = "Hello"

        So `foo [http://example.com]` is the equivalent of `<a href="http://example.com">foo</a>` in HTML.

    2.3.2. Whole-element anchors (reference lines)

        A reference that is the *only* content on its line is a reference line. Its anchor is the entire head line of the element directly above it:

              Getting Started
              [./readme.txt]

                  Welcome to the docs.

        The reference line anchors the whole session title "Getting Started". The same holds for the head line of every element:

              - Food
              - Water
              [https://water.example]
              - Bread

        anchors the entire "Water" list item.

        The anchor is always the element's own head line — never its content or its children:

        - Session: the title line (not the section body)
        - List item: the item's own line (not nested items or continuation paragraphs)
        - Definition: the subject term (the trailing colon is the marker, excluded from the anchor)
        - Verbatim block: the subject line (not the verbatim content)
        - Paragraph: the single line directly above the reference line

        A reference line only ever looks *upward*. If there is no content line directly above it — it is the first line of its container, or is preceded by a blank line — the reference line stands alone and links its own text, exactly as a lone inline reference would:

              See the upstream project:

              [https://github.com/lex-fmt/lex]

        A reference line placed *above* an element does not attach to the element below it.

    2.3.3. Reference lines and parsing

        A reference line is transparent to structural parsing: it is neither a content line nor a blank line. It is removed from the line stream before document structure is resolved, so the lines surrounding it retain their original adjacency.

        This matters because a blank line is significant in Lex: the presence or absence of a blank line after a subject is what separates a definition from a session (see ../../../definition.lex). If a reference line were treated as a blank line, the following definition would silently become a session:

              API Endpoint:
              [./endpoint.txt]
                  A URL that provides access to a resource.

        Removing the reference line (rather than blanking it) preserves the no-blank-line adjacency, so the element stays a definition and the reference line anchors the subject "API Endpoint".

        At most one reference line may anchor a given element. Stacked reference lines, and a reference line whose anchored head line also carries an inline reference (which would nest two links over the same text), are illegal: the parser honors the whole-line anchor only and emits a diagnostic warning for the overlap.

    2.3.4. Reference type and anchor scope

        Whole-element anchoring applies only to link-like references — those that render as a span of linked text (Url, File, Session, General). Marker-style references — footnotes `[1]`, citations `[@key]`, and annotation references `[::label]` — render as markers or superscripts, so a whole-element anchor has no visual meaning for them; on a reference line they self-link or resolve as usual. This split is a property of the reference type, not of position.
3. Reference Types

    3.1. External Links

        Direct URL references:
            [https://example.com]
            [http://lex.org/docs]
            [mailto:user@domain.com]
        :: external-links

        Purpose: Links to external web resources, email addresses

    3.2. File References

        Local and relative file links:
            [../docs/guide.lex]
            [images/diagram.png]
            [/absolute/path/file.txt]
        :: file-references

        Purpose: References to other files in the project or filesystem

    3.3. Document Cross-References

        Internal document navigation:
            [Introduction]
            [#1.2]
            [Methodology section]
        :: document-references

        Purpose: Navigation within the current document

    3.4. Citation References

        Bibliographic and academic citations:
            [@smith2023]
            [@doe2024, p. 45]
            [@multiple; @citations]
        :: citation-references

        Purpose: Academic and bibliographic references

    3.5. Footnote References

        Numbered references to footnote definitions in a `:: notes ::` list:
            [1]
            [2]
            [42]
        :: footnote-numbered

        Purpose: Supplementary information collected in a notes list.
        Footnote definitions are list items inside a list preceded by a `:: notes ::` annotation (see footnotes.lex).

    3.6. Annotation References

        Labeled references that point to an annotation by label:
            [::note1]
            [::detailed-explanation]
            [::methodology-note]
        :: annotation-reference

        Purpose: Precise pointers to individual `:: label ::` annotations.
        The `::` prefix mirrors the annotation marker syntax, distinguishing annotation references from other reference types. Resolution is by label matching, case-insensitive.

        Placeholder references for future content:
            [TK]                    # Naked TK reference
            [TK-identifier]         # TK with identifier
            [TK-1]                  # Numbered TK
            [TK-someword]           # Named TK
        :: tk-references

        Purpose: Content placeholders and development markers

    3.8. Not Sure References

        Unresolved or ambiguous references:
            [ambiguous-content]     # Cannot determine type
        :: not-sure-references

        Purpose: Default fallback when reference type cannot be determined

4. Target Resolution

    4.1. Resolution Strategy

        Reference target determination:
        1. Check for explicit patterns (URL, citation, footnote)
        2. Search document structure for matching targets
        3. Check external file references
        4. Fall back to textual display if no target found

    4.2. Target Types

        Reference resolution targets:
        - URLs: Direct external links
        - Files: Filesystem paths (relative/absolute)
        - Sessions: Document sections by title or number
        - Definitions: Term definitions within document
        - Citations: Bibliography entries
        - Footnotes: Footnote content
        - Anchors: Named reference points
        - TK: Content placeholders
        - Not Sure: Unresolved references

    4.3. Ambiguity Resolution

        Handling multiple potential targets:
        - Prefer exact matches over partial matches
        - Prioritize document-internal over external references
        - Use context to disambiguate similar targets
        - Provide clear error messages for unresolved references

5. Grammar

    5.1. Reference Structures

        The authoritative grammar for all reference types is defined in the main syntax reference.

        General reference:
            <reference-content> = (<text-char> - [[\]])+
            <reference-span> = <left-bracket> <reference-content> <right-bracket>

        Citation reference:
            <citation-span> = <left-bracket> <at-sign> <citation-keys> <citation-locator>? <right-bracket>

        Page reference:
            <page-ref> = <left-bracket> <page-locator> <right-bracket>

        Session reference:
            <session-ref> = <left-bracket> <hash> <session-number> <right-bracket>

        Footnote reference:
            <footnote-ref> = <left-bracket> <footnote-number> <right-bracket>

        Annotation reference:
            <annotation-ref> = <left-bracket> '::' <annotation-label> <right-bracket>
        :: grammar

6. AST Structure

    Post-parsing semantic representation:

    Reference AST:
        ├── Reference
        │   ├── reference_type: ReferenceType
        │   ├── content: String
        │   ├── target: Option<ResolvedTarget>
        │   ├── display_text: Option<String>
        │   └── tokens: TokenSequence
    :: reference-tree

    Reference type variants:
        ├── ReferenceType
        │   ├── Url(UrlData)
        │   ├── File(PathData)
        │   ├── Session(SessionRef)
        │   ├── Citation(CitationData)
        │   ├── FootnoteNumber(u32)
        │   ├── AnnotationReference(String)
        │   ├── TK(TKData)
        │   ├── NotSure(String)
        │   └── General(String)

7. Processing Rules

    7.1. Recognition Phase

        Reference detection and parsing:
        1. Scan text for bracket patterns `[...]`
        2. Extract content between brackets
        3. Validate content is non-empty
        4. Classify reference type based on content patterns

    7.2. Type Classification

        Reference type determination order:
        1. TK patterns (`TK` or `TK-identifier`)
        2. Citation patterns (`@key`)
        3. Annotation reference patterns (`::label`)
        4. Session patterns (`#number`)
        5. URL patterns (protocol or domain)
        6. File patterns (starts with `.` or `/`)
        7. Footnote numbered patterns (pure digits)
        8. General (default fallback)

    7.3. Validation Rules

        Parser validation requirements:
        - Must contain at least one alphanumeric character
        - No validation of actual target existence
        - No error on unresolved references
        - Preserve original content for display

8. Implementation Notes

    8.1. Parser Integration

        The parser should make an effort to validate the reference type, but not error or warn. To be a valid reference all that's needed is at least one alphanumeric character. And it should not do further validation such as validate paths or even sessions or footnotes in this same document.

    8.2. TK Reference Details

        TK (To Come) reference specifications:
        - Naked TK: `[TK]` (case insensitive)
        - Identified TK: `[TK-identifier]`
        - Identifier rules: lowercase alphanumeric, can start with numbers
        - Maximum 20 characters for identifier
        - Examples: `TK-1`, `TK-343`, `TK-a3`, `TK-someword`

    8.3. Not Sure Fallback

        Default reference type handling:
        - Used when no other pattern matches
        - Preserves original content exactly
        - Allows for future resolution by external tools
        - No parser errors for unknown reference types 
