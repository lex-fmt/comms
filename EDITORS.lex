Lex Editor Feature Parity

    Status of Lex-handling features across the three editor integrations — *vscode*, *nvim*, and *lexed* — plus a secondary view of the editor-infrastructure features that lexed has to provide on its own.

1. Scope

    The main table in section 2 covers *Lex-handling features*: functionality tied to the Lex language itself (parser, LSP, tree-sitter grammar) that every editor integration should expose to the user. vscode is the reference implementation; nvim and lexed are measured against it.

    *Editor-infrastructure features* — spellcheck engines, settings panels, file trees, theme pickers, preview panes, command palettes, and similar — are not Lex-scope. In vscode and nvim they come from the host editor; in lexed they have to be built from scratch because the app owns its own editor surface. Section 4 lists them for reference but they are not part of the parity picture.

    Legend:
    - *Ok* — fully implemented with reasonable test coverage (unit, integration, or e2e as appropriate for the surface).
    - *Partial* — implemented but with a known gap. A footnote describes what.
    - *Missing* — not implemented in this editor.

    Differences driven by the host runtime are not flagged. For example, nvim is a terminal editor, so it has no live HTML preview; that is a property of the environment, not a parity gap worth footnoting.

2. Lex-handling features

    Implementation status:

        | Feature                                     | vscode  | nvim    | lexed        |
        | *Highlighting*                              |         |         |              |
        | Semantic highlighting (LSP)                 | Ok      | Ok      | Ok           |
        | Tree-sitter injection highlighting [1]      | Ok      | Ok      | Missing      |
        | *Diagnostics*                               |         |         |              |
        | Parser / footnote / table diagnostics [2]   | Ok      | Ok      | Ok           |
        | *Navigation*                                |         |         |              |
        | Document outline (symbols)                  | Ok      | Ok      | Ok           |
        | Hover                                       | Ok      | Ok      | Ok           |
        | Go to definition                            | Ok      | Ok      | Ok           |
        | Find references                             | Ok      | Ok      | Ok           |
        | Document links                              | Ok      | Ok      | Ok           |
        | Folding                                     | Ok      | Ok      | Ok           |
        | *Formatting*                                |         |         |              |
        | Document formatting                         | Ok      | Ok      | Ok           |
        | Range formatting                            | Ok      | Ok      | Ok           |
        | Format on save                              | Ok      | Ok      | Ok           |
        | *Completion*                                |         |         |              |
        | Snippet completion (`@note`, `@image`, …)   | Ok      | Ok      | Ok           |
        | Path completion (`@`-triggered)             | Ok      | Ok      | Ok           |
        | Reference label completion [3]              | Ok      | Ok      | Ok           |
        | *Commands — annotations*                    |         |         |              |
        | Next / previous annotation                  | Ok      | Ok      | Ok           |
        | Resolve annotation                          | Ok      | Ok      | Ok           |
        | Toggle annotation resolution                | Ok      | Ok      | Ok           |
        | *Commands — insertion*                      |         |         |              |
        | Insert asset reference (file picker)        | Ok      | Ok      | Ok           |
        | Insert verbatim block from file             | Ok      | Ok      | Ok           |
        | *Commands — tables*                         |         |         |              |
        | Format table at cursor                      | Ok      | Ok      | Ok           |
        | Table cell navigation (Tab / Shift+Tab)     | Ok      | Ok      | Ok           |
        | *Commands — footnotes*                      |         |         |              |
        | Reorder footnotes                           | Ok      | Ok      | Ok           |
        | Add missing footnote definition [4]         | Missing | Missing | Missing      |
        | *Commands — conversion*                     |         |         |              |
        | Export to Markdown                          | Ok      | Ok      | Ok           |
        | Export to HTML                              | Ok      | Ok      | Ok           |
        | Export to PDF                               | Ok      | Ok      | Ok           |
        | Import Markdown → Lex                       | Ok      | Ok      | Ok           |
        | *Commands — preview*                        |         |         |              |
        | Live HTML preview                           | Ok      | n/a     | Ok           |
        | *File association*                          |         |         |              |
        | `.lex` filetype association                 | Ok      | Ok      | Ok           |
        | `.lex` file icon                            | Ok      | Ok      | Ok           |
    :: table align=lccc ::

3. Footnotes

    :: notes ::
    1. Syntax highlighting of embedded code inside verbatim blocks (e.g. Python inside a `:: python ::`-closed block). vscode and nvim use the `tree-sitter-lex` grammar with language injections. lexed relies solely on LSP semantic tokens, which do not cross the verbatim boundary. Tracked as a follow-up alongside §5.2: extract the injection highlighter from `vscode/src/injections.ts` into `@lex/shared/injections` so lexed can consume it.
    2. Parser errors, missing/unused footnote definitions, and inconsistent table columns are all emitted by `lex-lsp` through standard `publishDiagnostics`. Each client displays them via its default diagnostic handler.
    3. Completion of footnote labels, citation keys, and session references provided by the LSP. Delivered through standard completion; no editor-side logic required.
    4. The "Add missing footnote definition" quickfix is drafted in `lex-lsp` (`features/available_actions.rs`) but commented out at the server, so no editor surfaces it today. Listed to make the gap visible.
    :: notes ::

4. Editor-infrastructure features — lexed

    lexed is a standalone Electron application built around Monaco. The features below are not Lex-scope: they exist because lexed has to supply, from scratch, the editor affordances that vscode and nvim inherit from their host. They are tracked here so the parity table above stays focused on Lex surfaces, not on what the app-shell provides.

    Status:

        | Feature                                          | Status       |
        | Multi-pane workspace (splits, focus shortcuts)   | Ok           |
        | File tree with context menu                      | Ok           |
        | Settings UI (formatter, spellcheck, appearance)  | Ok           |
        | Keybinding customization                         | Ok           |
        | Command palette                                  | Ok           |
        | Client-side spellcheck engine [a]                | Ok           |
        | Theme engine (monochrome light / dark)           | Ok           |
        | Status bar widgets                               | Ok           |
        | Application menu + IPC bridge                    | Ok           |
        | Welcome screen                                   | Ok           |
        | Settings persistence                             | Ok           |
        | Vim mode (via `monaco-vim`)                      | Partial [b]  |
        | QuickLook extension (macOS)                      | Partial [c]  |
        | Multi-format open (`.lex`, `.md`, `.lexx`)       | Partial [d]  |
    :: table align=lc ::

    :: notes ::
    a. Spellcheck runs entirely in the renderer using Hunspell dictionaries bundled as app resources, with custom words persisted locally. `lex-lsp` has no spellcheck feature, so vscode and nvim rely on host-editor extensions and are intentionally not compared here.
    b. Vim mode is a toggle backed by `monaco-vim` and integrates with the status bar; no e2e test covers modal behaviour end to end.
    c. The macOS QuickLook plug-in is bundled with the app but is packaged separately from the main renderer pipeline and not covered by the renderer e2e suite.
    d. Opening `.md` invokes the Markdown → Lex importer on demand. Round-tripping through `.lexx` is not tested end to end.
    :: notes ::

5. Deduplication candidates

    Implementations that live in more than one client today and would be better off in a central location. Moving them reduces the per-editor surface area, ensures the three clients behave identically, and shrinks the set of places a bug can hide.

    5.1. Move to `lex-lsp` — *Adopted in lex-lsp v0.8.3 / editor releases vscode v0.6.5, nvim v0.7.6, lexed #17.*

        All three candidates are in the server and consumed by the three editors:

        Table cell navigation:
            Promoted to `lex.table.next_cell` / `lex.table.previous_cell`, sitting next to `lex.table.format`. vscode, nvim, and lexed now forward Tab / Shift+Tab to these commands; the pipe-counting heuristic no longer lives in any client.

        Verbatim language inference:
            `lex.insert_verbatim` owns the extension → language identifier table server-side (`lex-babel/templates/verbatim.rs::language_from_token`). vscode's `insertVerbatimBlock` and lexed's equivalent now pass only the file path; the client-side `py → python` map is gone.

        File-extension → convert format mapping:
            `lex.formats.list` enumerates the format registry. Clients derive their convertible-formats menu from it instead of a hard-coded table, so adding a new source format is a server-only change.

    5.2. Move to `@lex/shared` — *Outstanding.*

        Editor-agnostic TypeScript that two of the three clients could consume. vscode extensions do not expose Monaco APIs to extensions, but both vscode and lexed are TypeScript + Node and already share the `@lex/shared` workspace package (currently holding only `InsertAssetCommand` and `InsertVerbatimCommand`).

        Tree-sitter injection highlighter:
            vscode implements embedded-code highlighting in `src/injections.ts` using `web-tree-sitter` and a set of decoration categories; lexed does not have it at all (see row *Tree-sitter injection highlighting* in section 2 and footnote [1]). The module is pure tree-sitter + decoration logic and does not touch any vscode-specific API. Extract to `@lex/shared/injections` with a small host-adapter interface, and lexed can adopt it in an afternoon.

        Annotation / asset / verbatim insertion glue:
            Already partially shared via `@lex/shared/commands`. After 5.1 landed, the remaining client-side glue is thin, but moving path relativisation and asset-reference formatting into the same package would keep the vscode and lexed `commands.ts` files as pure host adapters.

    5.3. Not a dedup target

        LSP *client wiring* (semantic tokens, diagnostics, hover, completion, etc.) looks duplicated but isn't: vscode uses `vscode-languageclient`, lexed uses `monaco-languageclient`, nvim uses the built-in LSP client. Each client is the minimum amount of host-specific code required to bridge the protocol. Leave alone.
