---
name: track-agw-oss-pr
description: Track an AgentGateway OSS PR through enterprise syncs and releases. Use when asked "is agentgateway PR X in enterprise?", "did agentgateway PR X make it to release Y?", or "track agentgateway PR".
argument-hint: <oss-pr-number> [ent-release-tag]
---

# Track AgentGateway OSS PR

## Problem

When a bug fix or feature is merged in the open-source AgentGateway repo, customers ask "is this fix in my version?" There's no simple way to answer that because:

1. OSS changes don't go directly into enterprise releases
2. They first get synced to an internal branch (`solo-main`) via sync PRs
3. Releases are cut from separate release branches (`v2.3.x`, `v2.4.x`)
4. A fix being on `solo-main` doesn't mean it's in a release

Tracing this manually requires 5+ GitHub API calls and understanding the branch model.

## How the skill works

You give it an OSS PR number, and it traces the full journey:

- **Step 1** — Gets the PR's merge commit SHA from OSS `main`
- **Step 2** — Checks which OSS releases include it
- **Step 3** — Finds which enterprise sync PR picked it up (by comparing OSS commit positions)
- **Step 4** — Checks enterprise release branches to determine which shipped versions include it

## Steps

1. Parse the arguments from `$ARGUMENTS`:
   - First argument: OSS PR number (required)
   - Second argument: ENT release tag (optional, e.g., `v2.4.0-beta.0`)

2. Determine the script path. The script is bundled with this skill:

```bash
SCRIPT_DIR="$(dirname "$(readlink -f "$0")" 2>/dev/null || echo "$HOME/.claude/skills/track-agw-oss-pr")"
```

3. Run the shell script:

```bash
$HOME/.claude/skills/track-agw-oss-pr/track-agw-oss-pr.sh <pr-number> [release-tag]
```

4. Present the output to the user. If the output shows the PR is not yet in a release, mention that it will land in the next release cut from `solo-main`.

5. If the user seems confused about the results, explain the chain:
   - **OSS Issue** → fixed by an **OSS PR**
   - The PR creates a **merge commit** on OSS `main` when merged
   - An enterprise **sync PR** merges OSS `main` up to a certain point into ENT `solo-main`
   - Releases are cut from **release branches** (e.g., `v2.3.x`), not directly from `solo-main`
   - A PR being on `solo-main` does NOT mean it's in a release — it must be on the release branch

## Notes

- This skill is specific to AgentGateway. Other Solo.io products (kgateway, istio, etc.) have different OSS-to-enterprise sync mechanisms.
- OSS repo: `agentgateway/agentgateway`
- ENT repo: `solo-io/agentgateway-enterprise`
- Requires `gh` CLI authenticated with access to both repos.
