Specification: Lex Extension Wire Format

    This document specifies the wire-level contract between Lex hosts (`lexd`, `lex-lsp`, library embedders) and extension handlers, regardless of transport. It is the normative companion to *Proposal: Extending Lex via Label Namespaces* ([./extending-lex.lex]). That proposal motivates the design and names the parts; this one nails down the bytes.

    The contract has three audiences:

    - *Handler authors* who ship a namespace and need to know exactly what messages they will receive and what they must respond.
    - *Host implementers* who need to know how to dispatch hook events.
    - *Toolchain maintainers* who need to know what counts as a breaking change.

    Versioning rule: this format is identified by `wire_version`, an integer that increments on any breaking change to message shapes. New methods, new optional fields, and new values for string-shaped enums (severity, completion kind, etc.) are non-breaking; *new block AST kinds* and removing or retyping fields are breaking and require bumping the version. Hosts and handlers exchange `wire_version` in the `initialize` handshake and negotiate to the highest version both sides understand. See [#6] for the full policy. The current version is `2`.

1. Transport Framing

    1.1 Subprocess Transport

        LSP-framed JSON-RPC over stdin/stdout. Each message is preceded by a `Content-Length: N\r\n\r\n` header, where `N` is the byte length of the JSON-RPC payload that follows. JSON-RPC 2.0 conventions apply: requests carry an `id`; notifications do not; responses match a request's `id`.

        The host spawns the handler binary using the `command` array from the schema. Environment variable substitution happens before spawn; the host expands a small set of variables (`HANDLER_CONFIG`, `WORKSPACE_ROOT`, `LEX_CACHE`) and rejects unknown ones. Handler stderr is logged by the host but does not carry protocol traffic.

        Examples in this document show JSON payloads only; the framing is implicit.

    1.2 Native Rust Transport

        The `LexHandler` trait in `lex-extension` mirrors the wire format directly. Each method's parameters deserialise into Rust types; each return value serialises into the wire response. Native handlers do not actually serialise (they call the trait method in-process), but the type signatures are derived from the wire schema so that any divergence between native and subprocess transports is a compile error.

    1.3 WASM Transport (deferred)

        The same JSON payloads delivered as component-model imports/exports. Specified when the WASM transport ships. The handler-author surface is forward-compatible.

2. Wire AST

    The wire AST is the stable cross-version representation of Lex content that hooks consume and (for `on_resolve` and tree-shaped `on_render`) produce. It is *not* the lex-core internal AST. The internal AST is free to change between versions; the wire AST changes only on `wire_version` bumps.

    2.1 Common Fields

        Every node carries:

        - `kind`: string, the node type (see [#2.2]).
        - `range`: `{ "start": [line, col], "end": [line, col] }`. 0-indexed; `start` inclusive, `end` exclusive.
        - `origin`: optional string. Workspace-relative path of the file the node came from. Set when the node arrived via include resolution.

    2.2 Node Kinds

        Block kinds:

        - `document` — top-level container. Field: `children` (array of block).
        - `session` — heading + body. Fields: `title` (string), `marker` (optional, structured), `children`.
        - `definition` — subject + body. Fields: `subject` (string), `children`.
        - `paragraph` — text content. Field: `inlines` ([#2.3]).
        - `list` — ordered or unordered. Fields: `marker_style` (string), `items` (array of `list_item`).
        - `list_item` — one item. Fields: `inlines`, `children` (nested blocks).
        - `verbatim` — raw content with a label. Fields: `label`, `params` (object), `body_text` (string).
        - `table` — tabular content. Fields: `caption`, `header_rows` (int), `column_aligns` (array of string), `rows` (array of array of cell), `footnotes`. `column_aligns` carries one entry per column; values are `"left"`, `"center"`, `"right"`, or `""` (no alignment). `column_aligns.length` defines the table's column count: it MUST equal the longest row in `rows`. Cells in shorter rows are treated as missing (`""` alignment, empty content); rows MUST NOT exceed `column_aligns.length`. A peer that produces a wire AST violating this invariant is rejected under §2.2's malformed-tree rule.
        - `image` — media node with explicit fields. Fields: `src` (string), `alt` (string), `title` (optional string). Produced by `on_resolve` for `lex.media.image`-class verbatim labels; carries the same data the host would otherwise have flattened into `verbatim.params`.
        - `video` — media node. Fields: `src` (string), `title` (optional string), `poster` (optional string).
        - `audio` — media node. Fields: `src` (string), `title` (optional string).
        - `annotation` — labelled metadata. Fields: `label`, `params`, `body` (`null`, string, or `{ "kind": "block", "children": [...] }`).
        - `blank` — a deliberate blank-line group, surfaced when round-trip fidelity matters.

        The set of block `kind` values is closed within a `wire_version`. A host or handler that receives a wire AST containing an unknown block `kind` MUST refuse the message: subprocess transports respond with a JSON-RPC error (code `-32602`, "invalid params") naming the offending kind; for parse-time wire-AST construction inside the host, the host emits a document-root diagnostic and does not dispatch hooks that would receive the malformed tree. The `initialize` handshake at [#3] catches outright `wire_version` mismatches at session start; this rule covers the residual case of a peer producing a wire AST that exceeds the negotiated version. See [#6] for how new kinds become available at a bumped `wire_version`.

    2.3 Inlines

        Inline content is an array of `{ "kind": ..., ... }` objects:

        - `text` — `{ "text": string }`.
        - `bold` — `{ "children": [...inlines] }`.
        - `italic` — `{ "children": [...inlines] }`.
        - `code` — `{ "text": string }`.
        - `math` — `{ "text": string }`.
        - `reference` — `{ "ref_kind": string, "target": string, "label": optional string }`. `ref_kind` is one of `url`, `citation`, `footnote`, `session`, `file`, `placeholder`, `unsure`, `general`.

        Handlers must treat unknown `ref_kind` values as `general`.

3. Initialize

    Sent by the host on session start. Establishes `wire_version`, names the namespace's labels, declares capabilities, and lets the handler announce which methods it implements.

    Initialize request (host → handler):

        {
          "jsonrpc": "2.0",
          "id": 1,
          "method": "initialize",
          "params": {
            "wire_version": 2,
            "lex_version":  "0.12.0",
            "namespace":    "acme",
            "labels":       ["acme.task", "acme.user", "acme.commenting"],
            "capabilities": { "fs": false, "net": false },
            "workspace":    "/path/to/workspace"
          }
        }
    :: json ::

    Initialize response (handler → host):

        {
          "jsonrpc": "2.0",
          "id": 1,
          "result": {
            "wire_version": 2,
            "implements":   ["on_validate", "on_render", "on_hover"]
          }
        }
    :: json ::

    The handler's `implements` array lists the hook methods it actually responds to. The host uses this to skip events the handler does not implement, avoiding round-trips. A method present in `implements` but not actually responded to is treated as a handler-side error.

4. Hook Methods

    All hook events carry a `LabelCtx` payload describing the label invocation and its position. Method-specific fields extend `LabelCtx` as noted.

    LabelCtx shape:

        {
          "label":  string,
          "params": object,
          "body":   null | string | { "kind": "block", "children": [...node] },
          "node": {
            "kind":   string,
            "range":  { "start": [line, col], "end": [line, col] },
            "origin": string | null
          }
        }
    :: json ::

    `body` is `null` for `body.kind: none` labels, a string for `body.kind: text` labels, and a parsed wire AST subtree (`{ "kind": "block", "children": [...] }`) for `body.kind: lex` labels.

    4.1 on_label (notification)

        Method: `on_label`. Params: `LabelCtx`. No response.

        Fires informationally during the analyze phase. Used by handlers that maintain external state (caches, indices, link graphs) and need to know about every invocation without producing diagnostics or transformations.

    4.2 on_validate (request)

        Method: `on_validate`. Params: `LabelCtx`. Result: `{ "diagnostics": [Diagnostic] }`.

        Returns diagnostics for the labelled node. Fires during the analyze phase, after resolve.

        Diagnostic shape:

            {
              "severity": "error" | "warning" | "info" | "hint",
              "message":  string,
              "range":    { "start": [line, col], "end": [line, col] },
              "code":     optional string,
              "related":  optional [
                { "message": string, "range": { ... }, "uri": optional string }
              ]
            }
        :: json ::

        Handlers must treat unknown `severity` values as `info`.

    4.3 on_resolve (request)

        Method: `on_resolve`. Params: `LabelCtx`. Result: `{ "replacement": WireAst | null }`.

        Returns an AST replacement subtree, which the host splices into the parent in place of the labelled node. Fires during the resolve phase, before analysis.

        A `null` replacement leaves the original node in place (the handler chose not to splice). A non-null replacement is a single block-level wire AST node; to splice multiple siblings, return a `{ "kind": "document" }` wrapper whose children are unwrapped during the splice.

        Cycle detection: the host tracks which `(label, origin)` invocations are in flight up the resolution stack and refuses to recurse into the same invocation, where `origin` is the source position of the invocation site (file path + start line/column). Tracking the invocation site instead of `(label, params)` defeats handlers that vary parameters per call (random IDs, timestamps) and would otherwise bypass the check. The depth limit (default 32) remains as the ultimate backstop and produces `IncludeError::DepthExceeded`-style diagnostics on overflow.

    4.4 on_render (request)

        Method: `on_render`. Params: `LabelCtx & { "format": string, "format_options": object }`. Result: `{ "output": RenderOut }`.

        Returns the labelled node's representation in a target format. Fires during `lexd convert` or library-driven rendering.

        RenderOut shape:

            {
              "kind":   "string" | "wire_ast",
              "string": optional string,
              "ast":    optional WireAst
            }
        :: json ::

        For text-shaped target formats (`html`, `latex`, `markdown`), the handler returns `{ "kind": "string", "string": "..." }`. For tree-shaped target formats (namespace-defined formats, intermediate ASTs), the handler returns `{ "kind": "wire_ast", "ast": ... }`. A handler that does not understand a requested format returns a `-32601`-class error and the host falls back to default rendering of the underlying node kind.

    4.5 on_hover (request)

        Method: `on_hover`. Params: `LabelCtx`. Result: `{ "hover": Hover | null }`.

        Returns hover content for the labelled node. Fires in response to `textDocument/hover` LSP requests.

        Hover shape:

            {
              "contents": string,
              "format":   "plaintext" | "markdown",
              "range":    optional { "start": [line, col], "end": [line, col] }
            }
        :: json ::

        Hosts and handlers MUST treat unknown `format` values as `plaintext`.

    4.6 on_completion (request)

        Method: `on_completion`. Params: `LabelCtx & { "position": [line, col], "trigger": string }`. Result: `{ "items": [Completion] }`.

        Returns completion items for the position. Fires in response to `textDocument/completion` LSP requests inside a labelled node's params or body.

        Completion shape:

            {
              "label":      string,
              "detail":     optional string,
              "doc":        optional string,
              "insert":     string,
              "kind":       "value" | "param" | "namespace" | "snippet"
            }
        :: json ::

        Handlers must treat unknown `kind` values as `value`.

    4.7 on_code_action (request)

        Method: `on_code_action`. Params: `LabelCtx & { "range": { "start": [line, col], "end": [line, col] } }`. Result: `{ "actions": [CodeAction] }`.

        Returns code actions for the labelled node. Fires in response to `textDocument/codeAction` LSP requests.

        CodeAction shape:

            {
              "title":   string,
              "kind":    "quickfix" | "refactor" | "source",
              "edit":    optional { "changes": [TextEdit] },
              "command": optional {
                "title":     string,
                "command":   string,
                "arguments": [any]
              }
            }
        :: json ::

        TextEdit shape:

            {
              "range":    { "start": [line, col], "end": [line, col] },
              "new_text": string,
              "uri":      optional string
            }
        :: json ::

    4.8 on_format (request)

        Method: `on_format`. Params: `FormatCtx`. Result: `{ "annotation": LexAnnotationOut | null }`.

        Returns the Lex-source representation of a typed AST subtree the handler's namespace owns. It is the inverse of [#4.3] `on_resolve`: given a typed `WireAst` node produced earlier in the pipeline, the handler describes the label, parameters, body, and form the host emits as Lex source. Fires when the host serializes a document back to `.lex` — `lexd format`, library-driven `to_lex` calls, and the reverse direction of round-trip conversion.

        A `null` annotation lets the host fall back to its built-in formatter for the underlying node kind — there is no separate "not handled" error code.

        FormatCtx shape:

            {
              "label":          string,
              "params":         [[string, string], ...],
              "node":           WireAst,
              "format_options": optional object
            }
        :: json ::

        `label` is the fully-qualified label of the schema that owns this format pass (e.g. `"lex.tabular.table"`). `params` carries the originating `(key, value)` pairs in the order the host deserialized them; quoting and escaping are the host's responsibility on emission. `node` is the typed wire subtree to serialize back, in the same shape `on_resolve` would have produced. `format_options` is namespace-defined and omitted from the wire payload when absent.

        LexAnnotationOut shape:

            {
              "label":          string,
              "params":         optional [[string, string], ...],
              "body":           optional string,
              "verbatim_label": optional bool
            }
        :: json ::

        `label` is the canonical fully-qualified label the host emits. `params` is the `(key, value)` sequence; omitted when empty (marker-form annotations collapse to `{ "label": "..." }`). `body` is the inline or verbatim body text; omitted when empty. `verbatim_label` selects the emission form: `true` produces the verbatim closing form (subject + indented body + `:: label ::` closer); `false` (the default, omitted from the wire when not set) produces the inline annotation form (`:: label :: text` or `:: label ::` plus indented content for block-shaped bodies).

5. Errors

    A handler that hits an internal error returns a JSON-RPC error object:

    Error response:

        {
          "jsonrpc": "2.0",
          "id":      17,
          "error": {
            "code":    -32000,
            "message": "Tracker unreachable",
            "data":    { "retry_after_ms": 1000 }
          }
        }
    :: json ::

    Reserved error codes:

    - `-32700` — parse error (malformed JSON).
    - `-32600` — invalid request (missing required JSON-RPC field).
    - `-32601` — method not found (handler does not implement this hook, or — for `on_render` — does not understand the requested format).
    - `-32602` — invalid params (host sent malformed payload).
    - `-32603` — internal error.
    - `-32000` to `-32099` — handler-defined.

    A handler that consistently times out (default 2000 ms per request, configurable per-handler in the schema) or crashes is disabled for the rest of the session. The host emits a single diagnostic at the document root explaining which namespace was disabled and stops dispatching to it.

6. Versioning

    Handlers and hosts exchange `wire_version` in `initialize`. A host that receives a higher `wire_version` than it supports negotiates: it picks the highest version both sides understand. A host that receives a lower `wire_version` than its minimum supported (currently `1`) refuses the handler with a startup diagnostic.

    Non-breaking changes (no version bump):

    - New methods.
    - New optional fields on existing payloads.
    - New optional params for existing methods. Handlers must ignore unknown params.
    - New severity levels, ref kinds, completion kinds, code-action kinds, hover formats, render formats. Hosts and handlers MUST deserialise unknown wire values as the documented fallback (`info`, `general`, `value`, `refactor`, `plaintext`, and `-32601` respectively). Most of these enums are produced by handlers and consumed by the host, but the rule applies symmetrically.

    Breaking changes (version bump required):

    - Removing or renaming a method.
    - Removing a required field.
    - Changing the type of an existing field.
    - Changing the semantics of an existing method.
    - Changing the meaning of an existing severity / kind / format value.
    - *Adding a new block node kind to the wire AST.* Block kinds are structural; silently ignoring an unknown `kind` drops document content, with no safe fallback that preserves meaning. New block kinds therefore bump `wire_version`. Backwards-compatibility with handlers running an older version is the host's responsibility: hosts emit only kinds expressible in the negotiated session version, and surface a version-skew diagnostic when a document genuinely requires a kind the negotiated version cannot express. The handshake-level negotiation rule (highest common version wins; refuse only when no overlap exists) is unchanged.
    - *Adding a new inline kind* — same reasoning.

    The asymmetry between string-shaped enums (non-breaking, fall back to a documented default) and block-AST kinds (breaking, bump version) is deliberate. String values like severities are display metadata: an unknown severity surfaced as `info` is mildly imprecise but harmless. A node kind dropped silently loses content, and there is no safe fallback that preserves document meaning.

    The `lex-extension` Rust crate's major version tracks `wire_version`. A handler built against `lex-extension` 2.x speaks `wire_version: 2`. The crate's minor and patch versions reflect non-breaking additions and bug fixes.

    6.1 v1 → v2 (this revision)

        Three changes ship together at `wire_version: 2`:

        - *Breaking.* `table.align` (single string applied to every cell on the reverse codec) becomes `table.column_aligns` (array of string, one entry per column). Surfaced as a regression: a markdown pipe-table with mixed per-column alignment collapsed to its first non-`""` body alignment on round-trip through the wire.
        - *Breaking.* Three new block kinds — `image`, `video`, `audio` — join the closed set. Before v2 these were serialized as `verbatim` with the same data flattened into `params`, leaving `on_resolve` handlers for the built-in `lex.media.*` family with no typed return shape that differed from their input.
        - *Additive.* The `on_format` hook ([#4.8]) joins the method set. Pure addition under the "new methods" rule; documented here for symmetry with the breaking changes that landed in the same revision.

        Hosts negotiating with a `wire_version: 1` handler at `initialize` must continue to speak v1 over the session — emitting a `table` node with `column_aligns` or any of the three new media kinds is a version-skew error and surfaces as a document-root diagnostic per [#2.2]'s closed-set rule.

7. Examples

    7.1 Validate a task ID

        Request:

            {
              "jsonrpc": "2.0",
              "id": 17,
              "method": "on_validate",
              "params": {
                "label":  "acme.task",
                "params": { "id": "ACME-9999" },
                "body":   null,
                "node":   {
                  "kind":   "annotation",
                  "range":  { "start": [12, 4], "end": [12, 48] },
                  "origin": "chapters/02.lex"
                }
              }
            }
        :: json ::

        Response:

            {
              "jsonrpc": "2.0",
              "id": 17,
              "result": {
                "diagnostics": [
                  {
                    "severity": "error",
                    "message":  "Task ACME-9999 not found in tracker.",
                    "range":    { "start": [12, 18], "end": [12, 28] },
                    "code":     "acme.task.not-found"
                  }
                ]
              }
            }
        :: json ::

    7.2 Render a comment thread to HTML

        The annotation has a parsed Lex body (one paragraph, in this trimmed example). The handler returns the rendered HTML snippet; `lexd convert` splices it into the surrounding output.

        Request:

            {
              "jsonrpc": "2.0",
              "id": 42,
              "method": "on_render",
              "params": {
                "label":  "acme.commenting",
                "params": { "role": "editor", "resolved": false },
                "body": {
                  "kind": "block",
                  "children": [
                    {
                      "kind":  "paragraph",
                      "range": { "start": [4, 8], "end": [4, 64] },
                      "inlines": [
                        {
                          "kind": "text",
                          "text": "John, I see the relevance for this inclusion."
                        }
                      ]
                    }
                  ]
                },
                "node": {
                  "kind":   "annotation",
                  "range":  { "start": [3, 0], "end": [6, 0] },
                  "origin": "doc.lex"
                },
                "format":         "html",
                "format_options": {}
              }
            }
        :: json ::

        Response:

            {
              "jsonrpc": "2.0",
              "id": 42,
              "result": {
                "output": {
                  "kind":   "string",
                  "string": "<aside class=\"comment editor\"><p>John, I see the relevance for this inclusion.</p></aside>"
                }
              }
            }
        :: json ::

    7.3 Resolve a domain-specific include

        A namespace that splices content from an external system (a CMS, a database) implements `on_resolve` and returns a wire AST subtree. The host treats this identically to `lex.include` — cycle detection, depth limits, and origin tracking apply.

        Request:

            {
              "jsonrpc": "2.0",
              "id": 7,
              "method": "on_resolve",
              "params": {
                "label":  "acme.cms",
                "params": { "page": "intro", "version": "draft" },
                "body":   null,
                "node": {
                  "kind":   "annotation",
                  "range":  { "start": [0, 0], "end": [0, 48] },
                  "origin": "doc.lex"
                }
              }
            }
        :: json ::

        Response:

            {
              "jsonrpc": "2.0",
              "id": 7,
              "result": {
                "replacement": {
                  "kind": "document",
                  "range": { "start": [0, 0], "end": [0, 0] },
                  "origin": "cms://acme/intro@draft",
                  "children": [
                    {
                      "kind":  "paragraph",
                      "range": { "start": [0, 0], "end": [0, 0] },
                      "inlines": [
                        { "kind": "text", "text": "Introduction text from the CMS." }
                      ]
                    }
                  ]
                }
              }
            }
        :: json ::
