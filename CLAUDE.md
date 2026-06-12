<!-- BEGIN release-managed orientation — managed by release-sync; do not edit -->
This repo's quality gate, build, release, and PR/dev flow are provided by
`release-core` (installed at session start; not stored in this repo).

- **Start here:** run `release-core how-to` — the task playbook for *this* repo
  (its dev cycle, incl. coordinating a complex / multi-PR feature with subagents).
- Reference: `release-core --help`, `release-core <cmd> --help`, `release-core detect-kind`.
- Quality gate (run every loop, after `git add`): `release-core gate`.
<!-- END release-managed orientation -->

## Releasing

This repo is the source of the lex release cascade. Cutting a release here propagates automatically to all downstream lex-fmt repos via `repository_dispatch` (`on-upstream-released` handler workflows).

To cut a release: push an annotated tag (`git tag -a vX.Y.Z -m "..." && git push origin vX.Y.Z`). The cascade handles the rest.

Design + ops + gotchas: [arthur-debert/release/docs/lex-release-cascade.md](https://github.com/arthur-debert/release/blob/main/docs/lex-release-cascade.md).
