Inline Token Grammar for lex

	This document covers the inline tokens, which operate at the character level within text
	content. For the lower level core tokens see [./grammar-core.lex], and for line-based tokens
	see [./grammar-line.lex].

	This document defines the inline element tokens used for span-based formatting and references
	within text content. It mirrors the InlineKind enum in the token/inline.rs[1] code and the
	parser in inlines/parser.rs.

1. Scope & Characteristics

	- Inline elements are span-based, not line-based
	- They can start and end at arbitrary positions within text content
	- They can be nested (except literal types)
	- They cannot break parent element boundaries
	- No space is allowed between the start marker and content
	- Processing happens after line-based parsing is complete
	- Unclosed markers are treated as literal text (start marker + content pushed to parent)

2. Inline Token Types

	2.1. <strong>

		<strong> = '*' <inline-content>+ '*'

		Strong/bold text formatting. Can contain nested inline elements (emphasis, references, etc.).

		Example:
			*bold text*
			*bold with _emphasis_ inside*

		Properties:
		- Start token: *
		- End token: *
		- Literal: false (can contain nested inlines)
		- Validation: No space between * and content, content must not be empty

	2.2. <emphasis>

		<emphasis> = '_' <inline-content>+ '_'

		Emphasized/italic text formatting. Can contain nested inline elements.

		Example:
			_italic text_
			_italic with *bold* inside_

		Properties:
		- Start token: _
		- End token: _
		- Literal: false (can contain nested inlines)
		- Validation: No space between _ and content, content must not be empty

	2.3. <code>

		<code> = '`' <literal-text>+ '`'

		Inline code/monospace formatting. Content is treated literally (no nested inline parsing).

		Example:
			`var x = 10`
			`function *generator() {}`  (asterisks are literal)

		Properties:
		- Start token: `
		- End token: `
		- Literal: true (no nested inline parsing)
		- Content: Any characters except the closing ` are preserved as-is

	2.4. <math>

		<math> = '#' <literal-text>+ '#'

		Mathematical notation. Content is treated literally (no nested inline parsing).

		Example:
			#x + y = z#
			#f(x) = x^2#

		Properties:
		- Start token: #
		- End token: #
		- Literal: true (no nested inline parsing)
		- Content: Any characters except the closing # are preserved as-is

	2.5. <reference>

		<reference> = '[' <literal-text>+ ']'

		Reference to external resources, citations, footnotes, or annotations. Content is treated
		literally but is post-processed to determine reference type.

		Reference Types (determined by content pattern):

		URL Reference:
			[https://example.com]
			[http://site.org/path]
			[mailto:user@example.com]

		Citation Reference:
			[@doe2024]
			[@smith2023; @jones2022]
			[@doe2024, pp. 42-45]
			[@author2023; @other2024, p. 10]

		Annotation Reference:
			[^note1]
			[^important-caveat]

		Footnote Reference (Numbered):
			[42]
			[1]

		Session Reference:
			[#2.1]
			[#42]

		File Reference:
			[./path/to/file.txt]
			[/absolute/path]

		TK (To Come) Reference:
			[TK]
			[TK-feature-name]

		Not Sure Reference:
			[!!!]

		General Reference:
			[Section Title]
			[any other text]

		Properties:
		- Start token: [
		- End token: ]
		- Literal: true (no nested inline parsing)
		- Post-processing: classify_reference_node callback determines reference type

	2.5.1. Citation Grammar

		Citations are a specialized reference type that follows academic citation format:

		<citation> = '[' <citation-content> ']'
		<citation-content> = <citation-keys> (<citation-locator>)?
		<citation-keys> = <citation-key> (<citation-separator> <citation-key>)*
		<citation-key> = '@' <identifier>
		<citation-separator> = ';' | ','
		<citation-locator> = ',' <page-format> <page-specification>
		<page-format> = 'p.' | 'pp.' | 'p' | 'pp'
		<page-specification> = <page-range> (',' <page-range>)*
		<page-range> = <page-number> ('-' <page-number>)?
		<page-number> = [0-9]+

		Examples:
			[@doe2024]                           Single citation key
			[@smith2023; @jones2022]             Multiple keys with semicolon
			[@author2023, @other2024]            Multiple keys with comma
			[@doe2024, pp. 42-45]                With page range locator
			[@smith2023, p. 10]                  With single page locator
			[@author2023; @other2024, pp. 1,5-7] Multiple keys and page ranges

		Parsing Rules:
		- A single delimiter type is used per citation: if any semicolon exists, keys are split on semicolons; otherwise keys are split on commas. The two delimiters cannot be mixed within a single citation.
		- Leading @ is required for each key and is stripped during parsing
		- Locator must come after the last comma that starts a page format (p./pp.)
		- Page format can be "p." or "pp." (with or without the period, case-insensitive)
		- Multiple page ranges can be specified: "1,5-7,10" means pages 1, 5-7, and 10

	2.5.2. Reference Type Detection

		The reference classification logic (classify_reference_node) examines the content
		to determine the reference type based on these patterns:

		Detection Order:
		0. NotSure: Empty or no alphanumeric characters (e.g., "!!!") — checked first as early return
		1. TK Reference: "TK" or "TK-identifier" (case insensitive for prefix; identifier must be lowercase ASCII + digits, max 20 characters)
		2. Citation: Starts with "@" followed by citation parsing
		3. Annotation Reference: Starts with "^" followed by non-empty label
		4. Session: Starts with "#" followed by digits, dots, or dashes only
		5. URL: Starts with "http://", "https://", or "mailto:"
		6. File: Starts with "." or "/"
		7. Footnote (Numbered): Content is purely numeric (all ASCII digits)
		8. General: Any other content (fallback)

3. Inline Content Grammar

	<inline-content> = <plain-text> | <strong> | <emphasis> | <code> | <math> | <reference>
	<literal-text> = <any-character-except-end-token>+
	<plain-text> = <any-text-without-inline-markers>

	Nesting Rules:
	- Strong can contain: emphasis, code, math, reference, plain text
	- Emphasis can contain: strong, code, math, reference, plain text
	- Code cannot contain nested inlines (literal)
	- Math cannot contain nested inlines (literal)
	- Reference cannot contain nested inlines (literal)
	- Same-type nesting is blocked via a counter mechanism: when a start marker for a type already on the stack is found, a blocked counter is incremented; the corresponding end marker is consumed by the counter instead of closing the frame. For example, *outer *inner* text* produces Strong("outer *inner* text") — the inner * pair becomes literal text.

4. Validation Rules

	4.1. Start Validation

		A start marker is valid when:
		- Previous character is not alphanumeric (or is at start of text)
		- For non-literal types (strong, emphasis): next character must be alphanumeric
		- For literal types (code, math, reference): next character must be non-whitespace

		Invalid starts:
			word*text*      (previous char is alphanumeric)
			7 * 8           (next char is space, not alphanumeric)

	4.2. End Validation

		An end marker is valid when:
		- For literal types: previous character exists (content not empty)
		- For non-literal types: previous character is not whitespace
		- Next character is not alphanumeric (or is at end of text)

		Invalid ends:
			*text *         (previous char is whitespace)
			*text*word      (next char is alphanumeric)

	4.3. Empty Content

		Empty inline elements are not valid:
			**              Renders as: **
			__              Renders as: __
			``              Renders as: ``

		The parser preserves empty markers as literal text.

	4.4. Unclosed Markers

		When a start marker has no matching end marker, the opening delimiter and any content
		accumulated inside the frame are unwound as literal text into the parent context:
			*unclosed text      Renders as: *unclosed text
			[no closing bracket Renders as: [no closing bracket

		This ensures all input is preserved and no content is lost.

5. Escape Sequences

	See also [./elements/escaping.lex] for the full escaping specification.

	5.1. Escaping Inline Markers

		Use backslash (\) to escape inline markers:

		Example:
			\*literal asterisk\*   → *literal asterisk*
			\[not a link\]         → [not a link]

	5.2. Backslash Behavior

		- Before non-alphanumeric: escapes the character (backslash is removed). This includes non-ASCII non-alphanumeric characters.
		- Before alphanumeric (ASCII or Unicode): backslash is preserved (for paths like C:\Users)
		- Double backslash (\\): produces single backslash (since \ is non-alphanumeric)
		- Trailing backslash at end of input: preserved as literal text

		Escapable special characters: \ * _ ` # [ ]

		Examples:
			\*text\*               → *text*
			C:\Users\name          → C:\Users\name (backslashes preserved)
			C:\\Users\\name        → C:\Users\name (double backslash = single)

	5.3. Literal Context Exemption

		Inside literal inline elements (code, math, reference), escape processing
		does NOT apply. Backslashes are preserved verbatim:

		Examples:
			`\*text\*`             → Code("\*text\*")
			#\alpha + \beta#       → Math("\alpha + \beta")

		This ensures code spans and math notation work naturally without
		requiring double-escaping of backslashes.

6. Implementation Notes

	6.1. Processing Order

		Inline parsing happens after the main parser completes:
		1. Line-based parsing creates the AST structure
		2. Text content nodes are identified
		3. Inline parser processes each text content node independently
		4. Results replace the plain text nodes with inline trees

	6.2. Parallelization

		Because inline parsing does not depend on document-level context:
		- Each text content node can be parsed independently
		- No coordination required between different text containers
		- Enables parallel processing for performance

	6.3. Post-Processing Callbacks

		Some inline types need additional logic after parsing:
		- Reference nodes use classify_reference_node to determine type
		- Other types may have custom transformations
		- Callbacks receive the parsed node and return a transformed node

Notes:

1. crates/lex-core/src/lex/token/inline.rs
