#!/usr/bin/env bash
# scripts/setup-dev-env.sh — per-session dev-environment setup, invoked by
# the SessionStart hook in .claude/settings.json.
#
# Cloud-only: local sessions exit early (devs already have their env set up).
# Detects stack by filesystem signals — works for rust, node-flavored
# (npm/yarn/pnpm), ruby (bundle), and nvim/zed/static-site (no project
# deps, just lefthook wiring). Stack-specific extras (e.g. resource
# download scripts, submodule init) can be added below the universal
# section as needed for the particular repo.
#
# Idempotent — safe to re-run. Errors are best-effort: a failure in one
# step doesn't abort the rest (e.g. transient registry hiccup on cargo
# fetch shouldn't block the lefthook install).

set -euo pipefail

# Cloud-only gate. Local sessions already have their env set up.
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "${REPO_ROOT}"

# 1. Project dep cache — pick the right tool based on lockfile / manifest.

# Rust: cargo fetch with --locked so we don't silently mutate Cargo.lock
# in the per-session clone. Stale lockfile produces a non-fatal exit;
# the agent's later cargo build/test surfaces the real issue.
if [ -f Cargo.toml ] && command -v cargo >/dev/null 2>&1; then
  cargo fetch --locked --quiet || true
fi

# Node-based (npm / yarn / pnpm). Skip if node_modules already exists
# (warm from a previous session within the same env-snapshot).
if [ -f package.json ] && [ ! -d node_modules ]; then
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

# 2. Pre-commit hook wiring (lefthook).
# Binary is installed at env-setup time (arthur-debert/release env/setup.sh);
# this just wires .git/hooks/pre-commit to call it. Errors are surfaced
# loudly — the whole point of the script is the hook install.
if [ -f lefthook.yml ] && command -v lefthook >/dev/null 2>&1; then
  if ! lefthook install; then
    echo "warning: lefthook install failed — pre-commit hook NOT wired" >&2
  fi
fi

# 3. comms-specific extras.
# This repo's only buildable artifact is the Jekyll docs site under docs/,
# which depends on (a) Ruby gems from docs/Gemfile and (b) the pinned lex
# CLI from shared/lex-deps.json. The universal Gemfile check above only
# looks at the repo root, so we wire docs/ explicitly here.

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

# lex CLI — version + repo pinned in shared/lex-deps.json. Downloaded
# tarball goes under /tmp (per-session, fine for cloud); the binary is
# symlinked to /usr/local/bin/lex so docs/build (and ad-hoc invocations)
# find it without env tweaks. Always re-installs (no `command -v lex`
# short-circuit) so a bump to the pinned version in lex-deps.json takes
# effect on session resume, not just on fresh containers.
if [ -f shared/lex-deps.json ] && command -v jq >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
  LEX_VERSION="$(jq -r '."lex-cli"' shared/lex-deps.json)"
  LEX_REPO="$(jq -r '."lex-cli-repo"' shared/lex-deps.json)"
  LEX_DIR="/tmp/lex-cli"
  # uname normalisation: macOS reports arm64, the release tarballs use
  # aarch64. Script is cloud-only Linux so darwin URLs aren't needed.
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
