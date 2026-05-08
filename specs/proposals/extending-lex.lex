Proposal: Extending Lex via Label Namespaces

    A modern, open data format that wants wide adoption across specialised contexts has to be a platform, not a parser. Authoring, presenting, publishing, processing, transforming — every stage of a document's life accumulates tooling, and a format that doesn't make room for that tooling forces every consumer to reinvent it. Lex's parser, formatter, and linter are the floor. This proposal sets the next floor up: an extension system that turns Lex's existing label surface into a platform third parties can build on with minimal ceremony and without forking the language.

    The extensibility on offer is deliberately bounded. Lex does not let you invent new syntax — no new list markers, no new heading style, no new way to delimit a session. The only extension points are the two places where Lex already accepts arbitrary identifiers: annotations (`:: label params ::`) and verbatim block closings (`:: label ::`). Everything in this proposal hangs off those two surfaces. We believe this is the right balance between two failure modes — locked-down formats with no extension story, where every serious adoption needs a fork, and wide-open macro systems, where no two documents agree on what they mean. Bounded extensibility keeps a vanilla Lex parser able to read any document, while letting third parties attach typed semantics on top.

    Concretely, this proposal extends label-as-namespace into a complete extension system: namespaces that guard schemas, ownership grounded in a decentralised convention rather than a registry, hook integration points that name where in the pipeline extension code participates, and a single handler protocol delivered over three transports — native Rust traits, JSON-RPC subprocesses, and (deferred) WASM components. The parser does not change. The `lex.*` namespace stays special only in being hard-coded; every other code path treats it identically to a third-party namespace.

    Wire-level details — JSON-RPC method catalogue, payload schemas, AST node shapes, versioning rules — live in the companion document, *Specification: Lex Extension Wire Format* ([./lex-extension-wire.lex]).

1. Why a Platform, not a Parser

    1.1 The Use Case

        Lex aims to be useful across many specialised contexts: technical documentation, scientific publishing, legal drafting, internal corporate communication, narrative writing. Each context arrives with its own tooling appetite — issue-tracker links, citation managers, plasma-spec validators, regulatory annotations, screenplay format converters, brand-style enforcers. None of these belong in the core. All of them need to attach typed information to documents and get tooling support across the ecosystem.

        Consider an editorial commenting workflow:

            :: acme.commenting role="editor" ::
                John, I see the relevance for this inclusion, but I question its position. Considering:

                - The legal status is a core motivator for readers
                - Most people skim the later sections

                I'd argue for keeping it in the introduction.

                Screenshot:

                    This is how others are tackling it:
                :: image src="comparison.png" ::

        The annotation carries structured params (`role="editor"`), a parsed Lex body (paragraph, list, definition with a nested verbatim), and identity that downstream tools can thread replies off. None of that requires new syntax — annotations and verbatim blocks already exist — but realising it requires a contract between the annotation surface and the tools that consume it.

        Consider a publishing pipeline:

            :: mit.plasma-specs version=4 ::
                ... domain-specific content ...

        For this to be useful end-to-end, MIT's plasma-spec extension has to plug into converters (LaTeX out, HTML out), validators (does the version-4 spec hold?), editors (autocomplete the `version` parameter, hover its description), and importers (read from XMP, output to Lex). Without an extension story, every consumer reinvents discovery, validation, and dispatch. Two editors that both want to recognise `acme.task` end up with diverging autocomplete tables, diverging diagnostics, and incompatible code actions. Pipeline tools face the same problem at a different layer: each one hard-codes the namespaces it knows about or invents its own plugin protocol.

        The right level for the answer is the format itself. Define a single extension contract, and every consumer that honours it gets every namespace for free. Authors get terse syntax in their documents; namespace owners get one place to ship schemas and code; editors and pipelines get a uniform integration point. That is the shift from parser to platform.

    1.2 Bounded Extensibility

        The extension surface is narrow on purpose. A label can:

        - attach typed parameters and a body to an AST node (annotations)
        - own the contents of a verbatim block (verbatim closings)

        A label cannot:

        - introduce new structural syntax (no custom list markers, no new session styles, no alternative table delimiters)
        - alter the parsing of unlabelled content
        - require a Lex parser to know the label's schema in order to produce a parse tree

        The boundary matters because it preserves portability. A document using `mit.plasma-specs` and `acme.task` is still a valid Lex document under any conforming parser. The parser produces a tree with annotation and verbatim nodes carrying their labels and parameters; an extension-aware consumer adds semantics on top. A consumer that does not know the namespace renders the annotation as an annotation and the verbatim block as a code block — degraded, not broken.

        This rules out a class of extensions deliberately: anything that wants to invent new top-level syntax has to either ship its content inside a verbatim block (where the body is opaque to the parser) or reuse the existing structural elements. We consider this the right trade. The two failure modes — formats so locked down that adoption requires a fork, and formats so open that no two implementations agree on anything — are both worse than a small, principled extension surface.

2. What's Missing from the Status Quo

    Today, labels parse but mean nothing outside `lex.*`. Three concrete gaps:

    - *Ownership.* Anyone can write `acme.foo` in a document. Nothing prevents two different organisations from defining incompatible `acme.foo` semantics. Authors have no way to assert "I mean Acme Corp's `foo`."
    - *Schema.* Tooling has no machine-readable description of what parameters a label takes, what types they have, what AST nodes it may attach to, or what its body looks like. Each editor invents its own autocomplete table and falls behind reality.
    - *Hooks.* A namespace owner has no way to react to invocations of their labels — to validate, to transform, to render to another format, to sync with an external system — without rebuilding the discovery and dispatch machinery from scratch.

    All three are addressable without changing the parser, by giving labels a configuration story (ownership), a description format (schema), and a host that dispatches to namespace-owned code (hooks).

3. Prior Art

    Several patterns informed the design:

    - *Homebrew taps.* `user/repo` resolves to `github.com/user/homebrew-repo` by convention. Pure social contract, zero infrastructure. Adopted as the surface ergonomic for the GitHub case.
    - *Nix flakes.* URI schemes (`github:`, `gitlab:`, `https:`, `path:`) plus content-hash locking. Adopted as the underlying resolution model.
    - *Kubernetes CRDs.* Reverse-DNS group names tie ownership to domain ownership. Considered for the namespace surface; rejected as too verbose for the document syntax.
    - *Block Protocol.* Schema-described portable blocks with optional active handlers. Closest spirit-match for the schema tier.
    - *MyST roles and directives.* Declared signatures unlock editor UX without forcing code. Validated the schema-only-as-default approach.
    - *LSP / DAP / BSP.* JSON-RPC over stdio is the universal-language sweet spot for per-document interaction. Adopted as one of three transports.

4. Namespace Ownership

    4.1 The Tap Convention

        Authors declare the namespaces a document uses in `lex.toml`. The simplest form is a *tap*, modelled on Homebrew: a single key like `acme = { tap = "acme" }` in `[labels]` expands to `github:acme/lex-labels` — schemas live at `github.com/acme/lex-labels`. Documents that use the namespace write the short form throughout: `:: acme.foo … ::`. The verbosity lives in config; the document syntax stays terse. The full block format is in *Example A* ([#13.1]).

        Ownership is grounded in GitHub's existing account system. There is no central Lex registry. Two organisations cannot both own `acme` for the same reason they cannot both own `github.com/acme`.

    4.2 URI Forms

        Tap shorthand is sugar over a URI scheme. Any of the URI forms shown in *Example A* ([#13.1]) is legal as the value of a `[labels]` entry: `github:`, `gitlab:`, `https:`, `path:`, `git+ssh:`. Resolvers are pluggable, so additional schemes can be added without touching the document surface.

        This decoupling means GitHub is the default but never privileged. Internal corporate setups, self-hosted Git, or local development directories all work.

    4.3 The lex.* Namespace

        `lex` is registered at startup from a compiled-in schema bundle. The compiled-in registration is the *only* difference between `lex` and a third-party namespace: schema lookup, validation, attachment policy, hook dispatch, and transport selection all flow through the same code path. The `lex.toml` parser denies `lex = …` as a key — that single line of validation is the entirety of the reservation.

        Concretely, the `lex.*` schemas (`lex.include`, `lex.toc`, future additions) are written in the same YAML format third parties ship and back onto native-trait handlers in the same registry the third-party transports feed into. Dogfooding the same infrastructure catches schema-format regressions for free and prevents the core's needs from drifting away from what extensions can express.

    4.4 Caching and Reproducibility

        Resolved schemas are content-hashed and cached at `~/.cache/lex/labels/<hash>/`. Two clients with the same `lex.toml` resolve to the same schema as long as upstream has not moved a tag.

        For mutable references (e.g., branches like `#main`, or tap defaults), the cache is treated as valid for a fixed TTL (e.g., 24 hours), after which the resolver performs a background network check. Users can force a refresh with `lexd labels update`. Immutable references (tags or specific Git SHAs) are cached indefinitely.

        A lockfile is *not* part of v1. Caching alone gives reproducibility in the absence of upstream tampering, and lockfile machinery is friction in source trees full of one-off documents. If real-world reproducibility complaints arrive, a `lex.lock` file is additive — the URI scheme is already content-addressable.

5. Schemas

    A namespace ships a directory of YAML files, one per label. Each file declares the label, its parameters (with types, defaults, and required-ness), its attachment rules (which Lex containers it may attach to), the *body shape* (none, raw text, or parsed Lex subtree), whether the label is also legal as a verbatim block closing, the *hooks* it implements, declared *capabilities* (file-system, network), and optional handler metadata. The full schema format is given in *Example B* ([#13.2]).

    5.1 Body Shape

        An annotation's body — the content between the opening `:: label … ::` and its dedent — is a real Lex subtree, not a free-form string. The schema declares which body shape a label expects:

        - `body.kind: none` — the label is a marker only (e.g., `lex.toc`).
        - `body.kind: text` — the body is opaque text. The parser does not descend into it.
        - `body.kind: lex` — the body is parsed Lex, and the handler receives the full AST subtree (paragraphs, lists, definitions, nested annotations, even nested verbatim blocks).

        The `lex` body shape is what makes commenting threads, structured discussion, and rich annotations feasible. A `acme.commenting` annotation can carry a body that itself contains lists, definitions, and embedded images, and the handler receives that body as a parsed tree — not as a string to re-parse.

        Verbatim usage is orthogonal: a label declared with `verbatim_label: true` is additionally legal as a verbatim block closing, where the body is always opaque text by definition of the construct. A single label may be usable both as an annotation (with its declared `body.kind`) and as a verbatim closing (with text body).

    5.2 Schema Discovery

        Editor tooling consumes the schema directly: autocomplete fills in parameter names and types, hover shows descriptions, diagnostics flag missing or wrong-typed parameters, code actions offer fix-its for misspelled names. None of this requires code execution.

        Schema discovery is uniform across namespaces. `lex.toml` names the namespace's source URI; the resolver fetches and caches the directory; each `*.yaml` inside contributes one label. Adding a label to a namespace is a single-file commit upstream and a single cache-bust downstream.

6. Hook Integration Points

    Hooks declare *when in the document's lifecycle* an extension's code participates. A label's schema names which hooks it implements; the host calls only those, at the right pipeline stage. There are five integration points, each tied to a distinct phase of processing.

    6.1 Parse

        Pure. No hooks fire. Output is the raw AST with label invocations as opaque labelled nodes carrying their parameters and (for `body.kind: lex` labels) parsed body subtrees. A document parses identically with or without any extensions installed.

    6.2 Resolve

        Hooks with `resolve` may return AST replacement subtrees, which the host splices into the parent tree before analysis or rendering. This is `lex.include`'s phase, generalised: any namespace can implement label-driven content splicing under the same protocol.

        The resolve phase has cycle detection and depth limits, mirroring `lex.include`'s safeguards. A hook returning a subtree containing further resolve-eligible labels has those resolved transitively.

    6.3 Analyze

        Hooks with `validate` return diagnostics for the hosting document. Hooks with `label` are notified informationally with no response expected — useful for handlers that maintain external state (caches, indices). Both fire after resolve, on the spliced tree.

    6.4 Render

        Hooks with `render` are called by `lexd convert` and downstream pipeline tools. The hook receives the label's params and body subtree plus a target format identifier (`html`, `latex`, `markdown`, `pdf`, or any namespace-defined format), and returns either a target-format string snippet or, for tree-shaped target formats, a wire AST in the target's vocabulary.

        This is the integration point that turns Lex into a publishing platform. A `mit.plasma-specs` namespace can declare `render: [latex, html]` and have its content participate in any conversion pipeline that calls `lexd convert`. An importer can ship as a separate tool that produces `mit.plasma-specs` annotations from XMP or LaTeX input; the export side and the editor side need no awareness of where the annotation came from.

    6.5 Interact

        LSP-only hooks: `hover`, `completion`, `code_action`. Fire in response to corresponding LSP requests, on labelled nodes. Surface as standard LSP responses to the editor.

    Each label's schema names which integration points it participates in. A label that only contributes diagnostics declares `hooks: { validate: true }`. A label that drives output declares `hooks: { render: [html, latex] }`. A label that does both declares both. The host pre-computes which phases need to call into which namespaces and skips namespaces whose hooks are not relevant to the operation in flight.

7. Transport Tiers

    Hooks are a contract, not a delivery mechanism. The same hook events flow over three transports; a namespace declares which transport delivers its handler.

    7.1 Native Rust Trait

        The protocol's source-of-truth: a `LexHandler` trait in the public `lex-extension` crate, with one method per hook event (`on_validate`, `on_render`, `on_resolve`, etc.). Built-in `lex.*` handlers are native impls compiled into the host. Library consumers embedding Lex in their own Rust applications (a docs pipeline, a publishing server, a custom CLI) register native handlers directly with the engine — zero IPC, type-safe payloads, no subprocess to spawn. The trait sketch is in *Example C* ([#13.3]).

        Wire AST types used by the trait are stable across lex-core versions (the trait imports them from `lex-extension`, not from lex-core internals). Internal AST changes do not break native handlers.

    7.2 Subprocess + JSON-RPC

        The default transport for third-party shipping. A handler binary is spawned by the host with stdin/stdout pipes, and messages are LSP-framed JSON-RPC. The wire format and method catalogue are specified in the companion document, *Specification: Lex Extension Wire Format* ([./lex-extension-wire.lex]).

        Subprocess handlers are universal-language: anything that can talk JSON-RPC over stdio works. They are persistent processes, so startup cost amortises across the session.

    7.3 WASM Components (deferred)

        The same hook events delivered as imports/exports of a WASM component running in-process. Sandboxed by default, low-latency, polyglot at the source-language level. Deferred until the component-model toolchain is consistently usable across the languages namespace authors care about. The handler-author surface (the trait shape, the event payloads) is designed so that adding a WASM transport later does not change it.

    7.4 Choosing a Transport

        A namespace ships exactly one transport for v1. Pick by these axes:

        - *Native trait.* Built-ins, in-process Rust embedders, performance-sensitive cases. Compile-time coupling to a specific `lex-extension` major version.
        - *Subprocess.* Third-party ship-it case. Polyglot. Process startup cost per session, then amortised. The default for namespaces published to the wider ecosystem.
        - *WASM.* Polyglot in-process, sandboxed. Available when the WASM transport ships.

        Mixed-transport namespaces (a Rust crate plus a fallback subprocess for non-Rust embedders) are out of scope until someone needs them.

8. Trust Model

    Handlers run code. Schemas do not. The trust gate applies to handlers, not to schemas; fetching a schema is the same operation as fetching any other versioned text from a Git host.

    The handler trust decision splits along three axes:

    - *Source.* How did the schema arrive? An explicit local path (`--ext-schema ./mit-plasma.yaml`) is implicitly trusted by the user pointing at it. A namespace declared in the project's `lex.toml` is a deliberate dependency. A schema arriving only via cache or marketplace lookup is unvouched-for.
    - *Surface.* Where is the handler being run? A one-shot CLI invocation, a long-running LSP session, and a CI job have very different exposure profiles.
    - *Capability.* What does the handler need? A *pure* handler that consumes parameters and returns diagnostics has a small attack surface. A *full* handler that opens files or makes network calls has a much larger one. The schema declares capabilities (`capabilities: { fs: false, net: false }`); the host enforces the declaration by sandboxing the handler at the OS level so that pure handlers cannot escape their declared capabilities even if compromised.

    The default policy can be expressed as a matrix:

    Handler trust defaults:
        | Source                         | CLI one-shot   | LSP session    | CI            |
        | `--ext-schema ./local.yaml`    | on             | prompt + pin   | off (flag)    |
        | `lex.toml` namespace, pure     | on             | on             | on            |
        | `lex.toml` namespace, full     | prompt + pin   | prompt + pin   | off (flag)    |
        | cache-only / marketplace       | prompt + pin   | prompt + pin   | off (flag)    |
    :: table align=lcccc ::

    The pure-handler row is the load-bearing one for the converter ecosystem: declared no-fs, no-net handlers run by default in `lexd convert` without `--enable-handlers`, so a documentation pipeline that fans out to ten extension-rendered formats does not require ten interactive trust prompts.

    When a prompt fires, trust is pinned not just to the namespace, but to the specific handler `command` string declared in the schema. If the upstream schema changes the command between cache invalidations, the user is re-prompted. The decision is persisted per workspace, modelled on VS Code's workspace trust.

9. Hosts

    Three integration surfaces share a single resolver and registry crate (`lex-extension-registry`). All three see the same handlers via the same `LexHandler` trait; differences are lifecycle and which hooks they invoke.

    9.1 lexd CLI

        Reads `lex.toml [labels]` and `--ext-schema` flags at startup, resolves namespaces, instantiates the right transport per namespace, registers handlers in the registry. Subcommands invoke the relevant hooks: `lexd convert --to html` walks the AST and calls `render`; `lexd labels validate` calls `validate`; `lexd labels emit --label X` produces a JSON stream of label invocations for pull-based integration with anything that reads JSON.

    9.2 lex-lsp

        Same registry, longer lifetime. Subprocess handlers stay warm for the editor session. LSP-specific hooks (`hover`, `completion`, `code_action`) are bridged to standard LSP responses; the editor extension stays a UI shell, with no per-namespace code.

        Any editor with LSP support — VS Code, Neovim, Zed, Helix, lexed — gets label-driven features for free, without per-editor extension code. A new editor entering the ecosystem starts fully featured.

    9.3 Public Rust API

        Library consumers embedding Lex in their own Rust applications use the `lex-extension` crate directly. The `Engine` builder accepts both `lex.toml`-driven subprocess handlers and directly-registered native handlers; the registry routes labels to whichever transport delivers them.

        Embedder example:

            use lex::Engine;
            use lex_extension::{LexHandler, LabelCtx, Format, RenderOut};

            struct MyPlasmaHandler;
            impl LexHandler for MyPlasmaHandler {
                fn on_render(&self, ctx: &LabelCtx, fmt: Format) -> Option<RenderOut> {
                    // produce target-format output for `mit.plasma-specs`
                    todo!()
                }
            }

            let engine = Engine::builder()
                .with_config_file("lex.toml")?              // wires subprocess handlers
                .register_handler("mit.plasma", MyPlasmaHandler)
                .build()?;

            let doc = engine.parse(source)?;
            let html = engine.render(&doc, Format::Html)?;
        :: rust ::

10. Explicitly Out of Scope

    10.1 Community Registry

        Some package ecosystems run a single canonical registry mapping short names to URIs (Cargo's crates.io, npm). Lex labels v1 has none. Aliases live in each project's `lex.toml`. This avoids running infrastructure, avoids the alias-collision arbitration problem, and keeps the design honest about its decentralisation. If real-world usage justifies a registry later, it is purely additive.

    10.2 Lockfile

        See [#4.4]. Caching is content-hashed; a `lex.lock` file can be added later without breaking changes.

    10.3 WASM Handlers

        See [#7.3].

    10.4 Schema Inheritance and Composition

        A schema cannot extend or include another schema in v1. If two namespaces want to share a parameter set, they duplicate. Composition is a real feature but a different design conversation; the simple flat case wants to ship first.

    10.5 Per-Document Handler Configuration

        A document cannot pass session-wide configuration to a handler in v1 (no `[labels.acme.config]` block in `lex.toml` flowing through to the handler's startup). The handler protocol is intentionally narrow at the start; richer configuration is additive.

    10.6 Mixed-Transport Namespaces

        A namespace ships one transport in v1. A namespace shipping a Rust crate plus a fallback subprocess (for non-Rust embedders) is out of scope until someone needs it.

11. Future Extensions

    Directions the design leaves room for, without committing:

    - *Lockfile* ([#4.4]). One file, content-hash-pinned, opt-in.
    - *WASM handlers* ([#7.3]). Same protocol, sandboxed delivery.
    - *Community alias registry* ([#10.1]). Optional layer on top of `lex.toml` aliases.
    - *Schema composition* ([#10.4]). Extends the YAML format, no resolver change.
    - *CLI handler invocation.* `lexd labels run acme.sync doc.lex` to trigger handlers outside an editor session, with the same trust prompt.
    - *Cross-namespace dependencies.* A schema declaring it requires another namespace to also be installed (e.g., `acme.task` depends on `acme.user`).

    None of these require breaking changes to the surface defined here.

12. Summary

    The proposal adds:

    - A `[labels]` block in `lex.toml` mapping namespaces to URI-resolvable schema sources.
    - A YAML schema format that any namespace ships, including a body-shape declaration that gives annotations real parsed bodies.
    - Five named hook integration points (parse, resolve, analyze, render, interact), with namespaces declaring which they participate in.
    - Three transport tiers (native trait, subprocess, WASM-deferred) carrying one protocol contract.
    - A trust model split along source × surface × capability that lets pure handlers run by default in CI and `lexd convert`.
    - Three hosts (`lexd`, `lex-lsp`, public Rust API) sharing a single resolver and registry.
    - The same code path for `lex.*` and third-party namespaces, with the only special-casing being the compiled-in source of `lex.*` schemas and a single denied `lex.toml` key.

    The design keeps the parser pure, keeps the document surface terse, keeps ownership decentralised, and gives third parties the same affordances the core enjoys — across editor, CLI, and library surfaces. Bounded extensibility is the load-bearing constraint: a Lex parser without any extensions still parses any conforming document.

    Wire-level details — JSON-RPC method catalogue, payload schemas, AST node shapes, versioning rules — live in the companion document, *Specification: Lex Extension Wire Format* ([./lex-extension-wire.lex]).

13. Examples

    Three reference artifacts illustrate the surface defined above. Each is a complete, copy-pasteable example.

    13.1 Example A — the `[labels]` block in `lex.toml`

        Tap shorthand and full URI forms coexist; both produce the same internal representation. Tap shorthand expands to `github:<value>/lex-labels`. A bare string value is a URI. The expanded table form is used when more than the URI and `rev` are needed (e.g., `subdir`).

        `lex.toml` `[labels]` block:

            [labels]
            acme    = { tap = "acme" }
            cern    = { tap = "cern", rev = "v2.1.0" }
            foolco  = "gitlab:foolco/lex-labels#main"
            legal   = "https://internal.example.com/lex-labels/"
            local   = "path:../shared/labels"

            [labels.bigorg]
            uri    = "git+ssh://git@internal.example.com/docs/lex-labels.git"
            rev    = "v3.4.0"
            subdir = "labels"
        :: toml ::

    13.2 Example B — schema YAML

        One file per label, declaring params, attachment rules, body shape, capabilities, hook participation, and (optionally) handler metadata.

        Schema for a hypothetical `acme.commenting`, which carries a parsed Lex body and produces validation diagnostics plus rendering hooks for HTML and Markdown:

            schema_version: 1
            label: acme.commenting
            description: |
                A comment thread attached to a Lex element. The body is a full
                Lex subtree (lists, definitions, nested annotations, embedded
                verbatim blocks).

            params:
                role:
                    type:        enum
                    values:
                        - name: author
                        - name: editor
                        - name: reviewer
                    required:    true
                resolved:
                    type:        bool
                    default:     false
                thread_id:
                    type:        string
                    required:    false
                    description: "Stable ID for reply threading."

            attaches_to:
                - paragraph
                - definition
                - session
                - annotation
                - list_item

            body:
                kind:        lex
                presence:    required

            verbatim_label: false

            capabilities:
                fs:  false
                net: false

            hooks:
                validate: true
                render:   [html, markdown]
                hover:    true

            handler:
                transport:  subprocess
                command:    ["acme-comment-handler", "--config", "${HANDLER_CONFIG}"]
                timeout_ms: 2000
        :: yaml ::

    13.3 Example C — the LexHandler trait

        Native handlers (built-ins, in-process Rust embedders) impl this trait directly. Subprocess and WASM transports are generic adapters that impl the same trait by serialising calls to JSON-RPC or component imports respectively. The exact event payloads (`LabelCtx`, `RenderOut`, `WireAst`, `Diagnostic`) are specified in the companion wire-format document.

        `LexHandler` trait sketch:

            use lex_extension::{
                LabelCtx, Diagnostic, RenderOut, WireAst, Hover,
                Completion, CodeAction, Format,
            };

            pub trait LexHandler: Send + Sync {
                fn on_label(&self, _ctx: &LabelCtx) {}

                fn on_validate(&self, _ctx: &LabelCtx) -> Vec<Diagnostic> {
                    Vec::new()
                }

                fn on_resolve(&self, _ctx: &LabelCtx) -> Option<WireAst> {
                    None
                }

                fn on_render(
                    &self,
                    _ctx: &LabelCtx,
                    _fmt: Format,
                ) -> Option<RenderOut> {
                    None
                }

                fn on_hover(&self, _ctx: &LabelCtx) -> Option<Hover> {
                    None
                }

                fn on_completion(&self, _ctx: &LabelCtx) -> Vec<Completion> {
                    Vec::new()
                }

                fn on_code_action(&self, _ctx: &LabelCtx) -> Vec<CodeAction> {
                    Vec::new()
                }
            }
        :: rust ::
