---
name: track-agw-oss-pr
description: Track an AgentGateway PR (OSS or ENT) through enterprise syncs and releases. Use when asked "is agentgateway PR X in enterprise?", "did agentgateway PR X make it to release Y?", "is ENT PR X in v2.3.0?", or "track agentgateway PR".
argument-hint: [--ent] <pr-number> [release-tag]
---

# Track AgentGateway PR

## Problem

When a bug fix or feature is merged in AgentGateway (OSS or enterprise), customers ask "is this fix in my version?" There's no simple way to answer that because:

1. OSS changes don't go directly into enterprise releases — they first get synced to `solo-main` via sync PRs
2. Enterprise PRs merge to `solo-main` but releases are cut from separate release branches (`v2.3.x`, `v2.4.x`)
3. A fix being on `solo-main` doesn't mean it's in a release — it must be on the release branch

Tracing this manually requires multiple GitHub API calls and understanding the branch model.

## Two modes

### OSS PR mode (default)

Traces an OSS PR through: OSS releases → enterprise sync → enterprise releases.

### ENT PR mode (`--ent`)

Traces an enterprise PR directly against enterprise release tags. Simpler — no sync step needed since the PR is already in the ENT repo.

## Steps

1. Parse the arguments from `$ARGUMENTS`:
   - `--ent` flag (optional): treat the PR number as an enterprise PR
   - First positional argument: PR number (required)
   - Second positional argument: release tag (optional, e.g., `v2.4.0-beta.0`)

2. Run the shell script:

```bash
# OSS PR
$HOME/.claude/skills/track-agw-oss-pr/track-agw-oss-pr.sh <pr-number> [release-tag]

# ENT PR
$HOME/.claude/skills/track-agw-oss-pr/track-agw-oss-pr.sh --ent <pr-number> [release-tag]
```

3. Present the output to the user. If the output shows the PR is not yet in a release, mention that it will land in the next release cut from `solo-main`.

4. If the user seems confused about the results, explain the chain:
   - For **OSS PRs**: OSS Issue → OSS PR → merge commit on OSS `main` → enterprise sync PR → release branch → release
   - For **ENT PRs**: ENT PR → merge commit on `solo-main` (or release branch) → release
   - In both cases: releases are cut from **release branches** (e.g., `v2.3.x`), not directly from `solo-main`

## Notes

- This skill is specific to AgentGateway. Other Solo.io products (kgateway, istio, etc.) have different sync mechanisms.
- OSS repo: `agentgateway/agentgateway`
- ENT repo: `solo-io/agentgateway-enterprise`
- Requires `gh` CLI authenticated with access to both repos.
