Reference Anchoring Fixture

This fixture exercises every anchoring case from references-general.lex §2.3.
Each session names the case and shows the construct; parser tests assert the
resolved anchor for each reference shown.

1. Inline word anchors

    Preceding word:

        the project website [https://lex.ing] is fast.

    The reference anchors "website".

    Following word:

        [https://lex.ing] is the home page.

    The reference is first on the line, so it anchors the following word "is".

    Explicit single word:

        Hello[./file.txt] World

    The reference directly follows "Hello", so it anchors "Hello" only.

2. Reference line on a session title

    Getting Started
    [./readme.txt]

        Welcome to the docs.

    The reference line anchors the whole title "Getting Started", not the body.

3. Reference line on a list item

    - Food
    - Water
    [https://water.example]
    - Bread

    The reference line anchors the entire "Water" list item, not the siblings.

4. Reference line on a definition term

    API Endpoint:
    [./endpoint.txt]
        A URL that provides access to a resource.

    The reference line is transparent, so the no-blank-line adjacency holds: this
    stays a definition (not a session) and anchors the term "API Endpoint".

5. Reference line on a verbatim subject

    Example Source:
    [./example.rs]
        fn main() {
            println!("hello");
        }
    :: rust ::

    The reference line anchors the subject "Example Source", not the content.

6. Reference line on a paragraph

    The release notes cover every change in this cycle.
    [./CHANGELOG.md]

    The reference line anchors the single paragraph line directly above it.

7. Self-link fallback

    There is no content line directly above the reference below it:

    [https://github.com/lex-fmt/lex]

    With a blank line above it, the reference line stands alone and links its own
    text.

8. Marker-style references on a reference line

    Closing remarks.
    [::summary-note]

    Annotation references, footnotes, and citations are marker-style: a reference
    line does not give them a whole-element anchor. They self-link or resolve as
    usual.

    :: summary-note ::
        Resolved by label, unaffected by anchoring.
