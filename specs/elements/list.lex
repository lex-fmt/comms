Lists

Introduction

	Lists organize related items in sequence. They are collections of at least two list items, distinguished from single-item paragraphs.
	List items are ordered according to their position in the list, regardless of marker style. For example: 

	2. First item
	1. Second item

	Confusing as it it, marking the first item with "2." does not make it second in the list. The first item is still the first item, and the second item is still the second item, regardless of the marker used.
	Hence, the list markers are about visual formatting. Likewise, Lex does not error on non-sequential numbering or mixed marker styles within a list. The first item's marker style sets the semantic type of the list, but subsequent items can use different markers without affecting the list's structure.
	The style should be consistent for items in the same list / level, but can change across different levels of nesting. Therefore the style is actually a property of the list, not the items.
	Tools (formatters, renderers) can fix ordering and consistency issues, but Lex does not enforce them.

Syntax

	Pattern:
		<blank-line>
		- First item
		- Second item
		- Third item

	Key rule: Lists REQUIRE a preceding blank line
	(for disambiguation from paragraphs containing dash-prefixed text)

	Minimum items: 2
	(single dash-prefixed lines are paragraphs, not lists)

List Item Markers

	Plain (unordered):
		- Item text here

	Numbered:
		1. First item
		2. Second item

	Alphabetical:
		a. First item
		b. Second item

	Parenthetical:
		1) First item
		2) Second item
		a) Alphabetical with parens

	Roman numerals:
		I. First item
		II. Second item

Mixing Markers

	List items can mix different marker styles within the same list.
	The first item's style sets the semantic type, but rendering is flexible.

	Example (all treated as single list):
		1. First item
		2. Second item
		a. Third item
		- Fourth item

Short and Extended Marker Forms

	List markers come in two forms: short and extended.

	Short form markers reference only the current item at the current level:

	1. First item
	2. Second item
		a. Nested first item
		b. Nested second item

	Extended form markers encode the full hierarchical path, including all ancestor indices:

	1. First item
	2. Second item
		2.1. Nested first item
		2.2. Nested second item
			2.2.1. Nested nested item

	The extended form can use different decoration styles per level, as is common practice:

	1. First item
		1.a. Nested first item
			1.a.i. Deep nested first item
			1.a.ii. Deep nested second item
		1.b. Nested second item

	Propagation rule:
	The form is determined by the first item of a nested list (at the second level or deeper, since the root level is too shallow to distinguish short from extended). If a nested list's first item uses extended form, that list and all its inner lists also use extended form.
	When normalization is enabled, formatters rebuild extended markers from the actual list hierarchy, ensuring correct numbering and consistent style at each level.

Blank Line Rule

	Lists require a preceding blank line for disambiguation:

	Paragraph (no list):
		Some text
		- This dash is just text, not a list item

	List (has blank line):
		Some text

		- This is a list item
		- Second item

	No blank lines BETWEEN list items:
		- Item one
		- Item two
		
		- This starts a NEW list (blank line terminates previous)

Content

	List items contain text on the same line as the marker.
	Indented content can contain:
		- Paragraphs (multiple paragraphs allowed)
		- Nested lists (list-in-list nesting)
		- Mix of paragraphs and nested lists
	List items CANNOT contain:
		- Sessions (use definitions instead for titled containers)
		- Annotations (inline or block)

Block Termination

	Lists end on:
		- Blank line (creates gap to next element)
		- Dedent (back to parent level)
		- End of document
		- Start of new element at same/lower indent level

Examples

	Simple unordered list:
		- Apples
		- Bananas
		- Oranges

	Numbered list:
		1. First step
		2. Second step
		3. Third step

	Mixed markers:
		1. Introduction
		2. Main content
		a. Subsection A
		b. Subsection B
		3. Conclusion

	Lists in definitions:
		HTTP Methods:
		    - GET: Retrieve resources
		    - POST: Create resources
		    - PUT: Update resources

	Multiple lists in sequence:
		List one:

		- Item A
		- Item B

		List two:

		- Item X
		- Item Y

	List items with nested paragraphs:
		1. Introduction
		    This is a paragraph nested inside the first list item.

		- Key point
		    Supporting details for this key point.

		    Additional context paragraph.

	List items with mixed content:
		- First item
		    Opening paragraph.

		    - Nested list item one
		    - Nested list item two

		    Closing paragraph.

Use Cases

	- Task lists and checklists
	- Enumerated steps or instructions
	- Feature lists
	- Options or choices
	- Bulleted information
	- Ordered sequences
