---
name: track-agw-oss-pr
description: Track an AgentGateway OSS PR through enterprise syncs and releases. Use when asked "is agentgateway PR X in enterprise?", "did agentgateway PR X make it to release Y?", or "track agentgateway PR".
argument-hint: <oss-pr-number> [ent-release-tag]
---

# Track AgentGateway OSS PR

Run the tracking script and present results to the user.

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
