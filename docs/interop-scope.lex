Babel v1 Interop Scope

1. Overview

    A guide for contributors: which document formats in lex-babel are real, which are planned, which are experimental, and which are explicitly out of scope.

    The lex-babel crate is the entire format-conversion story for Lex. This document exists so contributors, reviewers, and future-us can tell at a glance which formats are load-bearing and which are aspirational. The lex-babel `lib.rs` module doc links here.

    Before reading: the most important framing in this whole document is in section 6 — PDF import is a category error, not a postponed task. If you skim nothing else, skim that.

2. Core formats (the v1 bar)

    These three are what "lex-babel works" means. A regression in any of them is a release blocker.

    Markdown:
        Both export and import. Markdown is Lex's lingua franca — round-trip discipline is the bar, and is what we measure regressions against. The bulk of test fixtures and snapshot tests live here.

    HTML:
        Export only. The publishing target for the web; the PDF and PNG exporters and editor previews consume the HTML output. There is no v1 HTML importer — see section 3.

    PDF:
        Export only, via headless Chrome rendering of the HTML output. PDF import is a category error; see section 6.

    PNG:
        Export only, via a headless Chrome screenshot of the HTML output. Same pipeline as PDF; different output sink.

3. Stretch (after core lands)

    These are real, planned work — they belong on a roadmap, not in a `mod.rs` placeholder.

    HTML import:
        Semantic-enough HTML exists in the wild that an importer is worthwhile. Scheduled after the core trio is solid. Do not start it before then.

4. Experimental

    Kept in-tree as a proof-of-concept. We invest no bespoke time here; only improvements that fall out of IR-symmetry work for free.

    RFC XML:
        Parse-only import from IETF RFC XML (v3) documents. Fun, useful for demos, not a release-quality format. The `rfc_xml/mod.rs` doc-comment carries an Experimental banner so contributors know not to invest there.

5. Planned (not started)

    These are documented intent, not in-progress work. The `mod.rs` files for each carry a `Status: Planned, not started` banner so the source tree doesn't read as half-implemented.

    Pandoc:
        Will be the primary bridge for DOCX, EPUB, RST, Org, and most other formats that aren't worth a bespoke implementation. The plan is to use the `pandoc_ast` crate so we don't shell out to the Pandoc binary.

        There is currently no implementation — no struct, no `Format` impl, no `pandoc_ast` dependency in `Cargo.toml`, no registration in `registry.rs`. The `pandoc/mod.rs` file holds an element-mapping table as planning material; the file should not be read as in-progress.

    LaTeX:
        Export only, via Pandoc. Lex has obvious fit for scientific writing, but the bridge is Pandoc, not a bespoke exporter. Once Pandoc lands, `lex → Pandoc AST → LaTeX` is the production LaTeX path.

        A bespoke LaTeX exporter is conditional on all three of:

        - Adoption proving it matters.
        - Users actually consuming the LaTeX output.
        - Demonstrated limitations in the Pandoc-rendered LaTeX.

        A bespoke LaTeX importer is never in scope. Pandoc handles that direction natively, and a homegrown LaTeX parser would be a multi-year sink for a use case nobody has asked for.

6. Category errors (will not do)

    PDF import:
        PDF is a presentation format. It does not encode the structure Lex needs to parse — paragraphs, headings, lists, and the like are reconstructed heuristically from layout (font size, indentation, glyph positions), and no rule-based importer recovers that reliably. Pandoc punts to `pdftotext` for the same reason.

        This is not "postponed". It is a category mismatch and will not be implemented, ever, regardless of adoption.

        ML-based extraction (Marker, Nougat, Mathpix, Grobid) is an entirely different product category and out of scope for lex-babel. Do not list, advertise, or design around the possibility.

7. Why the explicit tiering

    The lib.rs doc, README, and several format `mod.rs` files have, at various points, listed Pandoc and LaTeX in ways that read as near-term goals. They are not. The ambiguity caused real damage:

    - The markdown serializer accumulated a hardcoded metadata-label whitelist (`author`, `note`, `title`, `date`, `tags`, `category`, `template`) because the IR/event abstraction couldn't yet express "metadata annotation → comment-wrapped raw block". The HACK comment in `markdown/serializer.rs` is a candid admission that the abstraction leaked.
    - Pandoc's `mod.rs` carried an element-mapping table that read like an in-progress implementation when no struct, trait impl, or dependency existed for it.

    Naming the tiers explicitly closes that pressure valve. Future contributors can read this file and know exactly where to invest — and just as importantly, where not to.

8. Quick reference

    The whole story in one table:
        | Tier            | Format   | Export | Import |
        | Core            | Markdown | yes    | yes    |
        | Core            | HTML     | yes    | no     |
        | Core            | PDF      | yes    | no     |
        | Core            | PNG      | yes    | no     |
        | Stretch         | HTML     | no     | yes    |
        | Experimental    | RFC XML  | no     | yes    |
        | Planned         | Pandoc   | no     | no     |
        | Planned         | LaTeX    | no     | no     |
        | Category error  | PDF      | no     | no     |
        :: table align=llcc ::
