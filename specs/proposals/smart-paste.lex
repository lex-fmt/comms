Proposal: Smart Paste

    Lex encodes document structure as indentation, four spaces per level. This makes copy-and-paste between Lex documents — and from the outside world into a Lex document — quietly hostile. Clipboard text carries the *absolute* indentation of wherever it was copied: a paragraph lifted from the top of one document arrives at column zero, a block copied from deep inside a session arrives carrying three levels of leading whitespace. Dropped at the caret unchanged, the first becomes a stray top-level session and the second a malformed over-indented block. The author's intent is almost always the opposite: "put this *here*, at the structural level I'm standing in." Today every author re-indents by hand after every paste.

    Smart paste re-anchors pasted text to the caret's structural context at paste time. It is a single behaviour that should feel identical in every Lex editor, which means the logic belongs in lex-lsp and the editors contribute only a thin capture-and-apply shim. This proposal specifies the layering, the custom LSP request that carries it, the paste-mode classification that decides *whether* to transform, and the re-anchoring transform that decides *how*.

1. Layering

    The transform logic lives in lex-lsp; the editors own only the paste interception. This split is forced by two facts that pull in opposite directions.

    The clipboard is the editor's:
        Standard LSP has no paste notification and no clipboard access. The server cannot observe a paste, cannot read the clipboard, and cannot initiate the operation. Only the editor can.

    The structure is the server's:
        Whether the caret sits inside a verbatim block, a table cell, a list item's hanging indent, or an ordinary session body — and what the correct anchor indentation is for that context — is knowable only from a parse of the document. The editor does not have it; the server does.

    The resolution is a custom request. The editor captures the paste, reads the clipboard, and asks the server what text to insert; the server parses, classifies, transforms, and returns an edit; the editor applies it. The editor stays a UI shell, consistent with the standing rule that validation and business logic live in the LSP and never fork across the four editor front-ends ([./extending-lex.lex] establishes the same boundary for extensions). One implementation, tested once, serves vscode, nvim, lexed, and any future Zed-class client.

    A server that does not implement the request, or an editor with the feature disabled, falls back to the editor's native paste. Smart paste is an enhancement over correct default behaviour, never a precondition for pasting at all.

2. The `lex/preparePaste` Request

    A custom request, not a standard LSP method. The editor sends the document identity, the target range the paste will replace, and the raw clipboard text. The server returns the text to insert in that range.

    Request params:

        textDocument:
            The document identifier. The server resolves it to its current parsed state.

        range:
            The range the paste replaces. For a collapsed caret this is an empty range at the caret; for a paste over a selection it is the selection. The range *start* is the structural anchor (§4.1); the range itself is what the returned edit overwrites.

        pastedText:
            The raw clipboard text, exactly as the editor holds it, including its original indentation and any trailing newline.

    Response:

        text:
            The transformed text to insert across `range`. The editor applies it as an ordinary single-edit replacement — it does not need to understand the transform, only to splice the returned string in.

        mode:
            The classification the server applied (§3), as a string. Advisory: editors may surface it ("pasted as verbatim — not re-indented") but are not required to act on it. Including it keeps the transform debuggable from the editor side without a server round-trip.

    The request is synchronous from the author's perspective — the paste does not visibly complete until the edit lands — so the server's handler must be cheap. It reuses the already-parsed document state the server holds for the open buffer; it does not re-parse from scratch. The handler is pure with respect to document state: it reads the parse, computes a string, and mutates nothing.

3. Paste Modes

    Before transforming anything, the server classifies the paste by the caret's structural context. The mode decides *whether* re-anchoring happens at all; §4 covers the transform that runs only in re-anchor mode.

    passthrough — verbatim:
        The caret is inside a verbatim block. Indentation there is literal content; re-indenting it would corrupt the very thing verbatim blocks exist to preserve. The clipboard text is inserted unchanged. This case alone justifies routing paste through the parser — a whitespace-counting editor heuristic cannot know it is inside a verbatim block.

    passthrough — table:
        The caret is inside a table's pipe rows. Cell structure is delimiter-driven, not indentation-driven; the re-anchor transform does not apply. Inserted unchanged. (A richer table-aware paste — splitting tab- or comma-separated clipboard text into cells — is a separate future mode, noted in §8.)

    passthrough — single line:
        The clipboard holds a single line with no newline. There is no inter-line structure to re-anchor and, mid-text, nothing to indent. Inserted unchanged. This is the case the naive "do nothing when mid-sentence" rule gets right; §4 covers why it is the *only* case that rule gets right.

    re-anchor:
        Everything else — caret in a session body, list item, or definition body, with multi-line clipboard text. The transform in §4 runs.

    Modes are resolved innermost-first: a single-line paste inside a verbatim block is `passthrough — verbatim`, not `passthrough — single line`. The distinction is moot for the inserted text (both pass through unchanged) but the reported `mode` should name the structural reason, not the incidental one.

4. The Re-anchor Transform

    In `reanchor` mode the server rewrites the clipboard's per-line indentation so the block lands at the caret's structural level while preserving its own internal shape. Three steps: find the anchor, find the clipboard's baseline, apply the difference.

    4.1 The Anchor

        The anchor is the *content indentation of the structural container enclosing the range start* — not the whitespace physically present on the caret's line, and not the caret's column.

        This is the central correction over a naive editor heuristic. "Prepend the spaces already on the current line" works only when the editor has auto-indented the fresh line to exactly the right level, and silently misbehaves when it has not: on a blank line left at column zero inside a deep session, in a list item whose continuation indent sits past the marker rather than at the marker, or anywhere the author's whitespace and the document's structure disagree. Because the server has parsed the document, it computes the anchor from the enclosing container — the body indentation a new child of that container should carry — and is correct regardless of what whitespace the caret's line happens to hold.

    4.2 The Clipboard Baseline

        The clipboard's own indentation is normalised before re-anchoring. Compute the baseline as the minimum leading-whitespace width across all *non-blank* lines of the clipboard text. This is the common indentation the whole block shares — zero for text copied from a document head, non-zero for a block lifted out of an existing nesting.

        Stripping the baseline and re-applying the anchor as a single constant offset is what preserves the clipboard's internal structure. A parent line and its indented child both shift by the same amount, so their *relative* relationship survives; only the block as a whole moves. Assuming the baseline is always zero — the naive model — corrupts any block that was copied from a position that was itself indented.

    4.3 Applying the Offset

        Let `delta = anchor - baseline`. For each line of the clipboard:

        - Blank lines (empty or whitespace-only) are emitted empty. Never pad a blank line; trailing whitespace is noise and Lex treats blank lines as block separators regardless of their width.
        - Non-blank lines are emitted with `max(0, original_indent + delta)` spaces of leading indentation followed by their stripped content. The clamp at zero prevents a negative indent when a block is pasted shallower than it was copied.

        The result re-anchors the block at the caret's level with its internal nesting intact, whether `delta` is positive (pasting deeper), negative (pasting shallower), or zero.

    4.4 The First Line

        The first pasted line is special whenever the range start is not at the beginning of a fresh, empty line — that is, whenever pasted content will sit on the same line as text that is already there.

        Fresh-line case:
            The range start is on a blank or whitespace-only line (or at the auto-indented head of a new line). The whole paste is a new block. Every line, including the first, takes the §4.3 treatment; the line's pre-existing whitespace is part of the replaced range and is overwritten by the anchor.

        Merge case:
            The range start follows existing content on its line. The first pasted line continues that content, so it is emitted with its leading whitespace stripped entirely and *no* anchor applied — it joins the text already on the line. Lines two onward take the full §4.3 treatment, because they are genuinely new lines that must sit at the document's structural level. Any document text that followed the caret moves below the last pasted line, as in an ordinary paste.

        This is the second correction over the naive rule. "Mid-sentence, do nothing" is right for the *first* line of a merge paste, but wrong for the rest: leaving lines two onward at their clipboard indentation drops them to column zero (or wherever the clipboard left them), breaking the session they were meant to join. The first line merges; the remainder re-anchors. The two are not in tension once the line is treated positionally rather than the paste treated wholesale.

5. Editor Integration

    Each editor contributes the same two moves — capture the paste, apply the returned edit — through whatever native hook it offers. No transform logic lives editor-side.

    vscode:
        A `DocumentPasteEditProvider` (stable since 1.87) is the native primitive: it hands the extension the pasted text and the target range and accepts a `DocumentPasteEdit` in return. The provider forwards to `lex/preparePaste` and wraps the response in the edit.

    nvim:
        A `vim.paste` override (or a buffer-local paste mapping) for Lex buffers calls the request through the LSP client and inserts the returned text.

    lexed:
        The editor surface intercepts paste at the same layer it already handles other Lex-aware commands and routes through the shared LSP client.

    All three guard on server capability and fall back to native paste when the request is unavailable (§1). The capability is advertised in the server's initialize response so editors enable the interception only against a server that implements it.

6. Edge Cases

    The transform and classification are specified above; these are the boundary inputs a correct implementation and its tests must pin down.

    - Empty clipboard: no edit; native paste (a no-op) proceeds.
    - Selection-replace paste: the anchor derives from the selection *start* (§4.1); the whole selection is the replaced range.
    - Trailing newline in the clipboard: preserved. Whether it opens a following block is the document's business once inserted, not the transform's.
    - Mixed tabs and spaces in the clipboard: leading whitespace is measured in display columns with the Lex tab width (four), so baseline and per-line widths are comparable; emitted indentation is spaces, consistent with Lex's canonical four-space levels.
    - Clipboard whose content is itself a verbatim block (subject line plus indented body plus `:: label ::`): treated as ordinary multi-line text by the re-anchor transform — the constant offset preserves the body's indentation relative to its subject, so the block stays well-formed. The transform does not parse the clipboard (§7).
    - Paste at document start (column zero, no enclosing container): the anchor is zero; the transform is an identity for zero-baseline clipboards and a dedent for indented ones.
    - Inconsistent clipboard indentation (a line shallower than the computed baseline cannot occur — baseline is the minimum — but a line may be only partially indented): partial indentation is carried through the offset unchanged, matching Lex's tolerance for partial indentation in authored documents.

7. Whitespace Re-indent, Not Structural Re-parse

    The transform is pure whitespace arithmetic over lines. It deliberately does *not* parse the clipboard as a Lex fragment, splice it into the AST at the caret, and re-emit through the formatter.

    The structural alternative is more powerful — it would normalise the pasted fragment, not merely re-anchor it — but it is the wrong default. Clipboard content is frequently not valid Lex: a half-copied block, prose from a browser, a snippet mid-edit. A structural paste either rejects such input or guesses at its structure, and when it succeeds it surprises the author by reformatting text they only meant to move. The whitespace transform is predictable, indifferent to whether the clipboard parses, and never reformats. It is the right behaviour for the overwhelming common case.

    A structural paste mode may be worth offering later as an explicit, opt-in command for the case where the author *wants* normalisation — distinct from the default paste, never silently substituted for it.

8. Out of Scope

    This proposal does not cover:

    - Table-aware paste: splitting tab- or comma-separated clipboard text into table cells when pasting inside a table. A distinct mode layered on the §3 table classification; its own design.
    - Structural / re-parse paste: the opt-in normalising mode noted in §7.
    - Copy-side transformation: rewriting indentation at *copy* time (for example, normalising a copied block to baseline zero on the clipboard). Smart paste operates purely on paste; copy stays native.
    - Cross-format paste: detecting Markdown or HTML on the clipboard and converting it to Lex on paste. A conversion feature in babel's domain, not a re-indentation one.
    - Undo granularity: the returned edit is a single replacement and undoes as one step; finer-grained undo is the editor's native concern.
