# Security Policy

## Supported versions

Security fixes are applied to the latest release and the current `main` branch.
Private prototype versions are not supported.

## Reporting a vulnerability

Please do not open a public issue for a vulnerability that could expose local
files, execute code unexpectedly, bypass macOS protections, or affect the AU
host.

Use GitHub's private vulnerability reporting or a private security advisory
when available. Include:

- macOS, Logic Pro and Xcode versions.
- Exact reproduction steps using non-confidential media.
- Expected and observed behavior.
- Whether the issue affects the standalone app, AUv3, or both.

Do not attach customer media, commercial Logic projects, credentials, personal
paths or other sensitive files.

## Binary trust

The project currently provides source code only. Builds created by forks or
third parties are not official releases. Inspect the source and build locally,
or verify the signer and notarization status before running a downloaded
binary.

## Privacy model

Logic Video Cue does not include network access, analytics or telemetry.
`.lvcue` documents contain absolute local media paths, which can reveal
usernames or project names if shared publicly.
