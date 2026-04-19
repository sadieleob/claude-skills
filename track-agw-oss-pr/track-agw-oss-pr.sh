#!/usr/bin/env bash
set -euo pipefail

OSS_REPO="agentgateway/agentgateway"
ENT_REPO="solo-io/agentgateway-enterprise"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

usage() {
  echo "Usage: $(basename "$0") [--ent] <pr-number> [release-tag]"
  echo ""
  echo "Examples:"
  echo "  $(basename "$0") 1540                  # track OSS PR (full scan)"
  echo "  $(basename "$0") 1540 v2.4.0-beta.0    # track OSS PR, check specific ENT release"
  echo "  $(basename "$0") --ent 478             # track ENT PR (full scan)"
  echo "  $(basename "$0") --ent 478 v2.3.0      # track ENT PR, check specific release"
  exit 1
}

# --- Parse arguments ---
IS_ENT=false
if [[ "${1:-}" == "--ent" ]]; then
  IS_ENT=true
  shift
fi

[[ $# -lt 1 ]] && usage
PR_NUM="$1"
RELEASE_TAG="${2:-}"

# --- ENT PR mode ---
if [[ "$IS_ENT" == true ]]; then
  echo -e "\n${BOLD}=== ENT PR #${PR_NUM} ===${RESET}"

  PR_JSON=$(gh pr view "$PR_NUM" --repo "$ENT_REPO" --json title,mergeCommit,mergedAt,body,state,baseRefName 2>&1) || {
    echo -e "${RED}Error: could not fetch ENT PR #${PR_NUM}${RESET}"
    exit 1
  }

  PR_STATE=$(echo "$PR_JSON" | jq -r '.state')
  if [[ "$PR_STATE" != "MERGED" ]]; then
    echo -e "${RED}PR #${PR_NUM} is not merged (state: ${PR_STATE})${RESET}"
    exit 1
  fi

  PR_TITLE=$(echo "$PR_JSON" | jq -r '.title')
  PR_SHA=$(echo "$PR_JSON" | jq -r '.mergeCommit.oid')
  PR_SHA_SHORT="${PR_SHA:0:10}"
  PR_MERGED=$(echo "$PR_JSON" | jq -r '.mergedAt[:10]')
  PR_BASE=$(echo "$PR_JSON" | jq -r '.baseRefName')
  PR_FIXES=$(echo "$PR_JSON" | jq -r '.body' | grep -oP '(?i)fixes\s+#?\K\d+|fixes\s+https://github\.com/[^/]+/[^/]+/issues/\K\d+' | head -1 || true)

  echo -e "Title:        ${PR_TITLE}"
  echo -e "Merge commit: ${CYAN}${PR_SHA_SHORT}${RESET} (${PR_SHA})"
  echo -e "Merged:       ${PR_MERGED}"
  echo -e "Base branch:  ${PR_BASE}"
  [[ -n "$PR_FIXES" ]] && echo -e "Fixes:        #${PR_FIXES}"

  # --- Check ENT releases ---
  echo -e "\n${BOLD}=== ENT Release Check ===${RESET}"

  check_ent_release_direct() {
    local tag="$1"
    local tag_date
    tag_date=$(gh release view "$tag" --repo "$ENT_REPO" --json publishedAt --jq '.publishedAt[:10]' 2>/dev/null || echo "unknown")

    local result
    result=$(gh api "repos/${ENT_REPO}/compare/${tag}...${PR_SHA}" --jq '.status' 2>/dev/null || echo "error")

    if [[ "$result" == "behind" || "$result" == "identical" ]]; then
      echo -e "${GREEN}${tag}${RESET} (${tag_date}): INCLUDED"
    elif [[ "$result" == "ahead" ]]; then
      local ahead
      ahead=$(gh api "repos/${ENT_REPO}/compare/${tag}...${PR_SHA}" --jq '.ahead_by' 2>/dev/null)
      echo -e "${RED}${tag}${RESET} (${tag_date}): NOT included (${ahead} commits ahead)"
    elif [[ "$result" == "diverged" ]]; then
      local branch
      branch=$(gh api "repos/${ENT_REPO}/commits/${tag}/branches-where-head" --jq '.[0].name' 2>/dev/null || true)

      if [[ -z "$branch" || "$branch" == "null" ]]; then
        local major_minor
        major_minor=$(echo "$tag" | grep -oP 'v\d+\.\d+' || true)
        if [[ -n "$major_minor" ]]; then
          local candidate="${major_minor}.x"
          local branch_exists
          branch_exists=$(gh api "repos/${ENT_REPO}/branches/${candidate}" --jq '.name' 2>/dev/null || true)
          [[ -n "$branch_exists" && "$branch_exists" != "null" ]] && branch="$candidate"
        fi
      fi

      if [[ -n "$branch" && "$branch" != "null" ]]; then
        local branch_result
        branch_result=$(gh api "repos/${ENT_REPO}/compare/${branch}...${PR_SHA}" --jq '.status' 2>/dev/null || echo "error")
        if [[ "$branch_result" == "behind" || "$branch_result" == "identical" ]]; then
          echo -e "${GREEN}${tag}${RESET} (${tag_date}): INCLUDED (PR merged to ${PR_BASE}, reachable from ${branch})"
        else
          echo -e "${RED}${tag}${RESET} (${tag_date}): NOT included (PR on ${PR_BASE}, not reachable from ${branch})"
        fi
      else
        echo -e "${RED}${tag}${RESET} (${tag_date}): NOT included (diverged, could not determine release branch)"
      fi
    else
      echo -e "${YELLOW}${tag}${RESET} (${tag_date}): could not compare (${result})"
    fi
  }

  if [[ -n "$RELEASE_TAG" ]]; then
    check_ent_release_direct "$RELEASE_TAG"
  else
    ENT_RELEASES=$(gh release list --repo "$ENT_REPO" --limit 10 --json tagName --jq '.[].tagName')
    while read -r tag; do
      [[ -z "$tag" ]] && continue
      check_ent_release_direct "$tag"
    done <<< "$ENT_RELEASES"
  fi

  echo ""
  exit 0
fi

# --- OSS PR mode (original flow) ---
echo -e "\n${BOLD}=== OSS PR #${PR_NUM} ===${RESET}"

PR_JSON=$(gh pr view "$PR_NUM" --repo "$OSS_REPO" --json title,mergeCommit,mergedAt,body,state 2>&1) || {
  echo -e "${RED}Error: could not fetch OSS PR #${PR_NUM}${RESET}"
  exit 1
}

PR_STATE=$(echo "$PR_JSON" | jq -r '.state')
if [[ "$PR_STATE" != "MERGED" ]]; then
  echo -e "${RED}PR #${PR_NUM} is not merged (state: ${PR_STATE})${RESET}"
  exit 1
fi

PR_TITLE=$(echo "$PR_JSON" | jq -r '.title')
PR_SHA=$(echo "$PR_JSON" | jq -r '.mergeCommit.oid')
PR_SHA_SHORT="${PR_SHA:0:10}"
PR_MERGED=$(echo "$PR_JSON" | jq -r '.mergedAt[:10]')
PR_FIXES=$(echo "$PR_JSON" | jq -r '.body' | grep -oP '(?i)fixes\s+#?\K\d+|fixes\s+https://github\.com/[^/]+/[^/]+/issues/\K\d+' | head -1 || true)

echo -e "Title:        ${PR_TITLE}"
echo -e "Merge commit: ${CYAN}${PR_SHA_SHORT}${RESET} (${PR_SHA})"
echo -e "Merged:       ${PR_MERGED}"
[[ -n "$PR_FIXES" ]] && echo -e "Fixes:        #${PR_FIXES}"

# --- Check against OSS release tags ---
echo -e "\n${BOLD}=== OSS Release Check ===${RESET}"

OSS_RELEASES=$(gh release list --repo "$OSS_REPO" --limit 10 --json tagName,publishedAt \
  --jq '.[] | "\(.tagName) \(.publishedAt[:10])"')

while read -r tag date; do
  [[ -z "$tag" ]] && continue
  result=$(gh api "repos/${OSS_REPO}/compare/${tag}...${PR_SHA}" --jq '.status' 2>/dev/null || echo "error")
  if [[ "$result" == "behind" || "$result" == "identical" ]]; then
    echo -e "${GREEN}${tag}${RESET} (${date}): INCLUDED"
  elif [[ "$result" == "ahead" ]]; then
    ahead=$(gh api "repos/${OSS_REPO}/compare/${tag}...${PR_SHA}" --jq '.ahead_by' 2>/dev/null)
    echo -e "${RED}${tag}${RESET} (${date}): NOT included (${ahead} commits ahead)"
  else
    echo -e "${YELLOW}${tag}${RESET} (${date}): could not compare"
  fi
done <<< "$OSS_RELEASES"

# --- Find ENT sync PRs that include this commit ---
echo -e "\n${BOLD}=== Sync to solo-main ===${RESET}"

SYNC_PRS=$(gh pr list --repo "$ENT_REPO" --search "sync upstream in:title" --state merged --limit 30 \
  --json number,title,mergedAt \
  --jq 'sort_by(.mergedAt) | .[] | "\(.number) \(.mergedAt[:10]) \(.title)"')

FIRST_SYNC=""
FIRST_SYNC_NUM=""
SKIPPED=()

while read -r num date title; do
  [[ -z "$num" ]] && continue
  sync_sha=$(echo "$title" | grep -oP '\(([a-f0-9]+)\)' | tr -d '()' || true)
  [[ -z "$sync_sha" ]] && continue

  result=$(gh api "repos/${OSS_REPO}/compare/${PR_SHA}...${sync_sha}" --jq '.status' 2>/dev/null || echo "error")

  if [[ "$result" == "ahead" || "$result" == "identical" ]]; then
    if [[ -z "$FIRST_SYNC" ]]; then
      FIRST_SYNC="ENT PR #${num} — \"${title}\" (${date})"
      FIRST_SYNC_NUM="$num"
    fi
  elif [[ "$result" == "behind" ]]; then
    SKIPPED+=("#${num} (${sync_sha})")
  fi
done <<< "$SYNC_PRS"

SYNC_MERGE_SHA=""
if [[ -n "$FIRST_SYNC" ]]; then
  echo -e "${GREEN}First sync: ${FIRST_SYNC}${RESET}"
  if [[ ${#SKIPPED[@]} -gt 0 ]]; then
    echo -e "Skipped by:  $(IFS=', '; echo "${SKIPPED[*]}")"
  fi

  SYNC_MERGE_SHA=$(gh pr view "$FIRST_SYNC_NUM" --repo "$ENT_REPO" --json mergeCommit --jq '.mergeCommit.oid' 2>/dev/null || true)
else
  echo -e "${RED}Not yet synced to solo-main${RESET}"
  echo -e "Latest sync PRs checked but none include this commit."
  [[ -z "$RELEASE_TAG" ]] && exit 0
fi

# --- Check ENT releases ---
echo -e "\n${BOLD}=== ENT Release Check ===${RESET}"

check_ent_release() {
  local tag="$1"
  local tag_date
  tag_date=$(gh release view "$tag" --repo "$ENT_REPO" --json publishedAt --jq '.publishedAt[:10]' 2>/dev/null || echo "unknown")

  if [[ -z "$SYNC_MERGE_SHA" ]]; then
    echo -e "${YELLOW}${tag}${RESET} (${tag_date}): cannot check (no sync merge SHA)"
    return
  fi

  local result
  result=$(gh api "repos/${ENT_REPO}/compare/${tag}...${SYNC_MERGE_SHA}" --jq '.status' 2>/dev/null || echo "error")

  if [[ "$result" == "behind" || "$result" == "identical" ]]; then
    echo -e "${GREEN}${tag}${RESET} (${tag_date}): INCLUDED"
  elif [[ "$result" == "ahead" ]]; then
    echo -e "${RED}${tag}${RESET} (${tag_date}): NOT included (sync merged after release)"
  elif [[ "$result" == "diverged" ]]; then
    local branch
    branch=$(gh api "repos/${ENT_REPO}/commits/${tag}/branches-where-head" --jq '.[0].name' 2>/dev/null || true)

    if [[ -z "$branch" || "$branch" == "null" ]]; then
      local major_minor
      major_minor=$(echo "$tag" | grep -oP 'v\d+\.\d+' || true)
      if [[ -n "$major_minor" ]]; then
        local candidate="${major_minor}.x"
        local branch_exists
        branch_exists=$(gh api "repos/${ENT_REPO}/branches/${candidate}" --jq '.name' 2>/dev/null || true)
        [[ -n "$branch_exists" && "$branch_exists" != "null" ]] && branch="$candidate"
      fi
    fi

    if [[ -n "$branch" && "$branch" != "null" && "$branch" != "solo-main" ]]; then
      local last_sync_oss_sha
      last_sync_oss_sha=$(gh api "repos/${ENT_REPO}/commits?sha=${branch}&per_page=50" \
        --jq '[.[] | select(.commit.message | test("[Ss]ync|[Uu]pstream")) | .commit.message][0]' 2>/dev/null \
        | grep -oP '[a-f0-9]{7,}' | tail -1 || true)

      if [[ -n "$last_sync_oss_sha" ]]; then
        local branch_result
        branch_result=$(gh api "repos/${OSS_REPO}/compare/${PR_SHA}...${last_sync_oss_sha}" --jq '.status' 2>/dev/null || echo "error")
        if [[ "$branch_result" == "ahead" || "$branch_result" == "identical" ]]; then
          echo -e "${GREEN}${tag}${RESET} (${tag_date}): INCLUDED (via ${branch} branch, synced OSS up to ${last_sync_oss_sha})"
        else
          echo -e "${RED}${tag}${RESET} (${tag_date}): NOT included (${branch} branch synced OSS up to ${last_sync_oss_sha}, before this PR)"
        fi
      else
        echo -e "${RED}${tag}${RESET} (${tag_date}): NOT included (release on branch '${branch}', no sync found)"
      fi
    else
      echo -e "${RED}${tag}${RESET} (${tag_date}): NOT included (diverged from solo-main, could not determine release branch)"
    fi
  else
    echo -e "${YELLOW}${tag}${RESET} (${tag_date}): could not compare (${result})"
  fi
}

if [[ -n "$RELEASE_TAG" ]]; then
  check_ent_release "$RELEASE_TAG"
else
  ENT_RELEASES=$(gh release list --repo "$ENT_REPO" --limit 10 --json tagName --jq '.[].tagName')
  while read -r tag; do
    [[ -z "$tag" ]] && continue
    check_ent_release "$tag"
  done <<< "$ENT_RELEASES"
fi

echo ""
