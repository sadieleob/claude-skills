# track-agw-oss-pr

A Claude Code skill that tracks AgentGateway pull requests (OSS or enterprise) through the enterprise sync pipeline and into releases.

## Problem

When a bug fix or feature is merged in AgentGateway, there's no simple way to know if it's in a specific enterprise release. The path differs depending on where the PR was merged:

**OSS PRs** go through three steps:
1. PR merges to OSS `main`
2. A sync PR merges OSS `main` into enterprise `solo-main`
3. Releases are cut from separate release branches (`v2.3.x`, `v2.4.x`)

**ENT PRs** are simpler but still not obvious:
1. PR merges to `solo-main` (or a release branch)
2. Releases are cut from release branches, not `solo-main` directly

This skill automates the full trace with a single command.

## Install

```bash
npx skills add https://github.com/sadieleob/claude-skills --skill track-agw-oss-pr
```

## Usage

### From Claude Code

```
/track-agw-oss-pr 1540                    # track OSS PR
/track-agw-oss-pr 1540 v2.3.2             # track OSS PR, check specific release
/track-agw-oss-pr --ent 478               # track ENT PR
/track-agw-oss-pr --ent 478 v2.3.0        # track ENT PR, check specific release
```

### From the terminal (standalone)

```bash
./track-agw-oss-pr.sh 1540                # track OSS PR
./track-agw-oss-pr.sh 1540 v2.3.2         # track OSS PR, check specific release
./track-agw-oss-pr.sh --ent 478           # track ENT PR
./track-agw-oss-pr.sh --ent 478 v2.3.0    # track ENT PR, check specific release
```

## Example output

### OSS PR

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

### ENT PR

```
=== ENT PR #478 ===
Title:        feat: add CEL authorization for tools
Merge commit: 9e2d6a9abc (9e2d6a9abc...)
Merged:       2026-03-10
Base branch:  solo-main

=== ENT Release Check ===
v2.3.2 (2026-04-17): INCLUDED
v2.3.0 (2026-04-09): INCLUDED
v2.3.0-beta.8 (2026-03-31): INCLUDED
```

## Prerequisites

- `gh` CLI authenticated with access to:
  - `agentgateway/agentgateway` (OSS)
  - `solo-io/agentgateway-enterprise` (ENT)
- `jq`

## How it works

The script uses the GitHub Compare API (`repos/{owner}/{repo}/compare/{base}...{head}`) to determine commit ordering:

- `status: "behind"` — the commit came before the tag — **INCLUDED** in that release
- `status: "ahead"` — the commit came after the tag — **NOT included**

### OSS PR flow

1. Gets the OSS PR's merge commit SHA
2. Compares it against OSS release tags
3. Compares it against each enterprise sync PR's OSS SHA to find which sync picked it up
4. Checks enterprise release branches to determine which releases include the sync

### ENT PR flow

1. Gets the ENT PR's merge commit SHA
2. Compares it directly against enterprise release tags (no sync step needed)

## Limitations

- Specific to AgentGateway (other Solo.io products have different sync mechanisms)
- Checks the last 30 sync PRs for OSS mode
- Requires read access to the enterprise repo
