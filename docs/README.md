# lex docs

This site now stores long-form content in [Lex](https://lex.ing) files under `_lex_src/`. Run `bin/build-lex.sh` to regenerate the HTML fragments before running Jekyll locally:

```bash
cd docs
LEX_BIN=../../tools/target/release/lex bin/build-lex.sh
bundle exec jekyll serve
```

`LEX_BIN` defaults to `lex` on your `$PATH`. Set it explicitly if you keep the binary in a sibling checkout.
