# track-agw-oss-pr

A Claude Code skill that tracks AgentGateway OSS pull requests through the enterprise sync pipeline and into releases.

## Problem

When an OSS AgentGateway PR is merged (bug fix, feature, etc.), there's no simple way to know if it's in a specific enterprise release. The path from OSS to enterprise involves:

1. PR merges to OSS `main`
2. A sync PR merges OSS `main` into enterprise `solo-main`
3. Releases are cut from separate release branches (`v2.3.x`, `v2.4.x`)

This skill automates the full trace with a single command.

## Install

```bash
npx skills add https://github.com/sadieleob/claude-skills --skill track-agw-oss-pr
```

## Usage

### From Claude Code

```
/track-agw-oss-pr 1540
/track-agw-oss-pr 1540 v2.3.2
```

### From the terminal (standalone)

```bash
~/.claude/skills/track-agw-oss-pr/track-agw-oss-pr.sh 1540
~/.claude/skills/track-agw-oss-pr/track-agw-oss-pr.sh 1540 v2.3.2
```

## Output

```
=== OSS PR #1540 ===
Title:        feat(llm): Add gemini provider support for Open Responses
Merge commit: 2d19cdce1a (2d19cdce1a3746dfe1f589dfd6c77958ed8b123d)
Merged:       2026-04-15
Fixes:        #1286

=== OSS Release Check ===
v1.1.0 (2026-04-09): NOT included (35 commits ahead)

=== Sync to solo-main ===
First sync: ENT PR #707 — "Sync upstream OSS (38049a155)" (2026-04-16)
Skipped by:  #673 (00b55fd77), #687 (36322ac79), #704 (76970c0f3)

=== ENT Release Check ===
v2.3.2 (2026-04-17): NOT included (v2.3.x branch synced OSS up to 4d04dea, before this PR)
v2.4.0-beta.0 (2026-04-14): NOT included (sync merged after release)
```

## Prerequisites

- `gh` CLI authenticated with access to:
  - `agentgateway/agentgateway` (OSS)
  - `solo-io/agentgateway-enterprise` (ENT)
- `jq`

## How it works

The script uses the GitHub Compare API (`repos/{owner}/{repo}/compare/{base}...{head}`) to determine commit ordering:

1. Gets the OSS PR's merge commit SHA
2. Compares it against OSS release tags
3. Compares it against each enterprise sync PR's OSS SHA to find which sync picked it up
4. Checks enterprise release branches to determine which releases include the sync

See the companion doc [oss-to-enterprise-sync.md](https://github.com/sadieleob/claude-skills/blob/main/track-agw-oss-pr/oss-to-enterprise-sync.md) for a deep dive on the sync mechanism.

## Limitations

- Specific to AgentGateway (other Solo.io products have different sync mechanisms)
- Checks the last 30 sync PRs
- Requires read access to the enterprise repo
