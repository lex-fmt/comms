#!/usr/bin/env bash
# scripts/setup-dev-env.sh — per-session dev-environment setup, invoked by
# the SessionStart hook in .claude/settings.json.
#
# Source of truth: arthur-debert/release templates/setup-dev-env.sh.
# Re-sync via the gh-repo-setup skill (or by copying this file verbatim).
# Repos that need project-specific extras (Xvfb daemon, pinned-binary
# fetch, extra rustup targets, etc.) append them below the marker at the
# bottom — anything above it is rsync'd from the template.
#
# Cloud-only: local sessions exit early (devs already have their env).
# Detects stack by filesystem signals — handles rust, node, ruby, python,
# and consumers with no project deps (just lefthook / hand-rolled hook
# wiring).
#
# Idempotent — safe to re-run. Errors are best-effort: a failure in one
# step does not abort the rest (transient registry hiccups shouldn't
# block the lefthook install).

set -euo pipefail

# Cloud-only gate. Local sessions already have their env set up.
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "${REPO_ROOT}"

# --- 1. Universal git hygiene --------------------------------------------
# Cloud clones are shallow; restore submodule content and release tags.
# Submodule update is a no-op when in sync; tag fetch is one round-trip.

if [ -f .gitmodules ]; then
  git submodule update --init --recursive --quiet || true
fi
git fetch --tags --quiet origin || true

# --- 2. Project dep cache ------------------------------------------------
# Pick the right tool based on lockfile / manifest. Per stack, idempotent.

# Rust: cargo fetch with --locked so we don't silently mutate Cargo.lock.
if [ -f Cargo.toml ] && command -v cargo >/dev/null 2>&1; then
  cargo fetch --locked --quiet || true
fi

# Node (npm/yarn/pnpm). We deliberately do NOT guard on `! -d node_modules`:
# the env-snapshot caches a node_modules paired with a previous branch's
# lockfile, and a feature branch that bumps the lockfile (Playwright is
# the canonical case) drifts silently. Re-installing when already in sync
# is ~2s; chasing a stale lockfile bug is hours. Pay the two seconds.
if [ -f package.json ]; then
  if [ -f package-lock.json ] && command -v npm >/dev/null 2>&1; then
    npm ci 2>/dev/null || npm install
  elif [ -f yarn.lock ] && command -v yarn >/dev/null 2>&1; then
    yarn install --frozen-lockfile 2>/dev/null || yarn install
  elif [ -f pnpm-lock.yaml ] && command -v pnpm >/dev/null 2>&1; then
    pnpm install --frozen-lockfile 2>/dev/null || pnpm install
  fi
fi

# Ruby / Bundler.
if [ -f Gemfile ] && command -v bundle >/dev/null 2>&1; then
  bundle install --quiet || true
fi

# Python / pip + venv. Only initialise if .venv missing — pip install is
# slower than node/cargo and the guard wins more than it costs.
if [ -f pyproject.toml ] && [ ! -d .venv ] && command -v python3 >/dev/null 2>&1; then
  python3 -m venv .venv
  .venv/bin/pip install --upgrade pip --quiet || true
  .venv/bin/pip install -e '.[dev]' --quiet 2>/dev/null \
    || .venv/bin/pip install -e . --quiet 2>/dev/null \
    || true
fi

# --- 3. Pre-commit hook wiring -------------------------------------------
# Default: lefthook (binary installed at env-setup time). Fallback for
# repos that ship a hand-rolled scripts/pre-commit instead (zed-lex,
# tree-sitter-lex pattern): symlink it into .git/hooks/.

if [ -f lefthook.yml ] && command -v lefthook >/dev/null 2>&1; then
  if ! lefthook install >/dev/null; then
    echo "warning: lefthook install failed — pre-commit hook NOT wired" >&2
  fi
elif [ -x scripts/pre-commit ]; then
  mkdir -p .git/hooks
  ln -sf ../../scripts/pre-commit .git/hooks/pre-commit
fi

# --- 4. Project-local extras ---------------------------------------------
# Everything above this marker is the canonical cross-repo setup-dev-env.sh
# from arthur-debert/release templates/setup-dev-env.sh. Do NOT modify it
# in-place; consumers append project-specific steps BELOW this marker.
# (See e.g. lex-fmt/lexed for an Xvfb start, lex-fmt/nvim for pinned-bin
# fetches.)


# Bundler install for docs/. The cloud env's rbenv layout puts gem
# executables at /opt/rbenv/versions/<v>/bin/, but `bundle exec` looks
# under <gem-install-dir>/bin/ (which doesn't exist), so `bundle exec
# jekyll` fails to find the binary. Generating local binstubs in docs/bin/
# sidesteps this — callers run `./bin/jekyll …` from docs/.
if [ -f docs/Gemfile ] && command -v bundle >/dev/null 2>&1; then
  (
    cd docs
    bundle install --quiet || echo "warning: bundle install failed in docs/" >&2
    bundle config set --local bin bin >/dev/null 2>&1
    bundle binstubs --all --force >/dev/null 2>&1
  )
fi

# lex CLI — version + repo pinned in shared/lex-deps.json. Always re-installs
# (no `command -v lex` short-circuit) so a bump to the pinned version takes
# effect on session resume, not just on fresh containers.
if [ -f shared/lex-deps.json ] && command -v jq >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
  LEX_VERSION="$(jq -r '."lex-cli"' shared/lex-deps.json)"
  LEX_REPO="$(jq -r '."lex-cli-repo"' shared/lex-deps.json)"
  LEX_DIR="/tmp/lex-cli"
  LEX_ARCH="$(uname -m | sed 's/arm64/aarch64/')"
  LEX_URL="https://github.com/${LEX_REPO}/releases/download/${LEX_VERSION}/lex-${LEX_ARCH}-unknown-linux-gnu.tar.gz"
  mkdir -p "${LEX_DIR}"
  if curl -fsSL -o "${LEX_DIR}/lex.tgz" "${LEX_URL}" \
      && tar -xzf "${LEX_DIR}/lex.tgz" -C "${LEX_DIR}" \
      && chmod +x "${LEX_DIR}/lex"; then
    if ! ln -sf "${LEX_DIR}/lex" /usr/local/bin/lex 2>/dev/null; then
      echo "warning: could not symlink lex to /usr/local/bin (permission denied?) — invoke directly via ${LEX_DIR}/lex" >&2
    fi
  else
    echo "warning: lex CLI download failed (${LEX_URL})" >&2
  fi
fi

exit 0
