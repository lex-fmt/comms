Font ligatures and Unicode symbols

1. Why this matters

    Lex documents lean heavily on arrows and logical symbols. `->`, `<-`, `=>`, `!=`, `<=>`, `...` appear constantly — not just in technical specs but in everyday prose: cause and effect, logical implication, ranges, approximate values, ellipses.

    Authors writing Lex in a ligature-aware monospace font (Geist Mono, Fira Code, JetBrains Mono) see these ASCII sequences rendered as proper typographic symbols. The source stays ASCII on disk, but the screen shows → ⇒ ≠ ⇔ …

    The problem is that rendering is purely local to the author's editor. When the document ships — to a coworker opening the HTML in Chrome, a student viewing the PDF, a reviewer on a different OS — the ligatures vanish. `->` becomes a dash followed by a greater-than sign. The visual clarity the author relied on is gone.

    Lex is meant to reach beyond technical authoring environments. The reader viewing a Lex-generated HTML file should see the same typographic symbols the author saw, regardless of whether they have a programmer's font installed. This document surveys which ASCII-to-symbol mappings can be done at the _text layer_ (via Unicode substitution) versus which require a controlled _font layer_ (via embedded webfonts with OpenType ligature features).

2. The tiers

    Symbols split into three tiers based on how reliably they render across fonts. Tier 2 splits further by Unicode block, because the practical coverage story is different for each half.

    2.1. Tier 1 — universal

        Codepoints in the oldest BMP blocks: Arrows (U+2190–U+21FF core range), basic Mathematical Operators (U+2200–U+22FF), General Punctuation (U+2000–U+206F). Present in every mainstream font — OS defaults, Google Fonts text families, bare system fallbacks like DejaVu and Liberation. Safe to substitute unconditionally in prose.

    2.2. Tier 2a — widespread

        Codepoints in the upper Arrows block (U+219C–U+21DD) and extended Mathematical Operators (U+2254, U+2262), plus the interrobang (U+203D). Added in early Unicode versions and carried by all text-optimized fonts: Arial, Helvetica, Roboto, Inter, Open Sans, Lato, Source Sans, Noto Sans. Safe to substitute when targeting mainstream fonts; occasional fallback in older or display-focused typefaces.

    2.3. Tier 2b — spotty

        Codepoints in Supplemental Arrows-A (U+27F5–U+27FA) — the long-form arrows. Coverage is inconsistent. Arial and Helvetica historically do not cover these; the browser falls back to a math-capable font (STIX, Cambria Math), rendering the glyph at a mismatched weight and baseline. Inter, Noto Sans, SF Pro, and Segoe UI cover them cleanly. Substitute only when the font is controlled via `@font-face`.

    2.4. Tier 3 — font-only

        No reliable Unicode equivalent. These ligatures exist only as font-level OpenType substitutions (`calt` / `liga` features). The ASCII sequence must stay as-is in the source; visual rendering is entirely the font's responsibility.

3. Tier 1 substitutions

    Safe for every output, every font, every reader:
        | ASCII   | Symbol | Codepoint | Name                      |
        | `->`    | →      | U+2192    | Rightwards arrow          |
        | `<-`    | ←      | U+2190    | Leftwards arrow           |
        | `<->`   | ↔      | U+2194    | Left right arrow          |
        | `=>`    | ⇒      | U+21D2    | Rightwards double arrow   |
        | `<=>`   | ⇔      | U+21D4    | Left right double arrow   |
        | `<=`    | ≤      | U+2264    | Less than or equal        |
        | `>=`    | ≥      | U+2265    | Greater than or equal     |
        | `!=`    | ≠      | U+2260    | Not equal                 |
        | `/=`    | ≠      | U+2260    | Not equal                 |
        | `=/=`   | ≠      | U+2260    | Not equal                 |
        | `===`   | ≡      | U+2261    | Identical to              |
        | `~~`    | ≈      | U+2248    | Almost equal to           |
        | `~=`    | ≃      | U+2243    | Asymptotically equal      |
        | `...`   | …      | U+2026    | Horizontal ellipsis       |
        | `--`    | –      | U+2013    | En dash                   |
        | `---`   | —      | U+2014    | Em dash                   |
    :: table align=llll ::

4. Tier 2a substitutions

    Safe in any text-optimized font (Arial, Helvetica, Roboto, Inter, Open Sans, Lato, Source Sans, Noto Sans):
        | ASCII   | Symbol | Codepoint | Name                       |
        | `:=`    | ≔      | U+2254    | Colon equals               |
        | `!==`   | ≢      | U+2262    | Not identical to           |
        | `!?`    | ‽      | U+203D    | Interrobang                |
        | `->>`   | ↠      | U+21A0    | Two-headed rightwards      |
        | `>->`   | ↣      | U+21A3    | Rightwards arrow with tail |
        | `~>`    | ⇝      | U+21DD    | Rightwards squiggle arrow  |
        | `<~`    | ↜      | U+219C    | Leftwards wave arrow       |
        | `<~>`   | ↭      | U+21AD    | Left right wave arrow      |
        | `<<-`   | ↞      | U+219E    | Two-headed leftwards       |
    :: table align=llll ::

    One additional Tier 2a mapping is worth noting but sits outside the table because `|` is the Lex cell delimiter: the bar-hyphen-greater sequence (written in ASCII as pipe followed by `->`) maps to ↦ (U+21A6, Maps to) — the functional "mapsto" arrow common in type signatures and mathematical writing.

5. Tier 2b substitutions

    Use only when an embedded webfont with Supplemental Arrows-A coverage is guaranteed. Without that guarantee, these render in a fallback font and look visually worse than plain ASCII:
        | ASCII    | Symbol | Codepoint | Name                            |
        | `-->`    | ⟶      | U+27F6    | Long rightwards arrow           |
        | `<--`    | ⟵      | U+27F5    | Long leftwards arrow            |
        | `==>`    | ⟹      | U+27F9    | Long rightwards double arrow    |
        | `<==`    | ⟸      | U+27F8    | Long leftwards double arrow     |
        | `<==>`   | ⟺      | U+27FA    | Long left right double arrow    |
    :: table align=llll ::

6. Tier 3 — font-only

    No reliable Unicode equivalent. Leave as ASCII and rely on an embedded ligature font (or on the reader having one installed) if you want the glyph rendering.

    Representative examples:
        - `==`, `=>>`, `=<<`
        - `>=>`, `>>=`, `>>-`, `>-`
        - `-<`, `-<<`, `<=<`, `<<=`, `<-<`
        - `<|`, `<||`, `<|||`, `<|>`, `|||>`, `||=`, `||>`, `|>`, `|=`
        - `|}`, `{|`, `</>`, `<!--`, `<>`
        - `~@`, `~-`, `-~`, `~~>`, `<~~`
        - `###`, `%%`, `.=`, `..=`, `??`, `???`

7. Font coverage comparison

    Coverage of each tier across common font families. `✓` = reliable coverage, `~` = partial (browser fallback likely for some codepoints), `✗` = no coverage, `liga` = rendered via OpenType `liga` / `calt` rather than via dedicated Unicode codepoints:
        | Font family                      | Tier 1 | Tier 2a | Tier 2b | Tier 3 |
        | Arial                            | ✓      | ✓       | ✗       | ✗      |
        | Helvetica / Helvetica Neue       | ✓      | ✓       | ✗       | ✗      |
        | Times New Roman                  | ✓      | ✓       | ✗       | ✗      |
        | Courier New                      | ✓      | ~       | ✗       | ✗      |
        | SF Pro (macOS system)            | ✓      | ✓       | ✓       | ✗      |
        | Segoe UI (Windows system)        | ✓      | ✓       | ✓       | ✗      |
        | Roboto                           | ✓      | ✓       | ~       | ✗      |
        | Inter                            | ✓      | ✓       | ✓       | ✗      |
        | Open Sans                        | ✓      | ✓       | ~       | ✗      |
        | Lato                             | ✓      | ✓       | ~       | ✗      |
        | Source Sans 3                    | ✓      | ✓       | ~       | ✗      |
        | Noto Sans                        | ✓      | ✓       | ✓       | ✗      |
        | Merriweather / Playfair (serif display) | ✓ | ~    | ✗       | ✗      |
        | Fira Code                        | ✓      | ✓       | ✓       | liga   |
        | JetBrains Mono                   | ✓      | ✓       | ✓       | liga   |
        | Geist Mono                       | ✓      | ✓       | ✓       | liga   |
        | Cascadia Code                    | ✓      | ✓       | ✓       | liga   |
    :: table align=lcccc ::

    A few notes on reading the table:
        - The `~` cells are the trap. The glyph _renders_, but not in the requested font — the browser silently swaps to a math fallback with a different weight and baseline. Visually it's worse than leaving the ASCII alone.
        - The display serifs row illustrates why typeface choice matters beyond aesthetics: a heading font that looks beautiful for titles may fail on body text that contains Tier 2 symbols.
        - Monospace ligature fonts are the only place Tier 3 sequences render as symbols, and they do it via OpenType features, not Unicode substitution.

8. Recommendation

    Two layers, applied together:

    Text layer (Unicode substitution pass in the HTML/PDF formatter, applied to prose only — never inside verbatim blocks or inline `code`):
        - Always apply Tier 1.
        - Apply Tier 2a when the document's font stack leads with a widespread text font or embedded webfont.
        - Apply Tier 2b only when an embedded webfont with Supplemental Arrows-A coverage is guaranteed via `@font-face`.
        - Never substitute Tier 3. Leave ASCII; let the font do the work or let it stay literal.

    Font layer (for readers who want full ligature fidelity regardless of their system):
        - Embed a ligature-capable font via `@font-face` in HTML output. Geist Mono and JetBrains Mono are both OFL-licensed and cover Tier 3 cleanly.
        - Enable `font-feature-settings: "liga", "calt";` on code and verbatim blocks.
        - This closes the Tier 3 gap and covers any Tier 2 misses without source transformation.

    Config surface proposal:
        - `unicode_substitutions = "basic" | "extended" | "full" | "off"`
        - `basic` applies Tier 1 only (default).
        - `extended` adds Tier 2a.
        - `full` adds Tier 2b (requires embedded font guarantee).
        - `off` disables substitution entirely; ASCII ships as written.

    The guiding principle: substitution should never produce a worse rendering than the ASCII it replaces. Tier 1 never does. Tier 2a rarely does. Tier 2b will, unless the font is pinned. Tier 3 always does.
