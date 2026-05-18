Proposal: Extending Lex — Handler Distribution and Execution

    The extension system specified in *Extending Lex via Label Namespaces* ([./extending-lex.lex]) defines what an extension *is* — a YAML schema, an optional handler, three transports — and the wire format the handler speaks. It is deliberately silent on how the handler binary actually arrives on a user's machine. The `handler.command` field of a schema is a literal argv: the host expands variables, then calls `Command::new(argv[0]).spawn()`. Whatever produces that file is out of scope.

    That silence is fine for the built-in `lex.*` namespace (linked into the host) and for in-process Rust embedders (registered directly). It is *not* fine for the third-party subprocess case, which is the case the platform pivot exists to serve. This proposal closes that gap. It defines a single distribution provider (GitHub Releases, addressed by the same `user/repo` tap convention that already addresses schemas), a per-extension install root that does not contend with the user's PATH, and a small set of fields on the schema that name per-platform release assets. The trust gate from §8 of the parent proposal stays where it is; nothing in the distribution layer expands the host's capability surface.

    The shape we land on is, in one sentence: lex extensions are installed the way `gh` CLI extensions are installed, into the directory the extension's own schema names, and run inside the existing handler sandbox. Everything beyond that — bundlers, language runtime managers, OS-level dependency installers — is either an author concern or a future addendum that fits the same shape without changing it.

1. Motivation

    The status quo is `handler.command = ["my-thing", "--flag"]`. The host expands `${VAR}` references, then spawns whatever the user's operating system happens to resolve. For a script extension whose only dependencies are the unix textutils, that is sufficient. For everything else, it pushes the entire distribution problem onto the extension author *and* the user.

    1.1 What an Author Has to Do Today

        Without a distribution story, an extension author shipping a compiled handler has to:

        - cross-compile the handler for some set of `(os, arch)` pairs they pick
        - decide where to host the resulting binaries
        - write user-facing documentation explaining where to download from, where to put the file, how to mark it executable, how to handle Gatekeeper/SmartScreen, how to upgrade
        - own the long tail forever: new platforms, new OS minor versions, broken links, asset renames

        None of that is a Lex problem. All of it is a Lex *adoption* problem. An author who is one weekend's work away from a useful extension is two weeks away from a *distributable* extension, and most never close that gap. The result is a platform whose extensions exist only in the laptops of their authors.

    1.2 What a User Has to Do Today

        A user installing such an extension has to: find the right download URL for their platform, manually fetch the binary, place it where their `lex.toml` expects it, mark it executable, and re-do the dance on upgrade. Every author invents their own version of these instructions. Every user becomes a package manager for the duration of the install.

        The asymmetry compounds: a small-cost-per-author becomes a small-cost-per-user, and the cross product is enough friction that the extension surface stays underused.

    1.3 The Goal

        The extension system already moved the schema-and-trust questions to a single contract. The distribution question deserves the same treatment: one mechanism, one set of conventions, ergonomic enough that the median author can ship a cross-platform extension as a release-tag side effect, ergonomic enough that the median user installs it with one command and forgets it exists. The host must not become a package manager. The mechanism must not require third-party infrastructure beyond GitHub. The mechanism must compose with the existing trust matrix rather than open new holes in it.

2. Options Considered

    The plugin-systems literature converges on a small number of shapes for this problem. Each picks who pays the platform-matrix cost; none eliminates it for the binary case.

    2.1 Bring Your Own PATH

        Pandoc filters, Helix language servers, cargo and git subcommands. The host spawns whatever name the configuration names; resolution falls through to the operating system. The user is the package manager.

        Wins: zero infrastructure, day-one usable, the right floor for internal tooling and one-off scripts. Loses: no discovery, no version pinning, no checksum or signature, and the per-user install cost survey rules out non-trivial adoption.

        This is what lex has today (`command = ["my-filter"]`). It is necessary as an escape hatch and insufficient as the primary path.

    2.2 Manifest with Per-Platform Asset Stanza

        `gh` CLI extensions and `kubectl krew` plugins. A manifest declares an array of `(os, arch) → url, sha256, bin` entries; the host fetches the matching one, verifies the digest, and installs into a per-extension directory under the user's data root. The author is the package matrix; the host is a thin downloader.

        Wins: proven by two ecosystems with thousands of users each, no host-side build step, composes cleanly with `--pin` for reproducibility, one-line release-side workflow (`gh-extension-precompile` for `gh`, a GoReleaser plugin for krew). Loses: the author still owns cross-compilation; nothing in the manifest helps an extension whose handler is a Python or Node script.

    2.3 WASM Component Handler

        Zed's extension model, Extism's plugin model. The author ships a single `.wasm` file; the host embeds a runtime and dispatches into it via a WIT-described interface. The platform matrix vanishes for pure-computation handlers because there is only one artifact.

        Wins: zero platform matrix, sandbox is structural rather than enforced, polyglot at the source-language level. Loses: native LSP-style handlers and any extension that shells out to a real toolchain still need a subprocess underneath the WASM (Zed authors typically download a per-platform LSP binary from inside their WASM extension), so the matrix problem returns through the back door for non-pure handlers. As of late 2025, language coverage outside Rust/JS/Go is still rough.

        The parent proposal already names a WASM transport as a deferred third tier. This proposal does not block it; the distribution mechanism specified below resolves to absolute paths inside an install root, and a `.wasm` artifact slots into the same shape.

    2.4 Tiered Language-Runtime Bootstrap

        `pre-commit`'s model. The host re-implements an installer per language: for `python`, build a venv; for `node`, fetch the toolchain; for `rust`, `cargo install`. The author writes code, ships source, declares a language tier.

        Wins: serves the long tail of "extension is a small Python script" without forcing the author through a release pipeline. Loses: the host grows a bootstrap subsystem per supported language, which is a permanent maintenance load. `pre-commit`'s complexity lives almost entirely here, and the cost is visible.

        We do not adopt this in v1 but call it out as a natural future extension ([#8]).

    2.5 Curated Registry

        Mason.nvim. A third-party adapter layer where volunteer maintainers write small YAML wrappers around upstream releases. The author does nothing lex-specific; a maintainer at the adapter layer maps "extension X" to "fetch this asset."

        Wins: best UX. Loses: requires sustained volunteer attention the project does not have at v1. Worth revisiting once the extension count justifies it.

3. Why the gh Model

    The manifest-with-per-platform-asset-stanza shape ([#2.2]) is the right fit for lex, for four reasons that compound.

    3.1 The Tap Convention Already Exists

        The parent proposal grounds namespace ownership in `user/repo` taps resolving to GitHub repositories ([./extending-lex.lex] §4.1). A schema for `acme.commenting` already lives in `github.com/acme/lex-labels`. Putting the *handler binaries* in the GitHub Releases of that same repository is a zero-new-concepts extension. One organisation, one repository, one place a `lex.toml` entry points at, both for the schema and for the executable code.

        Authors who already understand the schema-publishing flow learn nothing new to publish a handler. Users who already trust `acme = { tap = "acme" }` for schemas are not asked to trust a second source for binaries.

    3.2 The Distribution Is GitHub's Problem

        GitHub Releases is durable, free, content-addressable, geo-distributed, and integrated with the CI system most extension authors will already be using. lex does not host anything, does not pay for bandwidth, does not maintain a registry. The bus factor is GitHub's.

    3.3 The Asset Naming Convention Is a Manifest

        `gh` resolves per-platform assets by suffix-matching the filename against a known `(goos, goarch)` table. The "manifest" is literally the asset name. There is no separate YAML field for platforms, no parsing step, no per-release ceremony beyond uploading files with predictable names. The release workflow that produces those files (`cli/gh-extension-precompile`) is six lines of YAML.

        We adopt the same convention. An extension that wants to ship for `(macOS, arm64)` uploads a release asset whose name ends in `darwin-arm64`. The host resolves the user's platform string and picks the matching asset. The release-side automation is one Composite Action away.

    3.4 The Sandbox Is Already There

        The parent proposal's trust matrix ([./extending-lex.lex] §8) already names OS-level sandboxing as the enforcement mechanism for declared capabilities. That mechanism applies to *any* subprocess handler regardless of how the binary arrived. Adding a distribution layer does not require a new sandboxing story; it slots into the existing one. A handler downloaded from a GitHub Release runs under the same `LinuxSandbox` / `MacosSandbox` / null-on-Windows enforcement as a handler the user dropped into `~/bin` by hand.

        Crucially, the distribution layer does not earn any extra trust by virtue of being structured. A signed-and-pinned binary fetched from a `lex.toml`-declared tap is still a *subprocess handler with declared capabilities*, and its capability declaration is what governs what it can do. The trust model already separates "is this code I want to run at all" (a prompt-and-pin question) from "what is this code allowed to touch when it runs" (a sandbox question). The distribution mechanism is orthogonal to both.

    3.5 The Schema Is the Plugin

        A structural property worth foregrounding before the mechanics: the YAML schema file is itself the plugin. A namespace owner does not author a schema *and* a manifest *and* an install script. They author one YAML file per label, and that single file contains everything a host needs to validate the label, drive editor tooling for it, fetch its executable code, and run that code under the right sandbox.

        Concretely, one `acme-commenting.yaml` carries the param declarations editors use for autocomplete, the body shape the parser uses for descent, the capability declaration the sandbox enforces, the hook set the registry uses for dispatch, *and* (per [#4]) the per-platform asset URLs and digests the installer uses to fetch the handler. A user who wants to inspect what an extension does and where its code comes from reads one file. A user who wants to fork or vendor an extension copies one file. A CI job that wants to pin an extension commits one file. There is no "plugin package" as a distinct unit from the schema; the schema *is* the package.

        The cost is install-time fragility. A `[release]` block can reference a URL that no longer exists, a digest that does not match a renamed asset, or — in the future runtime-tier case ([#8]) — a source archive that is malformed or missing the declared lockfile. These failure modes are concentrated into the install step, which is bounded in time and recoverable: the user retries, or the namespace owner publishes a fixed schema. They never become document-open-time failures, never silently corrupt user data, and never escalate past "install failed with this specific cause." We consider the trade clearly worth it: a single-file plugin is an unusually clean unit of distribution, and the install-time failure modes are diagnostic problems with diagnostic answers.

        Everything that follows is a consequence of this property. The `[release]` block in [#4] lives in the schema because the schema is the plugin. The single-purpose tap repository pattern in [#5] is natural because all an author publishes is YAML files and a CI workflow that uploads what the YAML names. The runtime-tier addendum in [#8] keeps the property: a node-flavoured extension is still one YAML file pointing at a source archive plus a lockfile name, not a YAML plus a separate package descriptor.

        The single-file property has one notable cost: a namespace with many labels sharing one multi-call handler binary duplicates the `[release]` block across every schema, and a version bump touches every file. We accept this for v1. The duplicated content is small (a tag, an asset pattern, a handful of digests), mechanical, and trivially codegen-able from one source of truth in the author's repo. A future revision can introduce namespace-level defaults — a `release.yaml` at the tap root whose fields apply unless overridden per schema — additively, without changing the per-schema surface or breaking v1 schemas. Inheritance is sugar over the property, not a replacement for it.

4. The Provider Surface

    A schema gains an optional `[release]` block alongside the existing `[handler]` block. The two compose: `[handler]` says *what* runs and how the host talks to it; `[release]` says *where the bits come from* and how to locate them on disk.

    4.1 The Release Block

        A minimal example, in the same YAML format used by the rest of the schema:

            handler:
              transport: subprocess
              command: ["${ext_dir}/acme-commenting"]
              timeout_ms: 2000

            release:
              provider: gh
              repo: acme/lex-labels
              version: v1.4.0
              asset_pattern: "acme-commenting-${version}-${os}-${arch}${exe_suffix}"
              sha256:
                darwin-arm64: "abc123..."
                darwin-amd64: "def456..."
                linux-amd64:  "789..."
                linux-arm64:  "..."
                windows-amd64: "..."
        :: yaml ::

        Fields:

        - `provider` — the resolver scheme. `gh` is the v1 provider and the only one specified here. Future providers (`gitlab`, `https`, `path`) follow the same pluggable resolver shape the parent proposal already uses for schema URIs.
        - `repo` — the `owner/name` pair. Defaults to the namespace's schema-source repo when omitted (the common case: one repo holds schemas and binaries together).
        - `version` — the release tag to fetch from. May be `latest` to track the latest published release; `latest` resolution follows the same cache TTL and refresh rules as schema resolution ([./extending-lex.lex] §4.4).
        - `asset_pattern` — the asset-name template. Available variables: `${os}` (`darwin`, `linux`, `windows`), `${arch}` (`amd64`, `arm64`, `386`, `arm`), `${exe_suffix}` (`.exe` on Windows, empty elsewhere), and `${version}` (the resolved release tag — useful for authors whose release tooling embeds the tag in the filename). The `${os}` and `${arch}` values follow the `gh`/Go convention deliberately; authors writing Rust or C++ extensions map their target triples to these strings, which are the lowest common denominator across plugin ecosystems. Patterns that resolve to no matching asset fail at install time with a precise error.
        - `sha256` — required per-platform digests. Install verifies the digest before writing the binary into `${ext_dir}/`. There is no opt-out.

        v1 ships **raw single-file binaries** only — `asset_pattern` resolves to one downloaded file per `(os, arch)`. Archive-shaped assets (`.tar.gz` containing a tree, multi-file payloads, sidecar resources) are deliberately out of scope for v1. The runtime-tier addendum ([#8]) extends `[release]` to source-archive distribution along the same shape if and when that case becomes load-bearing.

        The `${ext_dir}` placeholder in `handler.command` resolves to the install root for this specific extension (`[#4.3]`), so the schema and the handler agree on layout without the author hard-coding paths.

    4.2 The Install Lifecycle

        `lexd labels install acme/lex-labels` (or an automatic install on first use of a `lex.toml`-declared tap, gated by the trust matrix):

        - Fetch the schema directory from `github.com/acme/lex-labels` (existing schema resolver).
        - For each label whose schema declares a `[release]` block, fetch the asset matching the user's `(os, arch)` from the named release tag.
        - Verify the `sha256` digest. A mismatch is a hard install failure with no recovery beyond the author publishing corrected digests.
        - Write the resolved binary into `${ext_dir}/`, **renaming it to a platform-independent canonical name** by stripping the `-${version}-${os}-${arch}${exe_suffix}` tail from the resolved `asset_pattern`. The result is a stable filename across all platforms (`acme-commenting` in the example above), so `handler.command` can reference one path regardless of where the user is. Mark the file executable on Unix (`chmod +x`).
        - On macOS, clear the `com.apple.quarantine` extended attribute if set. On macOS arm64, additionally ad-hoc re-sign the binary (`codesign --sign -`) to satisfy the kernel's "must have some signature" requirement. This is what `gh` does, and the reason its arm64 install path works.
        - Write a `lex-release.lock` alongside the binary, recording the tag, original asset name, and digest actually installed.

        Upgrade is `lexd labels upgrade acme` (per-namespace) or `lexd labels upgrade --all`. The host compares the locked tag against the upstream `latest` (or against the value of `release.version` if pinned), and re-runs the install when they differ. Pinned versions never upgrade without an explicit `--force`.

    4.3 The Install Root

        Each label's handler lives in its own directory under the user's data root:

            ${XDG_DATA_HOME:-~/.local/share}/lex/ext/<namespace>/<label>/      (Unix)
            %LOCALAPPDATA%\lex\ext\<namespace>\<label>\                        (Windows)

        `${ext_dir}` in `handler.command` expands to this path. Nothing the extension contains ever lands on the user's PATH, in the user's home, or alongside the user's system binaries. An extension that wants its own writable scratch space gets one inside its install root; an extension that wants to read from the user's filesystem has to declare `capabilities.fs: true` and pass the sandbox.

        Removing an extension is `rm -rf ${ext_dir}/`. There is no shared state, no leftover symlinks, no PATH entry to clean up.

    4.4 Pinning and Reproducibility

        The lockfile sketched above (`lex-release.lock`, written into `${ext_dir}/` next to the binary) records what was actually installed. `lex.toml` can pin a release tag explicitly:

            [labels.acme]
            tap = "acme"
            release_pin = "v1.4.0"
        :: toml ::

        With `release_pin` set, `lexd labels upgrade` is a no-op for that namespace until the pin moves. Without it, the resolver tracks the schema's `release.version` (which itself may name `latest` or a fixed tag — the schema author's choice).

        This is the same pattern the parent proposal already uses for schema reproducibility ([./extending-lex.lex] §4.4): immutable references cache indefinitely, mutable references are subject to a TTL and an explicit refresh command.

5. The Single-Purpose Tap Repository

    The mechanism above collapses into a particularly clean idiom: one GitHub repository per namespace, hosting both schemas and handler releases. A namespace owner who wants to ship `acme.commenting`, `acme.task`, and `acme.review` creates `github.com/acme/lex-labels` and:

    - Commits one YAML schema per label under `schemas/`.
    - Writes one cross-compile workflow (the lex equivalent of `cli/gh-extension-precompile`, which we will ship as `lex-fmt/lex-handler-precompile` — a Composite Action over `cargo zigbuild` or `cross` for Rust, with a `build_script_override` escape hatch for non-Rust authors).
    - Tags a release. The workflow cross-compiles, uploads platform-named artifacts, and produces a release. End-users running `lexd labels upgrade` pick up the new version automatically.

    The author writes no installation documentation. The user runs one command and sees the extension begin to work. The repository's URL is the only thing either party has to remember, and it is already where the schemas live.

6. Trust and the Sandbox

    The distribution layer does not relax the trust matrix from the parent proposal. Specifically:

    - Fetching a schema is unchanged from the existing schema-resolution path. No new code runs as a side effect.
    - Fetching a release asset is a network operation, not a code-execution operation. It happens during `lexd labels install`/`upgrade`, after the user has authorised the tap (either by adding it to `lex.toml` or by interactive prompt). It does not happen as a side effect of opening a document.
    - The first run of a newly installed handler goes through the same prompt-and-pin gate any subprocess handler goes through — the matrix in *Extending Lex* §8 applies unchanged.
    - The handler runs inside the OS-level sandbox honouring its declared capabilities. The sandbox does not distinguish between a binary downloaded from a release and a binary placed there by the user.

    The two new failure modes the distribution layer introduces — wrong digest and missing asset — are install-time errors, not runtime errors. They cannot escalate into anything more serious than a failed install.

7. What This Rules In and Out

    Rules in:

    - One-command install and upgrade of third-party handlers for any namespace whose authors choose to publish releases.
    - A single release-side workflow (cross-compile + tag) producing a working extension for every supported platform.
    - Per-extension install roots with no PATH contention, no shared state, no system-level installation.
    - Reproducible installs via `release_pin` and per-asset SHA-256 digests.
    - The same trust matrix and the same sandbox as the rest of the extension system.

    Rules out (intentionally):

    - lex installing, managing, or shipping language runtimes (Node, Python, Lua, JVM, etc.). An extension that needs a runtime declares the dependency in its README and either bundles the runtime into a single executable or asks the user to install it via the user's existing package manager.
    - lex acting as a package manager for OS-level dependencies. A handler that needs `libfoo.so` documents the requirement; the user satisfies it; or the author bundles statically. There is no host-side `apt`/`brew`/`yum` integration.
    - A centralised registry, marketplace, search index, or curation layer at v1. Discovery is `github.com/topics/lex-extension` (mirroring the `gh-extension` convention), or whatever ad-hoc discovery the community converges on.
    - Code signing as a host responsibility beyond ad-hoc re-signing on macOS arm64 to satisfy the kernel. SHA-256 digests in the schema are the v1 integrity story; sigstore attestations and GPG-signed checksums are an additive future tier.

8. Addendum: Runtime Tiers

    The rules-out list deliberately omits language runtime managers. We expect a class of extensions whose handler is a short Python or Node script wrapping a domain-specific library, for which "ship a cross-compiled binary" is the wrong answer (the author has no Rust, and bundling Python via PyInstaller or Node via SEA is a 50–100MB artifact for a 200-line script).

    The shape this proposal commits to does not preclude later support for those cases. A future `[handler]` extension could declare a `runtime` tier alongside the existing `transport`, and the same `[release]` block would carry a source archive instead of (or alongside) per-platform binaries:

        release:
          provider: gh
          repo: acme/lex-labels
          version: v1.4.0
          source_archive: "acme-commenting-v1.4.0-src.tar.gz"
          sha256:
            source: "abc123..."

        handler:
          transport: subprocess
          runtime: node
          command: ["node", "${ext_dir}/handler.js"]
          lockfile: package-lock.json
    :: yaml ::

    The schema-is-the-plugin property ([#3.5]) survives intact: one YAML file still names everything the host needs. With `runtime: node`, the host would, at install time, fetch and verify the source archive, extract into `${ext_dir}/`, locate the declared `lockfile`, and shell out to a per-extension version pin of a runtime manager (volta, fnm, uv for Python, etc.) targeted at the same install root. The runtime would be installed into the extension's own root — never on the user's PATH, never interacting with the user's system Node or Python. Uninstalling the extension would remove the runtime with it.

    This is a strict addition to the design in [#4] — same install root, same trust gate, same sandbox, additional bootstrap step gated on a declared field. We do not specify it in v1 because:

    - The author surface is fine without it. An author with a Node script can either bundle via `bun build --compile` (one ~85MB binary) and ship the result through `[release]`, or document `node` as a `runtime: system` requirement and depend on the user's PATH.
    - Specifying the runtime-manager integration requires picking a runtime manager per language, taking a dependency on its CLI and its semantics, and updating that choice as the ecosystem evolves. The right time to pick is when a critical mass of extensions wants it.
    - Lua is the interesting third candidate. A future runtime tier for Lua would slot in the same way, likely backed by `luarocks --tree=${ext_dir}/luarocks`. The shape generalises cleanly.

    The headline point is that adding runtime tiers later does not require revisiting the distribution model, the trust matrix, the sandbox, or the `lex.toml` surface. It is a new value of one field, gated on a new install-time bootstrap step, fitting the existing slots.

9. Summary

    `gh` solved this for the CLI ecosystem with a small set of conventions and zero third-party infrastructure: tap-shaped repo addressing, release-asset naming as the manifest, per-extension install roots, lockfiles for pinning, and a Composite Action that turns cross-compilation into six lines of CI. Lex adopts the same shape, with three small additions specific to the platform: schemas and releases co-located in one tap repo, mandatory per-platform SHA-256 digests, and an install root resolvable from the schema's own `handler.command` via `${ext_dir}`. The existing trust matrix and sandbox absorb the new path without modification.

    The result is a distribution mechanism authors can adopt as a release-tag side effect and users can adopt with one command. Everything heavier than that — runtime managers, OS-level dependencies, bundling tools — is either an author choice or a future addendum that fits the same slots.
