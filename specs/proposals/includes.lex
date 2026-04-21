Proposal: The Includes Feature

    Lex today assumes a one-document, one-file relationship. This proposal introduces a sanctioned mechanism for a document to pull in content from another Lex file and have it merged into its tree at parse-plus-resolution time. The surface is a reserved annotation (`:: lex.include src="..." ::`) whose children are filled in by a post-parse resolution pass. The parser itself stays pure and filesystem-free. The mechanism deliberately starts narrow: relative and root-absolute paths only, no URLs, no absolute filesystem paths, no conditionals, no templating. The goal is a beachhead — a small, canonical core that third-party tooling can build on without fragmenting the ecosystem.

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
        - Ship a narrow core. Leave URL fetching, cross-document references, templating, and conditionals out of v1 of the feature, but in a way that does not require breaking changes to add later.

2. Surface Syntax

    2.1 The lex.include Annotation

        Includes use the annotation surface, with the reserved label `lex.include` and a mandatory `src` parameter:

            :: lex.include src="chapters/01-introduction.lex" ::

        The annotation may appear anywhere an annotation is legal: at document root, inside a session, inside a definition, or inside another annotation's block content. Its attachment follows standard annotation attachment rules (see `elements/annotation.lex`).

        Before resolution, the annotation is a normal `Annotation` node with empty children. After resolution, its children slot contains the content of the included document.

    2.2 Examples

        Document root (most common case):

            Book Title

                :: lex.include src="chapters/01.lex" ::

                :: lex.include src="chapters/02.lex" ::

                :: lex.include src="chapters/03.lex" ::

        Inside a session:

            2. Appendix

                :: lex.include src="appendix/glossary.lex" ::

        With an explicit title override dropped — the included file's own title is not carried over:

            :: lex.include src="shared/boilerplate-header.lex" ::

    2.3 Why Annotation, Not Verbatim

        Verbatim blocks already accept a `src=` parameter for linking external content, but verbatim's semantic is "content that comes from a file and stays opaque" (images, embedded code shown literally). An include's semantic is the opposite: "replace me with the parsed AST of that file." These are different enough that conflating them hurts both.

        Annotations already have a `children: GeneralContainer` slot. That slot is the natural landing pad for the resolved content. No AST shape change is required — only a resolver.

    2.4 The lex.* Namespace

        This proposal reserves the `lex.*` annotation label prefix for core-defined semantics. Third-party tooling must not use `lex.*`; the core may add new `lex.*` labels without versioning concerns. Non-reserved labels remain freely available for extensions (`mycompany.include`, `docs.embed`, etc.).

3. Resolution Model

    3.1 Parser Remains Pure

        The parser does not touch the filesystem. A `lex.include` annotation parses exactly like any other annotation: label, parameters, empty children. This is a hard invariant: it preserves synchronous, local, deterministic parsing, and it keeps the parser usable in WASM, LSP hot paths, and sandboxed environments without I/O permissions.

    3.2 Analysis-Layer Resolution Pass

        Resolution lives in the analysis layer (crate: `lex-analysis`). A new module exposes a function roughly shaped as:

            resolve_includes(
                document: Document,
                root: Path,
                loader: Loader,
                config: ResolveConfig,
            ) -> Result<Document, IncludeError>
        :: signature ::

        The pass walks the tree, finds each `lex.include` annotation, asks the loader to produce the source text, parses it (using the existing parser), recursively resolves its own includes (subject to the depth and cycle limits), strips its title and document-level annotations, and splices its root session's children into the including annotation's children slot.

        Consumers that want the pre-resolution tree (editor tooling displaying the include as a collapsed node, for instance) simply skip the pass.

    3.3 Injectable Loader

        The loader is an injected callable, not hard-coded to `std::fs`. This lets:

        - Tests use in-memory fixtures.
        - WASM builds provide a JS-backed loader.
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

        Every resolution has exactly one root. It defaults to the directory of the entry-point document (the file passed to `lex format`, `lex-lsp`'s workspace root, etc.). It is overridable via config (`lex.toml`) or CLI flag.

        All paths — relative or root-absolute — normalize to a canonical absolute path. That canonical path must live inside the root. Any normalized path that escapes the root is a resolution error, even if the on-disk file exists.

    4.4 No Escape

        The root is enforced by canonicalization and prefix check, not by blocklists or per-directory rules. This is intentional: permissive models with allow/deny lists are where security bugs live. One root, one rule, no exceptions.

5. Merge Semantics

    5.1 Where the Content Lands

        The included document's root session's children are spliced into the `lex.include` annotation's `children` slot. Nothing else in the AST shape changes.

        There is no "inject at document root" escape hatch. It would conflict with the attachment rules of annotations and duplicate an already-clean pattern: put the `lex.include` at the top of the including document.

    5.2 Dropped on Merge

        Two elements of the included document are discarded during the splice:

        - The document title. A document has at most one title; the including document's title wins.
        - Document-level annotations (those attached to `DocumentStart`). They describe the included file as a standalone artifact, not as a fragment. Authors who want them to apply in the merged context put them adjacent to the include site.

        Everything else — sessions, definitions, verbatim blocks, tables, lists, paragraphs, element-level annotations — carries over verbatim.

    5.3 Origin Tracking

        Each spliced node carries its origin file path. This is used by:

        - File-reference resolution (so `[./figure.png]` in an included atom resolves relative to the atom, not the merged document).
        - Diagnostics (so errors point to the authoring file, not the post-merge location).
        - LSP goto-definition and hover.

        Origin tracking is a side-table or per-node field; it does not rewrite any content.

6. References Across the Merge

    6.1 Footnotes

        Numbered footnote references (`[1]`, `[2]`, ...) scope to the file they were authored in. Resolution of footnote references to their definitions happens per-file, before merging. After merge, a reference carries a resolved target (or a dangling-reference diagnostic); there is no cross-file number collision to worry about.

    6.2 Session References

        Session references like `[#2.1]` are string targets, resolved against the tree the analysis layer sees. After merging, the tree the resolver sees is the merged tree. A reference like `[#2.1]` inside an included atom means "session 2.1 in my current context" — which, after merge, is the merged context.

        No path rewriting is performed. If the author's intent was "2.1 within this atom's private namespace," that intent is not expressible in v1. The cross-document reference syntax (section 9.2) will address this in a future version.

    6.3 File References

        File references like `[./figure.png]` and `[/shared/logo.svg]` are not touched by the parser. The file-reference resolver uses the origin-file tag (section 5.3) to resolve relative paths against the authoring file, and root-absolute paths against the document root.

    6.4 No Path Rewriting

        The merged AST does not mutate reference payloads. Origin tagging lets downstream resolvers do the right thing without losing authorial intent.

7. Safety

    7.1 Cycle Detection

        The resolver maintains a set of canonicalized paths currently being resolved. Encountering a path already in the set is a cycle error. Non-negotiable for v1.

    7.2 Depth Limit

        The maximum include depth is 8. This is enough for any reasonable atomization strategy (aggregator includes per-chapter includes per-section includes) while bounding the resolver's worst-case work. Configurable via `ResolveConfig` for pathological document sets; hitting the limit is an error, not a silent truncation.

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

        `:: lex.include src="..." ::` already parses today as a normal annotation with parameters. The parser needs no grammar change to support this proposal. The entire feature is a new resolution pass plus a reserved label.

    10.2 Accessor Convenience

        A small convenience accessor on `Annotation`:

            impl Annotation {
                fn is_include(&self) -> bool { ... }
                fn include_src(&self) -> Option<&str> { ... }
            }
        :: signature ::

        Purely ergonomic. The underlying data is already available via the general parameter API.

    10.3 Resolution Module Shape

        A new module `lex_analysis::includer` exposes:

            pub struct ResolveConfig {
                pub max_depth: usize,   // default 8
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

        The LSP runs the resolution pass on document open and on included-file change (via file watch). Diagnostics are surfaced at the `lex.include` annotation's range when resolution fails. Goto-definition on the include jumps to the target file. Hover on the include can show a preview of the included content.

    11.3 CLI

        `lex format` and related commands resolve includes by default. A `--no-includes` flag produces the pre-resolution tree, useful for inspecting a document atom in isolation.

    11.4 Formatter

        The formatter never expands includes. It operates on the surface AST: the `lex.include` annotation is formatted like any other annotation. Expansion is a separate concern.

12. Open Questions

    12.1 Entry-Point Root vs. Nearest-Config Root

        Default root is the entry-point document's directory. Should `lex.toml` discovery (walking upward from the entry point) override that? Leaning yes: matches the existing clapfig config discovery, gives project-wide includes without per-invocation config.

    12.2 Title-Only Included Files

        A file with only a title and no body is a legal Lex document. What does including it do? Current answer: the title is dropped, the body is empty, the include resolves to nothing. This is consistent but surprising. A diagnostic ("included file has no body") may help.

    12.3 Annotation-Level Parameter Passing

        The spec above treats `src` as the only parameter with semantic meaning. Should future-proofing allow additional user parameters to flow through as metadata on the resolved content? Leaning no: simpler to wait until a concrete use case forces the design.

    12.4 Formatter Behavior for Long src Values

        Very long paths in a `src=` parameter are ugly. The existing annotation parameter formatter rules apply. Likely no special-casing needed; flagged here for validation during implementation.

13. Summary

    The proposal adds no grammar, no new element, and no parser change. It adds:

    - A reserved annotation label (`lex.include`).
    - A reserved namespace (`lex.*`).
    - An analysis-layer resolution pass with cycle detection, depth limiting, and root-escape enforcement.
    - A documented security model (relative and root-absolute paths only).
    - An explicit list of things that are out of scope — forever (shell, absolute FS paths, templating, conditionals) or for now (URLs, partial includes, cross-document references).

    The goal is to give the ecosystem a sanctioned beachhead: a small, canonical core that tooling can build on without each implementer reinventing it, and without locking out the more ambitious features that may arrive later.
