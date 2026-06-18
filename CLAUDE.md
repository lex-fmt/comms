@.claude/IMPORTANT-RELEASE.md

## Releasing

This repo is the source of the lex release cascade. Cutting a release here propagates automatically to all downstream lex-fmt repos via `repository_dispatch` (`on-upstream-released` handler workflows).

To cut a release: push an annotated tag (`git tag -a vX.Y.Z -m "..." && git push origin vX.Y.Z`). The cascade handles the rest.

Design + ops + gotchas: [arthur-debert/release/docs/lex-release-cascade.md](https://github.com/arthur-debert/release/blob/main/docs/lex-release-cascade.md).
