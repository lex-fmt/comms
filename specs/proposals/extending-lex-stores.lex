Specification: Lex Extension Stores

    Extensions need to live somewhere. The parent proposal ([./extending-lex.lex]) introduces the extension system as a whole — namespaces, schemas, hooks, transports, trust — and sketches the resolution side as a list of URI schemes (`github:`, `gitlab:`, `https:`, `path:`, `git+ssh:`). That sketch turns out to conflate two different concerns: *transports* (how schemas are fetched from a source) and *URL templates* (sugar that turns a forge-shorthand into a transport-specific URL). This document separates them.

    The motivating question is concrete. Is `github:acme/lex-labels` a different *kind* of thing than `https:.../tarball.tar.gz`, or is it the same thing with a friendlier name? The answer steers what a store implementer has to build, what knobs the configuration surface needs, and how the system grows when someone wants to add a Gitea or Codeberg backend. This spec works the question through and lands on a small, principled decomposition: three real transports, an arbitrary number of URL templates that resolve into them.

    Wire-format and AST details remain in [./lex-extension-wire.lex]. Hook semantics, trust prompts, and the extension philosophy remain in [./extending-lex.lex]. This document is scoped tightly to *how schemas get from their source to a local schema directory*.

1. Motivation

    The parent proposal at §4.2 lists five URI schemes side-by-side as if they were peers. Implementation experience reveals they are not. `path:` and `https:` are different in kind from each other, but `github:` is not different in kind from `https:` — it is a *naming convention* that produces an `https:` URL (the GitHub tarball API endpoint) from a terser `<owner>/<repo>/<ref>` triple. The same is true of `gitlab:`. And `git+ssh:` is one of several URL forms a real Git transport accepts (`https://...git`, `git@host:path`, `git://host/path`); making it a top-level scheme misclassifies it.

    Modelling these as five peer stores produces a system with too many fetchers (one per scheme), too much duplication (the github and gitlab fetchers would re-implement HTTPS GET and tarball extraction), and the wrong extension story (adding Codeberg would require a new fetcher rather than a new URL template). Factoring along the real axis — transport — produces three concrete fetchers and a URL-template layer that sits above them. Adding a new forge becomes ~20 lines of pure URL-template code; adding a new transport remains rare but is bounded.

2. The Store Concept

    2.1 What a store is

        A *store* is a backend that turns a resolved URI into a local directory of schema YAML files. It owns one network or filesystem mechanism end-to-end: opening files, making HTTP requests, spawning `git clone`, extracting archives. The trait surface the host needs is small — fetch, declare which URI schemes it owns, declare whether a given revision is immutable for cache purposes. Everything else is a store's private concern.

        A store has no opinions about ownership, naming conventions, or what a schema means once fetched. It is a pure data-movement layer: given a URI and a destination directory, populate the directory and return.

    2.2 What a store is not

        A store is *not* a URL pattern. A forge-shorthand like `github:owner/repo` is a URL template, not a store: at resolution time it expands into either an `https:` tarball URL or a `git:` clone URL, and the corresponding store does the actual work. The github-ness is in the template's knowledge of GitHub's URL conventions; the fetching is the responsibility of the underlying store.

        Conflating the two layers is what motivated this spec. A store knows nothing about GitHub, GitLab, or any specific forge. A URL template knows everything about a specific forge but nothing about how to make a network request.

3. The Three Transports

    3.1 Filesystem (path)

        Reads from a directory on the local filesystem. Used for local development, vendored schemas, and project-relative bundles. The URI is a filesystem path, resolved relative to the workspace root when relative. No network, no auth, no extraction. Cache TTL is irrelevant; reads are direct.

        URI shape:

            path:./shared/labels
            path:/absolute/path/to/labels
            path:../sibling/repo/labels
        :: text ::

    3.2 HTTPS Tarball (https)

        Performs a single HTTPS GET against a URL, expecting a `tar.gz` or `zip` archive in response. Extracts the archive into the destination directory, optionally descending into a `subdir`. This is the universal "fetch a published artifact" transport — it works against any HTTP server that can serve a tarball: artifact registries (Artifactory, Nexus), object stores (S3, GCS, Azure Blob with presigned URLs), forge tarball APIs (GitHub, GitLab, Gitea), or a static Nginx behind a corporate proxy.

        URI shape:

            https:https://nexus.example.com/lex-labels-1.2.tar.gz
            https:https://example.com/static/foo.zip
        :: text ::

        Authentication is by way of an optional `Authorization` (or arbitrary) header pass-through; see [#6.2].

    3.3 Git (git)

        Shells out to the `git` binary in PATH (preferred over libgit2 for credential coverage; see [#6.3]) to perform a shallow clone at a specific revision into the destination directory. Optionally descends into a `subdir`. This is the universal "I need git's protocol and git's credential machinery" transport — it works against any Git server, public or private, over any transport Git itself supports (HTTPS, SSH, git://, file://).

        URI shape:

            git:https://github.com/owner/repo.git
            git:git@internal.example.com:org/repo.git
            git:git+ssh://git@host.example.com/repo.git
        :: text ::

        The URL body after `git:` is whatever `git clone` accepts. Revision (`rev`) is passed as `--branch` or resolved post-clone; see the resolver pipeline at [#9].

    3.4 Why only three

        These three correspond to the three credential-and-transport universes a sane implementation should not try to bridge:

        - Filesystem permissions (path).
        - HTTPS request/response with header-based or URL-baked auth (https).
        - Git's protocol and credential machinery (git).

        Anything else — IPFS, S3 native SDK, OCI registries, custom protocols — is either expressible as `https:` (presigned URLs, OCI tarball API) or belongs to a transport universe Lex is not in the business of crossing. New transports are possible but should clear a high bar: a genuinely different network mechanism and a genuinely different credential story.

4. URL Templates

    4.1 The github template

        `github:<owner>/<repo>` is a URL template, not a store. It expands at resolution time into an underlying store URI based on the `via` knob (default: https tarball API):

            github:acme/lex-labels#v1.2
            # via = "https" (default)
            # → https:https://api.github.com/repos/acme/lex-labels/tarball/v1.2

            github:acme/lex-labels#v1.2
            # via = "git"
            # → git:https://github.com/acme/lex-labels.git @ v1.2
        :: text ::

        The template is a pure function: `(owner, repo, ref, via) → underlying-store URI`. It does no network, no caching, no fetching. The fetching is the underlying store's job.

    4.2 The gitlab template

        Identical structure, different forge URL pattern:

            gitlab:foolco/lex-labels#main
            # via = "https" (default)
            # → https:https://gitlab.com/foolco/lex-labels/-/archive/main/lex-labels-main.tar.gz

            gitlab:foolco/lex-labels#main
            # via = "git"
            # → git:https://gitlab.com/foolco/lex-labels.git @ main
        :: text ::

    4.3 The `via` knob

        `via` picks which underlying store a URL template resolves into. Two values are defined:

        - `via = "https"` (default): use the forge's tarball API. Anonymous, fast, no `git` binary required, single HTTP request. Suitable for public repositories and presigned-URL setups.
        - `via = "git"`: use a full git clone. Inherits the user's git credential setup (SSH agent, credential helpers, `gh auth setup-git`, GCM, SAML SSO). Required for private repositories. Heavier — needs `git` in PATH, performs a clone rather than a single GET.

        The default is `https` because the 90% case is "public GitHub repo, no auth required" and the https path is materially cheaper. The `via = "git"` escape hatch is what users reach for when their tap or template URI points at a private repo.

    4.4 Adding new templates

        New templates are added in two ways:

        - *In-tree*: a new URL template is a pure function and a registered scheme name. Bitbucket, Gitea, Codeberg, SourceHut each fit this shape. Adding one is on the order of 20 lines of code plus tests.
        - *Out-of-tree*: out of scope for v1. The template surface is internal to the host; third parties cannot register new templates without modifying the host. If demand for user-defined templates emerges, a registration API is additive.

5. Configuration Surface

    The `lex.toml` `[labels]` block is the only place store configuration lives. Each entry declares which kind of store the namespace uses by which *primary field* it sets, not by parsing scheme strings out of free-form URI values. This makes the configuration self-documenting and makes the parser's job a straightforward enum dispatch.

    The primary fields are mutually exclusive — exactly one must be present per entry:

    - `path = "..."` — filesystem store.
    - `url = "..."` — https tarball store.
    - `git = "..."` — git clone store.
    - `tap = "..."` — github template, tap shorthand (`tap = "acme"` expands to `github:acme/lex-labels`).
    - `github = "owner/repo"` — github template, explicit owner/repo (lets you use a non-`lex-labels` repository name).
    - `gitlab = "owner/repo"` — gitlab template.

    Secondary fields are shared across applicable store kinds:

    - `rev = "..."` — revision (tag, branch, SHA). Applies to git, github, gitlab. Ignored for path and url (which embed revision in the URI itself if at all).
    - `subdir = "..."` — sub-directory within the fetched tree to use as the schema root. Applies to all stores.
    - `via = "https" | "git"` — URL-template transport selection. Applies to github, gitlab. Ignored elsewhere.
    - `header = "..."` — HTTPS header pass-through with `${ENV_VAR}` interpolation. Applies to url, and to github/gitlab when `via = "https"`. Ignored elsewhere.

    The full schema is shown in *Example A* ([#13.1]).

    The denied case `lex = ...` from the parent proposal ([./extending-lex.lex] §4.3) remains denied.

6. Authentication

    The authentication story is per-transport, deliberately delegated outward, and intentionally narrow. Lex does not run a credential ecosystem.

    6.1 Filesystem

        Auth is filesystem permissions. There is no Lex-side knob. If the user can read the directory, the fetch succeeds. If not, it fails with the OS's permission error surfaced as a `FetchError`.

    6.2 HTTPS

        A single optional `header` field accepts an HTTP header line with environment-variable interpolation. This covers Bearer tokens, Basic auth with a PAT, custom `X-API-Key` style headers — anything expressible as one request header.

            [labels.bigorg]
            url    = "https://nexus.example.com/lex-labels-1.2.tar.gz"
            header = "Authorization: Bearer ${BIGORG_TOKEN}"
        :: toml ::

        Secrets *must never* appear literally in `lex.toml`. The `${VAR}` interpolation is the only sanctioned mechanism for getting a secret into a request. A future credentials-file pattern modelled on Cargo's `~/.cargo/credentials.toml` is additive and out of scope for v1.

        Presigned URLs (S3, GCS, Azure SAS) embed signed credentials in the URL itself and need no `header` field at all. They are the strongest "private storage, zero Lex auth code" pattern available and should be the recommended path for self-hosted enterprise setups.

    6.3 Git

        The git store inherits the user's existing git credential setup entirely. There is no Lex-side knob, no `header` field, no environment variable. SSH agent, OS keychain credential helpers (osxkeychain, libsecret, GCM, GCMcore), `gh auth setup-git`, `gitconfig`-declared SSO providers — whatever `git clone` would honor at the command line, the git store honors. This is why the implementation shells out to the `git` binary rather than using libgit2: libgit2's credential coverage is incomplete in ways that matter (macOS keychain integration, SAML SSO, Kerberos), and the consequence is a UX divide between "private repos that work" and "private repos that don't" with no clear story for the user. Shell-out trades startup cost (10-50ms per fetch) for working auth everywhere git already works.

        The cost: `git` must be in PATH. This is an acceptable constraint; users invoking the git store are by definition already in a git-using environment.

    6.4 Out of scope

        - mTLS, AWS SigV4, OIDC code-exchange flows, Kerberos for HTTPS endpoints. Users needing these can put a reverse proxy in front that strips their custom auth and serves a tarball at a stable URL.
        - Credential helper protocols for HTTPS (Docker-style `credsStore`, npm-style `_authToken`). Additive; out of scope for v1.
        - Per-document auth overrides. Trust anchor concerns; see [#7].

7. The Trust Anchor Principle

    Store configuration lives in `lex.toml` and nowhere else. A document cannot redirect where a namespace's schemas — and therefore its handler code — come from. This asymmetry is load-bearing for the trust model, not a stylistic preference.

    The reason: a namespace's URI determines what *code* runs when its labels are invoked. A schema declares which capabilities a handler claims (fs, net); the host's sandbox enforces those claims; but the schema *itself* arrives from the URI. Redirecting the URI redirects the schema, which redirects the capability declaration, which redirects what the handler is allowed to do. The trust anchor must be one level up from anything user-content can touch.

    The threat scenarios are concrete:

    - *External contributions to OSS projects.* A drive-by PR adds a `.lex` file containing `:: acme.commenting source="github:attacker/lex-labels" ... ::`. Reviewers eyeball the editorial content, miss the source override; once merged, anyone running `lexd convert` pulls handler code from the attacker. Reviewer attention is asymmetric — a `Cargo.toml` dep change gets eyeballs, a long-form inline param does not.
    - *Multi-tenant publishing platforms.* A docs site ingests `.lex` from many authors. The operator owns `lex.toml`; authors own their documents. Without the asymmetry, any author could redirect handler sourcing for the platform's render pipeline.
    - *CI runners processing customer content.* A pipeline renders customer `.lex` to PDF/HTML. Customer documents should not inject arbitrary code-fetch URIs into the runner.
    - *Issue attachments and bug-report repros.* "Here's a `.lex` that reproduces the bug." If opening the file could redirect handler sourcing, the bug report itself is the attack.
    - *Snippets pasted from documentation forums.* Copy-paste from Stack Overflow into your repo should not get to override your project's namespace bindings.
    - *Editors opening unknown files.* A desktop editor (lexed, VS Code, Neovim with the lex plugin) opens any `.lex` you double-click. The user's intent is "view this document," not "execute handler code from a URI embedded in it."

    The structural pattern across all of these: a **role separation** between the party responsible for the environment (`lex.toml`, committed/operator-controlled) and the party writing content (`.lex`, author-controlled). Whenever those roles are distinct people or distinct review processes — which is essentially everywhere except solo-dev-on-personal-project — the asymmetry is doing real work.

    The trust-prompt model from the parent proposal ([./extending-lex.lex] §8) depends on this. "Prompt + pin" only coheres if a namespace's URI is stable per-workspace. If documents could rebind it, the pin is meaningless: every document could shift the binding under the user, defeating the prompt. The trust UI is sane only because `lex.toml` is the single source of "what URI does `acme` mean here."

    Future invocation-param defaults in `lex.toml` (the §10.5 follow-up) remain safe under this principle: invocation params cannot redirect code sourcing no matter where they are declared. The principle gates *what* the data line can express, not *how many* layers of defaults are merged before reaching it.

8. Caching

    The content-hashed cache from the parent proposal ([./extending-lex.lex] §4.4) remains unchanged in shape. The only refinement: cache keys are computed against the *resolved* URI, not the user-facing form. A URL template that produces a different underlying URI (e.g., flipping `via = "https"` to `via = "git"`) produces a different cache entry. The cache is store-agnostic — it works against any `Fetcher` impl uniformly, including the existing `path:` fetcher and a hypothetical user-defined one.

    Cache directory layout: `~/.cache/lex/labels/<sha256-of-resolved-uri>/`. Mutable revisions (branches, `HEAD`, no rev) have a 24h TTL; immutable revisions (tags, SHAs) cache indefinitely. The fetcher reports immutability via `is_immutable_rev`; the cache layer uses it directly.

9. Resolver Pipeline

    The full pipeline from a `lex.toml [labels]` entry to a usable schema directory:

    1. *Config parse.* The TOML parser reads `[labels.<name>]` and produces a `NamespaceSpec` typed by the primary-field discriminant (path / url / git / tap / github / gitlab).
    2. *Template expansion.* For tap / github / gitlab entries, the corresponding URL template runs and produces an underlying-store URI (https or git). Path / url / git entries pass through unchanged.
    3. *Cache lookup.* The resolved URI is content-hashed; the cache is consulted. On hit (within TTL or immutable rev), the cached schema directory is returned and the pipeline exits.
    4. *Fetch.* On miss, the appropriate `Fetcher` (selected by scheme of the resolved URI) is invoked with the URI and a fresh empty cache directory. The fetcher populates the directory.
    5. *Subdir descent.* If `subdir` is set, the cache layer scopes the schema-root to that path within the fetched tree.
    6. *Schema load.* The directory is handed to the schema loader (parent proposal §5.2), which scans `*.yaml` / `*.yml` and registers each schema with the namespace.

    The pipeline is the same across all stores. The variability is entirely encapsulated in the per-`Fetcher` `fetch()` method and in the per-template expansion function.

10. Migration from the Stub Model

    The current implementation registers four `Fetcher` stubs — `GithubFetcher`, `GitlabFetcher`, `HttpsFetcher`, `GitSshFetcher` — each returning `FetchError::Unimplemented`. This spec retires that factoring:

    - Of those four, only `HttpsFetcher` survives as a real fetcher under the new model (`https:` transport).
    - `GitSshFetcher` is subsumed into a new `GitFetcher` that accepts any git-clone-compatible URL form, not just `git+ssh://`.
    - `GithubFetcher` and `GitlabFetcher` become URL templates (`github_template`, `gitlab_template`), not fetchers. They have no `Fetcher` impl and do no I/O.
    - A new `GitFetcher` joins the existing `PathFetcher` and the surviving `HttpsFetcher`. Total: three real fetchers.

    The user-visible URI scheme `git+ssh:` is retained as a parseable form (it remains useful in error messages and in older configs) but is canonicalised to `git:git+ssh://...` internally before dispatch.

    The tracking issue for actual network code (lex#562) is rescoped from "implement four fetchers" to "implement two fetchers + two templates," reducing surface area.

11. Out of Scope

    11.1 Private-repo HTTPS auth beyond simple headers

        See [#6.4]. mTLS, SigV4, OIDC, Kerberos — all out. Users with these constraints either run a reverse proxy that translates to a simple authenticated tarball URL, or use the git store (which inherits whatever git knows).

    11.2 Mirror / fallback URIs

        A namespace cannot declare multiple sources for HA. If a primary store is down, the fetch fails. Mirrors are a real feature for high-availability infrastructure deployments and are additive; out of scope for v1.

    11.3 Per-document store overrides

        Covered by the trust-anchor principle ([#7]) and the parent proposal's §10.5. Cannot be added without compromising the trust model.

    11.4 Custom (out-of-tree) URL templates

        Adding `bitbucket`, `gitea`, `codeberg`, `sourcehut` is in-tree work. User-defined templates require an extension-of-the-extension-system surface and are out of scope.

    11.5 Credentials file

        A separate `~/.config/lex/credentials.toml` (modelled on Cargo) for secrets is additive; `${VAR}` interpolation covers the v1 case adequately.

12. Future Extensions

    Directions left open without commitment:

    - *Additional URL templates*: bitbucket, gitea, codeberg, sourcehut, etc. Each is a pure function; adding one does not change the resolver pipeline or the fetcher set.
    - *Credentials file*: `~/.config/lex/credentials.toml` for env-var-free secret storage. Cargo precedent.
    - *Mirror / fallback URIs*: declare a list of sources per namespace, try in order on failure.
    - *Per-store cache TTL override*: a namespace owner could declare "this namespace's branches are stable enough that the default 24h TTL is too aggressive (or not aggressive enough)".
    - *Out-of-tree custom templates*: a registration API for user-defined `<scheme>:` templates.

    None require breaking changes to the surface defined here.

13. Examples

    Every example below is a complete, copy-pasteable `lex.toml` `[labels]` entry plus a description of what it produces at resolution time.

    13.1 Example A — The full configuration surface

        Every field in one place, with comments naming each role:

            [labels]
            # Tap shorthand → github template, default `via = "https"`
            acme = { tap = "acme" }

            # Github template, explicit owner/repo, pinned to a tag
            cern = { github = "cern/lex-schemas", rev = "v2.1.0" }

            # Gitlab template, explicit subdir, default `via`
            foolco = { gitlab = "foolco/docs", subdir = "lex-labels" }

            # HTTPS tarball with bearer-token auth
            legal = { url = "https://nexus.example.com/legal-1.2.tar.gz", header = "Authorization: Bearer ${LEGAL_TOKEN}" }

            # Local development path
            local = { path = "../shared/labels" }

            # Private github, forced to git transport for auth
            [labels.bigorg]
            tap = "bigorg"
            via = "git"

            # Self-hosted git+ssh, table form
            [labels.internal]
            git    = "git@internal.example.com:docs/lex-labels.git"
            rev    = "v3.4.0"
            subdir = "labels"
        :: toml ::

    13.2 Example B — Tap, the 90% case

        The terse default:

            [labels]
            acme = { tap = "acme" }
        :: toml ::

        Resolves to: `github:acme/lex-labels` → `https://api.github.com/repos/acme/lex-labels/tarball/HEAD`. Anonymous HTTPS GET, tar extraction, cached for 24h (mutable rev). The single most common pattern in the ecosystem.

    13.3 Example C — Private github, via git for auth

        When the underlying repo is private:

            [labels.bigorg]
            tap = "bigorg"
            via = "git"
        :: toml ::

        Resolves to: `git:https://github.com/bigorg/lex-labels.git`. Shells out to `git clone --depth=1`, which inherits the user's git credentials (SSH agent, gh CLI's git config, OS keychain helper). No Lex-side credential code involved.

    13.4 Example D — HTTPS tarball with auth

        Self-hosted artifact server:

            [labels.legal]
            url    = "https://nexus.example.com/repo/lex-labels-1.2.tar.gz"
            header = "Authorization: Bearer ${LEGAL_TOKEN}"
        :: toml ::

        Single HTTPS GET with the configured header; `${LEGAL_TOKEN}` is interpolated from the process environment at resolution time. Secret never appears in `lex.toml`.

    13.5 Example E — Presigned URL, zero auth code

        S3-presigned URL, time-bounded:

            [labels.draft]
            url = "https://my-bucket.s3.amazonaws.com/lex-labels-snapshot.tar.gz?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Signature=..."
        :: toml ::

        No `header`, no env vars — auth is baked into the URL by `aws s3 presign`. The cleanest "private storage with enterprise-grade auth and zero Lex auth code" pattern.

    13.6 Example F — Local development

        Pointing at an in-progress schema directory next to the workspace:

            [labels.draft]
            path = "../shared/labels"
        :: toml ::

        Resolves to: `path:../shared/labels`. Direct filesystem read, no cache TTL relevant. Useful for namespace authors iterating on schemas before publishing.
