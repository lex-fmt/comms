Proposal: Extending Lex via Label Namespaces

    Labels — the identifiers that appear in annotations (`:: foo ::`) and verbatim closings (`:: rust ::`) — are Lex's natural extension points. They sit on metadata and on non-Lex content, and they already organise themselves into namespaces by convention (`lex.include`, `acme.foo`). Today only `lex.*` has declared semantics; everything else is free-form. An editor that wants to do something useful with `acme.foo` has to invent its own discovery, schema, and validation, and any two tools that try will diverge.

    This proposal extends label-as-namespace into a complete extension system: namespaces that guard schemas, ownership grounded in a decentralised convention rather than a registry, and tooling integration via a small handler protocol. The parser does not change. The `lex.*` namespace stays special only in being hard-coded; every other code path treats it identically to a third-party namespace.

    The intent is to give third parties — orgs, editors, build pipelines — a sanctioned way to attach typed data to Lex AST nodes, with editor support for free, without each implementer reinventing the surface.

1. Motivation

    1.1 Labels Are Already the Extension Point

        Lex's annotation surface (`:: label params ::`) and verbatim closings (`:: label ::`) are the only places where arbitrary identifiers attach to AST nodes. They cover the two interesting attachment points: structural metadata, and non-Lex content (code, data, embedded fragments). Any extension worth designing routes through one of these.

        Namespaces fall out of dotted identifiers naturally. `lex.include` is the include feature; `acme.foo` is whatever Acme decides. The dot is purely conventional — there is no parser-level namespace concept — and that is exactly right: the parser stays general, the meaning lives in tooling.

    1.2 What Is Missing

        The free-form status quo lacks three things:

        - *Ownership.* Anyone can write `acme.foo` in a document. Nothing prevents two different organisations from defining incompatible `acme.foo` semantics. Without a resolution mechanism, authors have no way to assert "I mean Acme Corp's `foo`."
        - *Schema.* Tooling has no machine-readable description of what parameters a label takes, what types they have, or what AST nodes it may attach to. Each editor invents its own autocomplete table and falls behind reality.
        - *Hooks.* A namespace owner has no way to react to invocations of their labels — to validate, to transform, to sync with an external system — without rebuilding the discovery and dispatch machinery from scratch.

    1.3 Design Goals

        - Document surface stays terse. Authors write `:: acme.foo … ::`, not URIs.
        - Ownership is decentralised. No central registry to run, no account system, no naming arbitration.
        - Schemas alone unlock the 80% case (autocomplete, validation, hover) — no code execution required.
        - Active hooks are universal-language and trust-gated.
        - One code path. `lex.*` and third-party namespaces flow through identical resolution, validation, and dispatch; the only difference is where `lex.*` schemas come from.
        - The parser is untouched. The entire feature is config + resolver + handler protocol.

2. Prior Art

    Several patterns informed the design:

    - *Homebrew taps.* `user/repo` resolves to `github.com/user/homebrew-repo` by convention. Pure social contract, zero infrastructure. Adopted as the surface ergonomic for the GitHub case.
    - *Nix flakes.* URI schemes (`github:`, `gitlab:`, `https:`, `path:`) plus content-hash locking. Adopted as the underlying resolution model.
    - *Kubernetes CRDs.* Reverse-DNS group names tie ownership to domain ownership. Considered for the namespace surface; rejected as too verbose for the document syntax.
    - *Block Protocol.* Schema-described portable blocks with optional active handlers. Closest spirit-match for the schema tier.
    - *MyST roles and directives.* Declared signatures unlock editor UX without forcing code. Validated the schema-only-as-default approach.
    - *LSP / DAP / BSP.* JSON-RPC over stdio is the universal-language sweet spot for per-document interaction. Adopted as the handler protocol.

    The full survey lives in design notes; this section names only the patterns that survived into the design.

3. Namespace Ownership

    3.1 The Tap Convention

        Authors declare the namespaces a document uses in `lex.toml`. The simplest form is a *tap*, modelled on Homebrew: a single key like `acme = { tap = "acme" }` in `[labels]` expands to `github:acme/lex-labels` — schemas live at `github.com/acme/lex-labels`. Documents that use the namespace write the short form throughout: `:: acme.foo … ::`. The verbosity lives in config; the document syntax stays terse. The full block format is in *Example A* ([#11.1]).

        Ownership is grounded in GitHub's existing account system. There is no central Lex registry. Two organisations cannot both own `acme` for the same reason they cannot both own `github.com/acme`.

    3.2 URI Forms

        Tap shorthand is sugar over a URI scheme. Any of the URI forms shown in *Example A* ([#11.1]) is legal as the value of a `[labels]` entry: `github:`, `gitlab:`, `https:`, `path:`, `git+ssh:`. Resolvers are pluggable, so additional schemes can be added without touching the document surface.

        This decoupling means GitHub is the default but never privileged. Internal corporate setups, self-hosted Git, or local development directories all work.

    3.3 The lex.* Namespace

        `lex` is registered at startup from a compiled-in schema bundle. The compiled-in registration is the *only* difference between `lex` and a third-party namespace: schema lookup, validation, attachment policy, and handler dispatch all flow through the same code path. The `lex.toml` parser denies `lex = …` as a key — that single line of validation is the entirety of the reservation. One code path, one denied key, no fork.

        Concretely, the `lex.*` schemas (`lex.include`, `lex.toc`, future additions) are written in the same YAML format third parties ship. They are compiled into the binary at build time but validated through the same resolver. Dogfooding the same schema infrastructure catches schema-format regressions for free and prevents the core's needs from drifting away from what extensions can express.

    3.4 Caching and Reproducibility

        Resolved schemas are content-hashed and cached at `~/.cache/lex/labels/<hash>/`. Two clients with the same `lex.toml` resolve to the same schema as long as upstream has not moved a tag.

        For mutable references (e.g., branches like `#main`, or tap defaults), the cache is treated as valid for a fixed TTL (e.g., 24 hours), after which the resolver performs a background network check. Users can force a refresh with `lexd labels update`. Immutable references (tags or specific Git SHAs) are cached indefinitely.

        A lockfile is *not* part of v1. Caching alone gives reproducibility in the absence of upstream tampering, and lockfile machinery is friction in source trees full of one-off documents. If real-world reproducibility complaints arrive, a `lex.lock` file is additive — the URI scheme is already content-addressable.

4. Schemas

    A namespace ships a directory of YAML files, one per label. Each file declares the label, its parameters (with types, defaults, and required-ness), its attachment rules (which Lex containers it may attach to, whether text content is allowed), the labels of any verbatim variants it owns, and optional handler metadata. The full schema format is given in *Example B* ([#11.2]).

    Editor tooling consumes the schema directly: autocomplete fills in parameter names and types, hover shows descriptions, diagnostics flag missing or wrong-typed parameters, code actions offer fix-its for misspelled names. None of this requires code execution. A schema is a static YAML file; a label's "behaviour" in editors emerges entirely from the schema unless the schema declares otherwise.

    Schema discovery is uniform across namespaces. `lex.toml` names the namespace's source URI; the resolver fetches and caches the directory; each `*.yaml` inside contributes one label. Adding a label to a namespace is a single-file commit upstream and a single cache-bust downstream.

5. Tooling Hooks

    The hook surface is layered. Each tier is strictly opt-in; most labels live happily at the lowest tier.

    5.1 Schema-Only Use (the Default)

        Most labels never need code. The schema alone unlocks autocomplete, validation, hover, and search. `lexd labels emit doc.lex --label acme.foo` produces a JSON stream of label invocations together with their attached AST nodes — pull-based integration with anything that consumes JSON. The 80% case requires no handler, no trust prompt, and no process spawning.

    5.2 Subprocess Handlers

        Labels that need to do active work — sync with an issue tracker, fetch live data, transform output, expose richer code actions — declare a handler in their schema YAML. `lex-lsp` spawns the handler once per session and talks JSON-RPC over stdio, modelled on LSP itself. Events deliver validated parameters and node context; responses can return diagnostics, code actions, hover content, or transformation patches. The protocol shape is given in *Example C* ([#11.3]).

        Handlers are universal-language: anything that can talk JSON-RPC over stdio works. They are persistent processes, so startup cost amortises across the session. They are also unsandboxed, which leads directly into the trust model in §6.

    5.3 WASM Handlers (Deferred)

        A future variant carries the same wire shape but loads handlers as WASM components in-process for sandboxed, low-latency operation. Deferred until a real use case forces it — the WASM component-model toolchain is still maturing in 2026, and the subprocess tier covers everything we know we need today. The handler-author surface is designed so that adding WASM later does not change it.

6. Trust Model

    Handlers are unsandboxed code. They run with the same privileges as the host process. Default policy is asymmetric:

    - In *non-interactive contexts* — `lexd format`, `lexd convert`, `lexd inspect`, CI runs, pre-commit hooks — handlers are off. `--enable-handlers` opts in. A label that triggers code execution from a freshly-cloned repository is a supply-chain attack; the default closes that vector.
    - In *LSP-attached editor sessions*, the first invocation of a handler prompts for trust. Crucially, trust is pinned not just to the namespace, but to the specific `command` string specified in the schema. The prompt is: "Trust `acme/lex-labels` to execute `acme-lex-handler`?" If the upstream schema changes the command between cache invalidations, the user is re-prompted. The decision is persisted per workspace, modelled on VS Code's workspace trust.

    Schemas (the schema-only tier of §5.1) are not gated by trust. They cannot execute code, they cannot read or write files, and the validation they drive is local to the document. Fetching the schema is the same operation as fetching any other versioned text from a Git host.

7. lex-lsp Is the Host

    Editor extensions do not talk to handlers directly. `lex-lsp` is the single host: it resolves namespaces, loads schemas, spawns handlers, dispatches events, and surfaces results through standard LSP messages — diagnostics, code actions, completion items, hover, document symbols.

    This matches the established design rule that editor logic belongs in the LSP. Editor extensions stay UI shells. Any editor with LSP support — VS Code, Neovim, Zed, Helix, lexed — gets label-driven features for free, without per-editor extension code. A new editor entering the ecosystem starts fully featured.

    The same rule applies to the CLI. `lexd` and `lex-lsp` share a single resolver crate; CLI subcommands like `lexd labels emit` and `lexd labels validate` use the same code paths the LSP uses, so behaviour cannot diverge between editor sessions and command-line tooling.

8. Explicitly Out of Scope

    8.1 Community Registry

        Some package ecosystems run a single canonical registry mapping short names to URIs (Cargo's crates.io, npm). Lex labels v1 has none. Aliases live in each project's `lex.toml`. This avoids running infrastructure, avoids the alias-collision arbitration problem entirely, and keeps the design honest about its decentralisation. If real-world usage justifies a registry later, it is purely additive.

    8.2 Lockfile

        See §3.4. Caching is content-hashed; a `lex.lock` file can be added later without breaking changes.

    8.3 WASM Handlers

        See §5.3.

    8.4 Schema Inheritance and Composition

        A schema cannot extend or include another schema in v1. If two namespaces want to share a parameter set, they duplicate. Composition is a real feature but a different design conversation; the simple flat case wants to ship first.

    8.5 Per-Document Handler Configuration

        A document cannot pass session-wide configuration to a handler in v1 (no `[labels.acme.config]` block in `lex.toml` flowing through to the handler's startup). The handler protocol is intentionally narrow at the start; richer configuration is additive.

9. Future Extensions

    Directions the design leaves room for, without committing:

    - *Lockfile* (§3.4). One file, content-hash-pinned, opt-in.
    - *WASM handlers* (§5.3). Same protocol, sandboxed delivery.
    - *Community alias registry* (§8.1). Optional layer on top of `lex.toml` aliases.
    - *Schema composition* (§8.4). Extends the YAML format, no resolver change.
    - *CLI handler invocation.* `lexd labels run acme.sync doc.lex` to trigger handlers outside an editor session, with the same trust prompt.
    - *Cross-namespace dependencies.* A schema declaring it requires another namespace to also be installed (e.g., `acme.task` depends on `acme.user`).

    None of these require breaking changes to the surface defined here.

10. Summary

    The proposal adds:

    - A `[labels]` block in `lex.toml` mapping namespaces to URI-resolvable schema sources.
    - A YAML schema format that any namespace ships.
    - A subprocess handler protocol modelled on LSP, gated by trust.
    - A single host (`lex-lsp`) that turns schemas and handlers into standard LSP capabilities.
    - The same code path for `lex.*` and third-party namespaces, with the only special-casing being the compiled-in source of `lex.*` schemas and a single denied `lex.toml` key.

    The design keeps the parser pure, keeps the document surface terse, keeps ownership decentralised, and gives third parties the same affordances the core enjoys. It is deliberately narrow: no community registry, no lockfile, no WASM, nothing that can be added later without breaking changes.

11. Examples

    Three reference artifacts illustrate the surface defined above. Each is a complete, copy-pasteable example. The main text refers to them as *Example A*, *Example B*, and *Example C*.

    11.1 Example A — the `[labels]` block in `lex.toml`

        Tap shorthand and full URI forms coexist; both produce the same internal representation. Tap shorthand expands to `github:<value>/lex-labels`. A bare string value is a URI. The expanded table form is used when more than the URI and `rev` are needed (e.g., `subdir`). The `rev` key pins a tag, branch, or commit; absent, the resolver uses the namespace's declared default branch.

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

    11.2 Example B — schema YAML

        One file per label, declaring params (with types and defaults), attachment rules (which Lex containers the label may attach to), an optional verbatim-label flag (whether the label is also legal as a verbatim block closing), and optional handler metadata. Type checking is fail-closed: an unknown type in a schema is a schema error.

        Schema for a hypothetical `acme.task`, which attaches to annotations and produces validation diagnostics plus a code action to open the task in a tracker:

            schema_version: 1
            label: acme.task
            description: |
                References a task in Acme's tracker. Validates that the task ID
                exists; offers a code action to open it in the browser.

            params:
                id:
                    type:        string
                    required:    true
                    pattern:     "^ACME-[0-9]+$"
                    description: "Acme tracker ID, e.g. ACME-1234."
                assignee:
                    type:        string
                    required:    false
                    description: "Username of the assignee."
                priority:
                    type:        enum
                    values:
                        - name: low
                          description: "Whenever"
                        - name: medium
                        - name: high
                        - name: urgent
                          description: "Drop everything"
                    default:     medium

            attaches_to:
                - annotation
                - definition
                - session

            text:
                presence:    optional
                description: "Free-form note about the task."

            verbatim_label: false

            handler:
                command: ["acme-lex-handler", "--config", "${HANDLER_CONFIG}"]
                events:  [on_label, on_validate, on_resolve_completion]
                timeout_ms: 2000
        :: yaml ::

    11.3 Example C — handler JSON-RPC protocol

        Modelled directly on LSP's notification and request shape. The handler binary is spawned with stdin/stdout pipes; messages are LSP-framed JSON-RPC. Diagnostics flow back to the host, which surfaces them through standard `textDocument/publishDiagnostics`. The same shape covers `on_resolve_completion` (returns enriched completion items), `on_hover`, and `on_code_action`. Adding a new event is backward-compatible: handlers ignore methods they do not implement.

        Initialization handshake (host to handler):

            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {
                    "lex_version": "0.10.2",
                    "namespace":   "acme",
                    "labels":      ["acme.task", "acme.user"]
                }
            }
        :: json ::

        Per-label event (host to handler, no response expected):

            {
                "jsonrpc": "2.0",
                "method":  "on_label",
                "params": {
                    "label":     "acme.task",
                    "params":    { "id": "ACME-1234", "priority": "high" },
                    "text":      null,
                    "node": {
                        "kind":    "annotation",
                        "range":   { "start": [12, 4], "end": [12, 48] },
                        "origin":  "chapters/02.lex"
                    }
                }
            }
        :: json ::

        Validation request (host to handler, response expected):

            {
                "jsonrpc": "2.0",
                "id": 17,
                "method": "on_validate",
                "params": { "label": "acme.task", "params": { "id": "ACME-9999" } }
            }
        :: json ::

        Validation response:

            {
                "jsonrpc": "2.0",
                "id": 17,
                "result": {
                    "diagnostics": [
                        {
                            "severity": "error",
                            "message":  "Task ACME-9999 not found in tracker.",
                            "range":    { "start": [12, 18], "end": [12, 28] }
                        }
                    ]
                }
            }
        :: json ::
