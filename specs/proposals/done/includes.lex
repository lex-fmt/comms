:: status :: This proposal was implemented in lex-fmt/lex PRs #486–#495. It is frozen — for current behaviour of the feature, see specs/elements/lex.include.lex. Kept here to preserve design rationale; small deviations between the proposal's original wording and the shipped behaviour are noted in the relevant section's revision history (see lex-fmt/comms#25).

Proposal: The Includes Feature

    Lex today assumes a one-document, one-file relationship. This proposal introduces a sanctioned mechanism for a document to pull in content from another Lex file and have it merged into its tree at parse-plus-resolution time. The surface is a reserved annotation (`:: lex.include src="..." ::`) whose included content is spliced into the parent container at the include site. The parser itself stays pure and filesystem-free. The mechanism deliberately starts narrow: relative and root-absolute paths only, no URLs, no absolute filesystem paths, no conditionals, no templating. The goal is a beachhead — a small, canonical core that third-party tooling can build on without fragmenting the ecosystem.

1. Motivation

    1.1 The Case for a Sanctioned Mechanism

        Documents of any size rarely live as one file. Shared headers, indexes, chapter atoms, reusable glossaries, and content-managed fragments all want to compose. Markdown never specified an include mechanism; the consequence is dozens of mutually-incompatible plugins, build-tool filters, and ad-hoc conventions that break the moment a document moves between tools.

        Lex has the structural advantage here: its AST is a proper tree with sessions, definitions, and annotations. Merging one Lex document into another is semantically clean in a way it never was for Markdown's flat-to-semi-flat model.

        Every serious document format has eventually landed here:

        - LaTeX: `\input` and `\include`
        - AsciiDoc: `include::path[]`
        - Org: `#+INCLUDE: "path"`
        - Typst: `include "path"`
        - Pandoc: filter ecosystem (no canonical form — the cost is visible)
        - MDX: ES module `import`

        The absence of a canonical form does not make tooling simpler; it forces every UI and build pipeline to reinvent its own, and those implementations drift out of sync.

    1.2 The Cost of Not Having One

        Without a sanctioned mechanism:

        - Each editor extension (VS Code, Neovim, lexed) has to either skip the feature or invent its own, making interchange worse.
        - Authors who want includes choose between tool lock-in and giving up the feature.
        - Build pipelines reimplement the same cycle detection, path resolution, and merge semantics slightly differently every time.
        - Future de facto standards emerge, but only after years of fragmentation.

    1.3 Design Goals

        - Reuse existing Lex syntax. No new surface grammar.
        - Keep the parser pure: no filesystem access, synchronous, local.
        - Give enough semantics in the core that tooling can be thin.
        - Define a security model from day one, before use cases ossify.
        - Stay composable with every other Lex element (sessions, footnotes, references, annotations).
        - Reserve a namespace (`lex.*`) so the core can grow without colliding with third-party extensions.
        - Match author intuition: an include should behave as if its content had been pasted at the include site, indent-shifted to match.
        - Ship a narrow core. Leave URL fetching, cross-document references, templating, and conditionals out of v1 of the feature, but in a way that does not require breaking changes to add later.

2. Surface Syntax

    2.1 The lex.include Annotation

        Includes use the annotation surface, with the reserved label `lex.include` and a mandatory `src` parameter:

            :: lex.include src="chapters/01-introduction.lex" ::

        The annotation may appear anywhere an annotation is legal: at document root, inside a session, inside a definition, inside a list item, or inside another annotation's block content. Its attachment, post-resolution, follows standard annotation attachment rules (see `elements/annotation.lex`): it attaches to the first node that came from the included file.

        Before resolution, the annotation is a normal `Annotation` node. After resolution, the included content occupies the parent container at the annotation's position and the annotation itself is attached to the first spliced node.

    2.2 Examples

        Document root (most common case):

            Book Title

                :: lex.include src="chapters/01.lex" ::

                :: lex.include src="chapters/02.lex" ::

                :: lex.include src="chapters/03.lex" ::

        Inside a session:

            2. Appendix

                :: lex.include src="appendix/glossary.lex" ::

        Including a fragment that has no top-level sessions (e.g. a thread of review annotations):

            1. Introduction

                Some content.

                :: lex.include src="reviews/intro-thread.lex" ::

    2.3 Why Annotation, Not Verbatim

        Verbatim blocks already accept a `src=` parameter for linking external content, but verbatim's semantic is "content that comes from a file and stays opaque" (images, embedded code shown literally). An include's semantic is the opposite: "replace me with the parsed AST of that file." These are different enough that conflating them hurts both.

        Annotations also already have the right attachment semantics: an annotation describes the thing that immediately follows it. The include annotation describes the included content. After resolution, the standard attachment rule places the annotation on the first node it pulled in, which is exactly the right place for tooling to find it.

    2.4 The lex.* Namespace

        This proposal reserves the `lex.*` annotation label prefix for core-defined semantics. Third-party tooling must not use `lex.*`; the core may add new `lex.*` labels without versioning concerns. Non-reserved labels remain freely available for extensions (`mycompany.include`, `docs.embed`, etc.).

3. Resolution Model

    3.1 Parser Remains Pure

        The parser does not touch the filesystem. A `lex.include` annotation parses exactly like any other annotation: label, parameters, no body. This is a hard invariant: it preserves synchronous, local, deterministic parsing, and it keeps the parser usable in WASM, LSP hot paths, and sandboxed environments without I/O permissions.

    3.2 Core-Layer Resolution Pass

        Resolution lives in `lex-core` (module: `lex_core::includes`). A new function is exposed, roughly shaped as:

            resolve_includes(
                document: Document,
                config: &ResolveConfig,
                loader: &dyn Loader,
            ) -> Result<Document, IncludeError>
        :: signature ::

        The pass walks the tree, finds each `lex.include` annotation, asks the loader to produce the included file's source text, parses it (using the existing parser), recursively resolves its own includes (subject to the depth and cycle limits), stamps the resulting tree with origin information, validates that its body is legal in the include site's parent container, and splices the body into that container at the include annotation's position.

        Consumers that want the pre-resolution tree (the formatter, the tree-sitter grammar, editor tooling that displays the include statement as authored) simply skip the pass. `parse_document` is unchanged and resolution is opt-in.

    3.3 Injectable Loader

        The loader is an injected callable, not hard-coded to `std::fs`. lex-core's own code does not reference `std::fs` for include resolution. This lets:

        - Tests use in-memory fixtures.
        - WASM builds provide a JS-backed loader.
        - The LSP wraps an FS loader with file-watch invalidation.
        - Future extensions plug in caching, URL fetching, or virtual filesystems without touching the core.

4. Path Resolution

    4.1 Relative Paths

        Relative paths resolve against the directory of the file that contains the include. This matches every reasonable author mental model: when writing `chapters/01.lex`, a reference to `./shared/figures/diagram.png` means "next to me."

        Non-negotiable for v1 of the feature. The safest form and the most common case.

    4.2 Root-Absolute Paths

        A leading `/` means "relative to the document root," not the filesystem root. This gives authors a stable way to reference shared fragments without needing to know their own depth in the tree:

            :: lex.include src="/shared/header.lex" ::

        This form is necessary because relative paths alone force fragile `../../../shared/header.lex` patterns once a project grows past two directory levels.

    4.3 The Document Root

        Every resolution has exactly one root, discovered in this order:

        1. An explicit override (CLI flag `--includes-root` or `[includes].root` in `lex.toml`).
        2. The directory of the nearest `lex.toml` walking upward from the entry-point document. This matches the existing clapfig config discovery and gives project-wide includes without per-invocation config.
        3. The directory of the entry-point document itself, as a fallback when no `lex.toml` is found.

        All paths — relative or root-absolute — normalize to a canonical absolute path. That canonical path must live inside the root. Any normalized path that escapes the root is a resolution error, even if the on-disk file exists.

    4.4 No Escape

        The root is enforced by canonicalization and prefix check, not by blocklists or per-directory rules. This is intentional: permissive models with allow/deny lists are where security bugs live. One root, one rule, no exceptions.

5. Merge Semantics

    5.1 Where the Content Lands

        The included document's body is spliced into the parent container at the include annotation's position. The annotation does not absorb the included content into its own children slot; the content appears as the annotation's siblings, immediately after it, in the parent container.

        Standard annotation attachment then runs as it would for any annotation: the `lex.include` annotation attaches to the first spliced sibling (the first node that came from the included file). After attachment, the include annotation is no longer standalone — it lives in the `annotations` field of the spliced node, exactly as if the author had written the annotation immediately above that content inline.

        This rule is uniform with how every other annotation in lex behaves: an annotation describes the thing it precedes. The thing the include annotation precedes is the included content.

        The mental model authors should hold: the include behaves as if the included file's text had been pasted at the include site, indent-shifted to match. The implementation operates on parsed trees rather than raw text, but the resulting tree is the same.

    5.2 Document-Level Metadata of the Included File

        An included file is parsed as a standalone Lex document. Its parsed form may contain a `DocumentTitle` and document-level annotations attached to `DocumentStart`. These elements describe the file as a standalone artifact, not as a fragment in a host document.

        On splice, they are converted to their non-document forms and prepended to the body:

        - The `DocumentTitle`, if present, is converted to a `Paragraph` containing the title text and prepended to the splice list.
        - Document-level annotations, if present, are converted to regular annotations and prepended.

        This is exactly what would happen in a textual model that pasted the included source into the host file with indent-shift: an unindented title line would parse as a paragraph in the new context, and document-level annotations would parse as regular annotations attaching to the next sibling.

        The benefit is round-trip predictability: when a chunk of merged content is later extracted into a standalone file, the leading paragraph naturally parses as a doc title and the leading annotations naturally parse as document-level metadata.

    5.3 Container-Policy Validation

        Lex's typed-content system enforces that certain containers do not allow Sessions: `Definition`, `Annotation` body, and `ListItem` (collectively, `GeneralContainer`). When an include site sits inside one of these containers and the included file contains top-level Sessions, the splice would produce an invalid tree.

        The resolver detects this case and produces a precise error pointing at the include site, naming the offending container kind and the included file. The cases are:

        - `lex.include` inside the long-form body of another annotation, where the included file contains Sessions.
        - `lex.include` inside a definition, where the included file contains Sessions.
        - `lex.include` inside a list item, where the included file contains Sessions.

        Includes at the document root or inside a Session never violate, because `SessionContainer` accepts every element type. The rule is uniform: an include is legal where its included content is legal.

    5.4 Origin Tracking

        Every node in the merged tree carries an `origin_path: Option<Arc<PathBuf>>` field on its `Range`. Nodes from the entry-point document carry the entry-point path (or `None`, depending on configuration); nodes from an included file carry that file's canonical path.

        This is used by:

        - File-reference resolution (so `[./figure.png]` in an included atom resolves relative to the atom's directory, not the merged document's).
        - Diagnostics (so errors point to the authoring file and line, not the post-merge location).
        - LSP goto-definition and hover.
        - "What files compose this document?" queries (walk the tree, collect distinct origin paths).

        Origin information is stamped post-parse on each loaded file's tree, before splicing. The parser is unchanged. Multiple inclusions of the same file produce nodes that share the same origin path; no per-include counter is needed because none of the use cases require distinguishing the copies.

6. References Across the Merge

    6.1 Footnotes

        Numbered footnote references (`[1]`, `[2]`, ...) scope to the file they were authored in. Footnote resolution runs per-file before merging — each reference carries a resolved target (or a dangling-reference diagnostic) by the time the splice happens. After merge, there is no cross-file number collision to worry about, because no inline still carries a bare number waiting to be matched.

    6.2 Session References

        Session references like `[#2.1]` are resolved against the post-merge tree by the existing reference resolver. A reference like `[#2.1]` inside an included atom means "session 2.1 in my current context" — which, after merge, is the merged context.

        No path rewriting is performed. If the author's intent was "2.1 within this atom's private namespace," that intent is not expressible in v1. The cross-document reference syntax (section 9.2) will address this in a future version.

    6.3 File References

        File references like `[./figure.png]` and `[/shared/logo.svg]` are not touched by the parser. The file-reference resolver consults each reference's enclosing node's `Range.origin_path`: relative paths resolve against the authoring file's directory, root-absolute paths against the document root.

    6.4 No Path Rewriting

        The merged AST does not mutate reference payloads. Origin tagging lets downstream resolvers do the right thing without losing authorial intent.

7. Safety

    7.1 Cycle Detection

        The resolver maintains a stack of canonicalized paths currently being resolved. Pushing a path that is already on the stack is a cycle error. Two consecutive includes of the same file are not a cycle — each include pushes and pops independently, so a file can be included multiple times in the merged tree.

    7.2 Depth Limit

        The maximum include depth is 8 by default. This is enough for any reasonable atomization strategy (aggregator includes per-chapter includes per-section includes) while bounding the resolver's worst-case work. Configurable via `ResolveConfig` for pathological document sets; hitting the limit is an error, not a silent truncation.

    7.3 Root Escape

        Any normalized path outside the document root is a resolution error. No fallback, no warning-then-continue. Enforced uniformly for both relative and root-absolute inputs.

8. Explicitly Out of Scope

    This section enumerates the things that are deliberately not part of the core, either forever or for this version. Naming them here prevents accidental scope creep and gives third-party tooling a clear extension surface.

    8.1 URLs

        `src="https://..."` is not supported in v1. Rationale:

        - URL fetching introduces asynchronous I/O, which the parser and the analysis layer today avoid.
        - Caching, offline builds, auth prompts, and redirect handling are all real problems with no universal answers.
        - Exfiltration risk (an include URL that 301-redirects to a local-file URL scheme, or that returns personally-identifying content) is non-trivial.

        Deferred, not rejected. See section 9.1.

    8.2 Absolute Filesystem Paths

        `src="/home/user/docs/shared.lex"` (interpreted as a filesystem-absolute path) is never supported. Root-absolute paths (`/shared.lex`, resolved within the document root) cover the legitimate use cases without the security and portability issues of true absolute paths.

    8.3 Conditional Includes

        No `if=`, `unless=`, `when=`, or environment-variable gating. Conditional logic belongs in a build system, not in the document format. AsciiDoc's experience is the cautionary tale.

    8.4 Variable Substitution and Templating

        No `{{var}}` interpolation, no parameter passing, no partial application. Lex documents are not templates. A doc that needs substitution is a build-system input, not a Lex file.

    8.5 Shell Commands as src

        `src="$(cat foo.lex)"` or similar is never supported. Running arbitrary code during include resolution is an attack vector with no legitimate core use case.

    8.6 Partial Includes

        No "include lines 10-20" or "include session 2.1 only" in v1. The substitute is better atomization: if you only want part of a file, split the file. Partial-range includes encourage tightly-coupled, line-number-dependent atoms.

    8.7 Cross-Document References

        Syntax like `[book#2.3]` or `parent=book` parameters on `lex.include` is not in v1. See section 9.2.

9. Potential Future Extensions

    These are directions the reserved namespace and architecture leave room for, without committing to them.

    9.1 URLs (Deferred, Not Rejected)

        When URL support lands, the syntax is unchanged — `src="https://..."` is already a legal parameter value. The additions are:

        - An async-capable loader variant.
        - A cache policy (TTL, offline mode, explicit invalidation).
        - A configuration flag gating URL resolution (off by default, opt-in per project).

        No breaking change to the core required.

    9.2 Cross-Document References

        A future extension could allow references into named siblings:

            :: lex.include src="book.lex" as="book" ::

            some [book#2.3], ...
        :: example ::

        This needs a namespace-design pass of its own (collision rules, nested aliases, what a bare `[#2.3]` means when an `as=` is in scope). Deferring to a post-v1 proposal preserves room to get it right.

    9.3 Richer Loaders

        The injectable loader interface opens room for virtual filesystems, content-addressed stores, generated content, and WASM-side loaders. None of these require core changes once the loader interface is fixed.

    9.4 Per-Include Resolution Config

        Parameters beyond `src=` (and the future `as=`) could carry include-local overrides: `depth=`, `origin=preserve|rewrite`, `errors=warn|error|ignore`. Useful for large documents; not urgent.

10. Grammar and AST

    10.1 No Parser Change Required

        `:: lex.include src="..." ::` already parses today as a normal annotation with parameters. The parser needs no grammar change to support this proposal. The entire feature is a new resolution pass, a reserved label, and one new optional field on `Range`.

    10.2 The Range.origin_path Field

        `Range` gains an optional `origin_path: Option<Arc<PathBuf>>`. Nodes in a non-resolved tree leave this `None`; nodes produced by include resolution carry the canonical path of the file they came from. Existing code that ignores the field continues to work; the field is metadata, not structure.

    10.3 Accessor Convenience

        Small ergonomic accessors on `Annotation`:

            impl Annotation {
                fn is_include(&self) -> bool { ... }
                fn include_src(&self) -> Option<&str> { ... }
            }
        :: signature ::

        These hide the string-match on the reserved label and serve as the migration boundary if a future version chooses to model includes as a distinct AST node type.

    10.4 Resolver Module Shape

        A new module `lex_core::includes` exposes:

            pub struct ResolveConfig {
                pub max_depth: usize,
                pub root: PathBuf,
            }

            pub trait Loader {
                fn load(&self, path: &Path) -> Result<String, LoadError>;
            }

            pub enum IncludeError {
                Cycle { path: PathBuf, chain: Vec<PathBuf> },
                DepthExceeded { limit: usize },
                RootEscape { path: PathBuf, root: PathBuf },
                NotFound { path: PathBuf },
                ParseFailed { path: PathBuf, source: ParseError },
                ContainerPolicy {
                    include_site: Range,
                    container: &'static str,
                    file: PathBuf,
                },
            }

            pub fn resolve_includes(
                doc: Document,
                config: &ResolveConfig,
                loader: &dyn Loader,
            ) -> Result<Document, IncludeError>;
        :: signature ::

11. Interoperability

    11.1 Tree-Sitter

        The tree-sitter grammar does not expand includes. It remains sync, local, and filesystem-free (same invariants as the core parser). A `lex.include` annotation appears in the CST as an annotation node. Editors that want the merged view get it from the LSP's semantic tokens, which run the full resolution pass.

        This is a deliberate and documented divergence between tree-sitter and LSP views. It matches the existing two-parser architecture.

    11.2 LSP

        The LSP runs the resolution pass on document open and on file watch events for included files. Resolution does not run on every keystroke: edits to the current file do not change include resolution, and edits to included files come through file watches.

        Diagnostics are surfaced at the `lex.include` annotation's range when resolution fails. Goto-definition on the include jumps to the target file. Hover on the include can show a preview of the included content.

    11.3 CLI

        `lex format` does not expand includes (per §11.4). `lex convert` and `lex inspect` resolve by default. A `--no-includes` flag bypasses resolution and produces the pre-resolution tree, useful for inspecting a document atom in isolation.

    11.4 Formatter

        The formatter never expands includes. It operates on the surface AST: the `lex.include` annotation is formatted like any other annotation. Expansion is a separate concern.

12. Open Questions

    12.1 Annotation-Level Parameter Passing

        The spec above treats `src` as the only parameter with semantic meaning. Should future-proofing allow additional user parameters to flow through as metadata on the resolved content? Leaning no: simpler to wait until a concrete use case forces the design.

    12.2 Formatter Behavior for Long src Values

        Very long paths in a `src=` parameter are ugly. The existing annotation parameter formatter rules apply. Likely no special-casing needed; flagged here for validation during implementation.

13. Summary

    The proposal adds no grammar, no new AST node type, and no parser change. It adds:

    - A reserved annotation label (`lex.include`).
    - A reserved namespace (`lex.*`).
    - A new optional field on `Range` (`origin_path`) for source attribution.
    - A core-layer resolution pass with cycle detection, depth limiting, root-escape enforcement, and container-policy validation.
    - A documented security model (relative and root-absolute paths only).
    - An explicit list of things that are out of scope — forever (shell, absolute FS paths, templating, conditionals) or for now (URLs, partial includes, cross-document references).

    The goal is to give the ecosystem a sanctioned beachhead: a small, canonical core that tooling can build on without each implementer reinventing it, and without locking out the more ambitious features that may arrive later.

14. Note on Revision

    This proposal supersedes an earlier draft that placed resolved content into the include annotation's `children` slot and located the resolver in `lex-analysis`. That draft conflicted with the typed-content system: an included file containing Sessions could not legally inhabit the `GeneralContainer` of an annotation. The current "splice into parent, attach via standard rules" model resolves the conflict, mirrors the textual paste mental model that authors form intuitively, and unifies include-site behavior with how annotations already work everywhere else in lex. The resolver moved to `lex-core` because the splice operation is part of producing a well-formed Lex document, not an optional analysis utility. The earlier draft is in source control history.
