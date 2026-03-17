#!/usr/bin/env bash

cat <<'EOF'
lex is a very uncommon language, with uncommon syntax and grammar.
in some ways, it's the simplest possible language, but in orders it uses contructs that regualr parsing libraries and common knowlege do not handle well.
Hence, it's critical that you read and follow the tips and guidance bellow, trying to outsmart it guarantess failure.

Above all:

1. Get trifecta parsing right, there is no point trying other elements until you do (since that would mean you don't have intendentation, blank lines and lists and headings and paragraphs right).
2. There is no such a thing as a pargraph. Rather its the fallback, the element when no other can be matched. Any other element is a valid paragraph ("1. Call Mom" is a valid pargraph!).
3. Sequencables (headers and lists), share common forms (seq marker + text), but headers can be marker free , what makes them is context (headings: blank line surrounded, lists need multiple lines with teh right pattern)
4. Follow verbatim.lex spec, and formalize wall parsing,

EOF

cat specs/general.lex specs/grammar-core.lex specs/grammar-line.lex specs/grammar-inline.lex specs/benchmark/080-gentle-introduction.lex specs/benchmark/040-on-parsing.lex
