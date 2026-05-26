Proposal: Diagnostic Configuration

    Authors today control diagnostic emission through a single toggle (`diagnostics.spellcheck`). Every other warning the toolchain produces — missing footnotes, inconsistent table columns, forbidden label prefixes, schema validation failures — has its severity hard-coded at the emission site. Authors who hit a false positive have no recourse short of changing the document. Authors who want to escalate a warning to an error in CI have no recourse short of forking the tooling. This proposal extends the existing `[diagnostics]` block in `.lex.toml` with a per-rule configuration surface modelled on patterns Clippy, ESLint, and Ruff have settled on, and designed to grow into per-rule numeric options (line length, nesting depth, column counts) as future rules require them.

    The wire format for diagnostics does not change. Every diagnostic the toolchain emits already carries a stable string code (`missing-footnote`, `schema.unknown-label`, `lex.include.cycle`, and so on) — the same codes editor code actions match against. This proposal adds the configuration surface on top: a registry the analysis pass consults at emission time, populated from `[diagnostics.rules]` in `.lex.toml`, overlaying the hard-coded defaults baked into the diagnostic emission code.

1. Identifier Scheme

    Every diagnostic is addressed by its stable string code — the same value that travels on the LSP wire as `Diagnostic.code`. Two shapes:

    Built-in:
        Bare names, optionally dotted for sub-categories. The toolchain owns the meaning.

            missing-footnote
            unused-footnote
            table-inconsistent-columns
            forbidden-label-prefix
            schema.unknown-label
            schema.missing-param

    Extension-emitted:
        `<namespace>.<code>` where `<namespace>` is a registered extension namespace from `[labels]`.

            acme.task-due-date-missing
            mit.plasma-specs.invalid-version

    The two shapes do not collide. Extension namespaces are declared in `[labels]` and cannot be bare — a registered namespace always contributes the leading segment. A code with no leading-segment match against any declared namespace is therefore built-in by construction. The same convention governs label identifiers ([./extending-lex.lex]); authors learn one rule for both surfaces.

2. Severity Levels

    Three levels, modelled on Clippy:

    allow:
        The diagnostic is suppressed entirely. No analysis result, no LSP wire entry, no editor squiggle, no exit-code influence.

    warn:
        The diagnostic emits at its declared LSP severity — typically `Warning`. Editors render the standard underline.

    deny:
        The diagnostic emits at LSP `Error` severity regardless of its declared default, and `lexd lint --strict` exits non-zero.

    The choice of three levels rather than four (adding `info`) or five (adding `info` and `hint`) reflects the experience of long-running linters in the ecosystem: the gradient between `warn` and `info` is not a level users meaningfully reach for in configuration, and tooling treats `info` as a quieter warning either way. A diagnostic that wants quieter rendering declares an `Information` or `Hint` intrinsic severity in its emission code; the user-facing config language exposes only the three actionable choices. If a need for an `info` keyword emerges later, adding it is additive and breaks no existing configuration.

    2.1 Severity Mapping

        Each emitted diagnostic carries two severities — an *intrinsic* one declared at the emission site (the LSP severity that tells editors how to render it), and a *configured* one resolved through the registry (the on/off and escalation control).

        - `allow` short-circuits emission entirely; the intrinsic severity is moot.
        - `warn` emits with the intrinsic severity unchanged.
        - `deny` overrides the intrinsic severity with `Error`.

        This split lets the diagnostic author choose the editor rendering once (does this warrant a yellow underline or a subtle hint?) while leaving the consequential decision (does this stop the build?) to the configuration.

3. Rule Entries

    A rule entry takes one of two shapes:

    Severity only:
        Bare string value.

            "missing-footnote"           = "warn"
            "schema.unknown-label"       = "deny"
            "table-inconsistent-columns" = "allow"

    Severity with options:
        Array, severity first, then a table of rule-specific options.

            "line-too-long" = ["warn", { max = 100 }]
            "deep-nesting"  = ["warn", { max-depth = 6 }]

    The array form's first element is always the severity; subsequent elements are rule-specific option tables. No rule in scope today carries options, but rules with numeric thresholds (line length, nesting depth, column counts) plug into this surface without changing the schema. Rules that accept options must also accept the bare-string form, meaning "use the rule's documented default for every option" — `"line-too-long" = "warn"` resolves to whatever `max` the rule documents as its built-in default.

    Options are forwarded to the rule's emission code as `toml::Value`; the rule deserialises them into its own typed shape. The registry does not type-check options.

4. Configuration File

    The schema extends the existing `[diagnostics]` block with a `rules` map:

        [diagnostics]
        spellcheck = false

        [diagnostics.rules]
        "missing-footnote"            = "deny"
        "schema.*"                    = "warn"
        "acme.task-due-date-missing"  = "allow"
        "line-too-long"               = ["warn", { max = 100 }]

    Loading semantics follow the rest of `.lex.toml`. The `rules` field is a `BTreeMap<String, RuleConfig>` with an empty default, and clapfig populates entries from `[diagnostics.rules]` on top of that default. The registry is constructed by walking the populated map; codes absent from the map fall through to the intrinsic default hard-coded at the diagnostic's emission site. This keeps configuration files terse — authors mention only codes they want to change — and avoids forcing the config schema to enumerate every diagnostic the toolchain ships, which would couple the configuration vocabulary to toolchain version.

    The existing `diagnostics.spellcheck` boolean remains as a top-level convenience for the most common toggle. Internally it resolves to a `"spellcheck"` registry entry: `true` is equivalent to `"spellcheck" = "warn"`, `false` to `"spellcheck" = "allow"`. An explicit `[diagnostics.rules]` entry for `"spellcheck"` takes precedence over the boolean if both are set.

5. Prefix Selection

    Codes select by exact string match or by prefix glob. The glob matches against the full code string and respects dot boundaries:

        [diagnostics.rules]
        "schema.*"             = "warn"     # all schema.* lints
        "schema.unknown-*"     = "deny"     # narrower, takes precedence
        "schema.unknown-label" = "allow"    # narrowest, takes precedence over both

    Precedence rules:

    - Longest exact match wins. An exact code entry always beats a glob, regardless of glob specificity.
    - Among glob matches, the longest matching prefix wins.
    - Two patterns that would tie at the same specificity for the same code are a load-time error. The loader rejects the configuration and quotes the conflicting pair.

    Globs match the same way label-namespace matching works in `[labels]`: `schema.*` matches `schema.unknown-label` and `schema.missing-param`, but not `schema-validation` (no dot) or `myschema.unknown-label` (different leading segment).

6. Scoped Overrides

    Two refinements live above the file-level registry. Both reuse the existing annotation surface (no new syntax) and both compose with the file-level configuration through standard merging rules: the closest scope wins, ties impossible because annotation scopes nest.

    6.1 The `lex.rules` Annotation Namespace

        Annotation-side overrides live under the built-in `lex.rules.*` namespace, a sibling of `lex.include`, `lex.toc`, and the other `lex.*` built-ins. As with every `lex.*` label, the `lex.` prefix is optional in source: `rules.missing-footnote` and `lex.rules.missing-footnote` denote the same handler, the same way `table` and `lex.table` denote the same element. The shorthand is the everyday form; the canonical form is the disambiguator when an extension namespace could otherwise shadow it.

        The handler under `lex.rules.*` is a dispatcher rather than a per-label handler. It strips the `lex.rules.` prefix and treats the suffix as a diagnostic code lookup against the registry — the same bare codes used as keys in `[diagnostics.rules]`.

        The TOML/annotation asymmetry — bare codes in TOML, namespaced labels in annotations — is the natural consequence of the two surfaces' shapes. TOML keys live inside the `[diagnostics.rules]` table, which supplies the routing context once. Annotations are open-ended; routing has to ride on the label itself.

        Two annotation forms, both terse:

        Single-rule, single-line:

            :: rules.<code> :: <severity>

        Bulk, parameterized:

            :: rules allow="<code>, <code>, ..." warn="..." deny="..." ::

        Severity vocabulary is the same as TOML: `allow`, `warn`, `deny`. Annotation bodies cannot carry per-rule options — the array form `["warn", { max = 100 }]` is TOML-only. Annotation overrides set severity only; rules that take options always read those options from `.lex.toml`.

        Both forms scope to the annotation's body subtree (its descendants in the parse tree). At the document level (annotation as document metadata, before the title), the body subtree is the whole document.

    6.2 Per-Document Overrides

        Bulk-form annotation at the document head, applied to every diagnostic emitted from the document:

            :: rules allow="missing-footnote" deny="schema.unknown-label" ::

            My Document Title

                Content begins here. The missing-footnote diagnostic is
                suppressed for this entire document; schema.unknown-label
                is escalated to an error regardless of the workspace
                `.lex.toml`.

        A single-rule form at the document head also works (one annotation per rule); the bulk form is the ergonomic choice when more than one code needs an override.

    6.3 Per-Region Overrides

        Either form, scoped to a sub-tree. Single-rule for one-shots:

            :: rules.missing-footnote :: allow
                Draft section. References here are placeholders.

                [42] will be defined before publish.

        Bulk for multiple codes over the same region:

            :: rules allow="missing-footnote, table-inconsistent-columns" ::
                Block-level prose with a few intentionally rough patches.
                ...

    6.4 Resolution Order

        At emission time, the registry resolves a diagnostic's severity by walking outward from the emission position:

        - innermost enclosing `rules.*` annotation (single-rule form for an exact code; bulk form for inclusion in one of its parameter lists)
        - outer `rules.*` annotations, walking outward through ancestor containers
        - workspace `.lex.toml` rule (exact match before prefix glob, per §5)
        - the diagnostic's intrinsic default in code

        The first level to mention the code wins. Annotations at the document head are simply the outermost layer of this walk — there is no separate "document scope" in the resolver, just the document's outermost annotation envelope.

7. Listing the Registry

    The toolchain ships a `lexd lints` subcommand that prints the registry as a table: every code the running toolchain (core + loaded extensions) knows about, its description, its intrinsic default severity, and any user override resolved from the nearest `.lex.toml`. Output mirrors the spirit of `clippy --explain` and `ruff rule`. Two intended uses:

    - Authors writing `.lex.toml` consult `lexd lints` for the canonical code list; the toolchain is the source of truth, not the spec.
    - CI scripts diff `lexd lints` output across toolchain versions to detect newly-introduced rules and decide their severity before they fire in production.

8. Channel Independence

    The registry is the source of truth for what emits and at what severity. The presentation channel — LSP wire to an editor, CLI stderr from `lexd lint`, a CI report's JSON dump, an HTML build's footer of unresolved warnings — is a renderer of registry verdicts, not an owner of them. Every channel consults the same registry, honours the same `allow / warn / deny` resolution, and respects the same scoped `rules.*` annotations from §6.

    Practically, this unifies the diagnostic surface across editor and command line. The same `.lex.toml` that quiets `missing-footnote` in an editor quiets it in `lexd lint`. The same in-document `:: rules.schema.unknown-label :: deny ::` annotation that turns a warning red in the editor also makes `lexd lint --strict` exit non-zero on that file. Authors write configuration once; CI honours it without separate flags.

    Two specific implications:

    Parser errors:
        As parser failures pick up stable codes (`parse.unterminated-verbatim`, `parse.unexpected-token`, …) they join the registry on the same terms as analysis diagnostics. The configuration vocabulary does not distinguish between sources — a code is a code regardless of which pass emitted it. This is additive work, not part of this proposal.

    Non-suppressible diagnostics:
        Some codes are non-suppressible. A "missing closing `::`" error cannot be `allow`ed because the parse failed before an AST existed to render around. Registry entries carry a `suppressible` flag; an attempt to `allow` a non-suppressible code in `.lex.toml` is a load-time error (the loader names the offending code and quotes the file/line). Non-suppressible codes can still be escalated with `deny` (a no-op for parser errors, which are already fatal, but meaningful for any future "warning the toolchain insists you see").

    The emission contract for diagnostic-producing code mirrors this: emit a code, a position, an intrinsic severity. The producer does not know which channel will render the output. The registry decides whether emission happens; the channel decides how to draw it.

9. Extension Diagnostics

    Extension handlers emit diagnostics through the wire protocol with `<namespace>.<code>` identifiers ([./lex-extension-wire.lex]). The configuration surface in this proposal treats those identifiers identically to built-in codes — a user writes `"acme.task-due-date-missing" = "deny"` and the registry applies the override before the emitted diagnostic reaches any channel. Extension authors do not implement their own severity-override plumbing; honouring user configuration is the host's responsibility, applied uniformly across transports (native, subprocess, WASM) and channels (§8).

    Extension diagnostic codes appear in `lexd lints` output once the extension is loaded, with descriptions and intrinsic defaults sourced from the extension's schema bundle.

10. Out of Scope

    This proposal does not cover:

    - The exact set of diagnostic codes the toolchain ships. Codes are added and removed through the normal release cycle; the configuration *schema* is stable across those changes even when the *vocabulary* shifts.
    - Numeric thresholds for any specific rule. `line-too-long` is illustrative — its actual addition is a separate design with its own discussion.
    - A lockfile of in-effect rule overrides. `.lex.toml` is the source of truth; `lexd lints` is the inspection tool.
    - Replacement of `diagnostics.spellcheck` with a generic on/off mechanism. The boolean stays for ergonomics; spellcheck's deeper knobs (dictionaries, ignore lists) are a separate proposal.
