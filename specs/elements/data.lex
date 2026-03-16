Data Markers

Introduction

	Data markers are the only explicit syntactic markers in Lex. They denote metadata
	rather than content: structured information (labels, parameters) that tooling can
	act on. A data marker is the reusable building block shared by annotations and
	verbatim closing lines.

	Data markers are not standalone elements. They are embedded by other elements
	that need a label + optional parameter payload.

Syntax

	A data marker line has two possible forms depending on context:

	Open form (no trailing :: marker):
		<data> = <lex-marker> <whitespace> <label> (<whitespace> <parameters>)?

	Closed form (with trailing :: marker):
		<data-marker-line> = <lex-marker> <whitespace> <label> (<whitespace> <parameters>)? <whitespace>? <lex-marker>

	The open form produces a <data-line> token in the lexer; the closed form produces
	a <data-marker-line> token. Both carry the same payload: a label and optional
	parameters.

	Examples:
		:: note severity=high
		:: javascript caption="Hello World" ::
		:: warning ::

Components

	Label (mandatory):
		The label identifies the data marker. Labels follow the syntax defined in
		specs/v1/elements/label.lex: a letter followed by letters, digits, underscores,
		dashes, or periods (for namespacing).

		Examples: note, warning, javascript, lex.internal, plugin.myapp.custom

	Parameters (optional):
		Key-value pairs that provide structured metadata. Parameters follow the syntax
		defined in specs/v1/elements/parameter.lex: comma-separated key=value pairs
		where values can be unquoted (restricted charset) or quoted (any text, with
		\" and \\ as the only escape sequences).

		Examples: severity=high, name="Jane Doe", version=3.11

	Whitespace:
		Whitespace between :: markers, labels, and parameters is ignored. The :: markers
		themselves are always two consecutive colons with no intervening space.

Embedding Elements

	Annotations:
		Annotations use the closed form. The data marker provides the label and
		parameters; the annotation element adds optional content after the closing
		:: marker. See specs/v1/elements/annotation.lex.

		:: label params? :: content?

	Verbatim Blocks:
		The closing line of a verbatim block is a data marker in closed form. It
		signals the end of verbatim content and identifies the content type. See
		specs/v1/elements/verbatim.lex.

		:: label params? ::

	In both cases, the syntactic pattern is identical. The role (annotation header
	vs verbatim closing) is determined by position in the document, not by the data
	marker itself.

Line Classification

	The lexer classifies data marker lines into two line types:

	- <data-marker-line>: closed form with both opening and closing :: markers.
	  Used for annotation start lines and verbatim closing lines.
	- <data-line>: open form with only the opening :: marker. Used for metadata
	  headers where the payload stops after the label block.

	Both require a valid label between the markers. The :: inside quoted parameter
	values (e.g., :: note msg=":: value" ::) is not treated as a structural marker.

Examples

	Simple marker (annotation):
		:: note ::

	With parameters (annotation):
		:: warning severity=high ::

	With quoted values:
		:: author name="Jane Doe", org="Acme Corp" ::

	Verbatim closing:
		:: javascript caption="Hello World" ::

	Open form (no closing marker):
		:: note severity=high
