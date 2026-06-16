lex.ing Site - Architecture

This directory contains the source for lex.ing, the documentation site for
the lex markup language. The site uses MkDocs (Material theme) with the
mkdocs-lex plugin for native .lex rendering, and GitHub Pages for hosting.


1. Directory Structure

   mkdocs.yml               MkDocs config (theme, nav, plugins) — at repo root
   docs/
   ├── CNAME                Custom domain (lex.ing)
   ├── requirements.txt     Python deps (mkdocs, material, mkdocs-lex-plugin)
   │
   ├── index.lex            Lex-authored pages (edited directly; the
   ├── about.lex            mkdocs-lex plugin converts .lex → markdown
   ├── why.lex              just-in-time at build time)
   ├── tools.lex
   ├── dummy-session.lex
   ├── font-ligatures-symbols.lex
   ├── interop-scope.lex
   │
   ├── editors.md           Pure markdown pages (no lex source)
   ├── contributing.md
   ├── specs/index.md
   │
   ├── README.lex           This file (excluded from the build)
   └── site/                MkDocs output (gitignored)


2. Build Pipeline

   Single stage. MkDocs builds the site; the mkdocs-lex plugin intercepts
   each .lex file and converts it to markdown via `lexd convert` on the
   fly (no temporary .md files, no separate build step). The Material
   theme styles the result. The plugin auto-downloads the matching `lexd`
   binary from lex-fmt/lex releases on first run (cached under
   .mkdocs_lex_cache/); if `lexd` is already on PATH it uses that.

   Nav paths in mkdocs.yml use .md extensions even for .lex sources — the
   plugin tricks MkDocs into treating them as markdown pages.


3. Local Development

   Prerequisites:
   - Python 3.x

   Setup and serve:
      python -m venv .venv && source .venv/bin/activate
      pip install -r docs/requirements.txt
      ./serve                     # http://localhost:8000 with livereload
      ./serve --port 8080         # custom port
   Build (strict, same as CI):
      bin/check                   # mkdocs build --strict (after release-core init)
      mkdocs build --strict       # or directly
   :: shell ::


4. GitHub Pages Deployment

   The site deploys automatically on push to main via GitHub Actions.

   The workflow (.github/workflows/docs.yml) is a thin caller of the
   shared reusable workflow:

      uses: arthur-debert/release/.github/workflows/mkdocs.yml@v3
   :: yaml ::

   It runs `mkdocs build --strict` and deploys to GitHub Pages. PRs that
   touch docs build (strict) without deploying, so broken refs fail before
   merge. No lex CLI download step is needed — the mkdocs-lex plugin
   fetches `lexd` itself.


5. Adding a New Page

   For a lex-authored page:

   1. Create docs/<name>.lex with your content
   2. Add a nav entry in mkdocs.yml pointing at <name>.md (the plugin
      maps the .md path to the .lex source)

   For a pure markdown page:

   1. Create docs/<name>.md with your content
   2. Add a nav entry in mkdocs.yml


6. Release Fleet

   This repo is managed by arthur-debert/release as the docs-site Kind
   (detected by the root mkdocs.yml). `release-core init` installs the
   shared lint gate + tooling into .release/ (a gitignored directory) and symlinks; the mkdocs
   Capability (.release-sync.yaml) adds bin/check-docs. Do not hand-edit
   files under .release/ or the managed symlinks.
