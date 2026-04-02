---
name: copilot-review-loop
description: Use when you want to autonomously iterate on Copilot PR review feedback - polls every minute, fixes issues, re-requests review, and stops when clean. Use after creating a PR and requesting a Copilot review.
---

# Copilot Review Loop

Polls a PR every minute for Copilot review feedback, fixes issues, and iterates until the review is clean.

## When to Use

- After creating a PR and requesting an initial Copilot review
- When you want hands-off iteration: fix → re-request → fix → done

## Key Lessons (from baseline failures)

- **Do NOT use ralph-loop** — it has no delay between iterations and burns through the limit while waiting
- **Do NOT use `@copilot` comments** to trigger re-reviews — use the API
- **Do NOT check only for unresolved threads** — also check that Copilot reviewed *after* the last push, otherwise you'll falsely think it's clean

## Setup

### Step 1 — Request the initial Copilot review

```bash
gh api repos/OWNER/REPO/pulls/PR_NUMBER/requested_reviewers \
  -X POST -f "reviewers[]=copilot-pull-request-reviewer[bot]"
```

### Step 2 — Create the cron job (fires every minute)

Call `CronCreate` with:
- `cron`: `*/1 * * * *`
- `recurring`: `true`
- `prompt`: the iteration prompt below (fill in OWNER, REPO, BRANCH, PR_NUMBER)

## Iteration Prompt Template

```
You are monitoring PR #PR_NUMBER (BRANCH) in OWNER/REPO for Copilot review feedback.

## Step 1 — Compare latest push vs latest Copilot review

Run:
  git log origin/BRANCH -1 --format="%ct"
  gh api repos/OWNER/REPO/pulls/PR_NUMBER/reviews \
    --jq '[.[] | select(.user.login == "copilot-pull-request-reviewer[bot]")] | last | .submitted_at'

If no review exists: output "Waiting for Copilot review..." and stop.

Convert submitted_at to UTC epoch: TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "<timestamp>" +%s
⚠️ macOS `date -j` without TZ=UTC treats UTC times as local — always use TZ=UTC or the comparison will be wrong.
If review epoch <= push epoch: output "Waiting for Copilot to review latest push..." and stop.

## Step 2 — Get unresolved threads

gh api graphql -f query='{repository(owner:"OWNER",name:"REPO"){pullRequest(number:PR_NUMBER){reviewThreads(first:30){nodes{id isResolved comments(first:1){nodes{databaseId body path line}}}}}}}' \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved==false) | [.id, .comments.nodes[0].path, (.comments.nodes[0].line | tostring), .comments.nodes[0].body] | @tsv'

## Step 3a — If unresolved threads:

For each thread: read the file, implement the fix if valid (use judgment), run npm run check, fix lint errors.

Commit: git add -A && git commit -m "fix(scope): address Copilot review feedback"
Push: git push

Resolve each thread:
  gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "THREAD_ID"}) { thread { isResolved } } }'

Re-request review:
  gh api repos/OWNER/REPO/pulls/PR_NUMBER/requested_reviewers \
    -X POST -f "reviewers[]=copilot-pull-request-reviewer[bot]"

Output: "Fixed N issues, re-requested Copilot review." and stop.

## Step 3b — If zero unresolved threads:

Copilot has reviewed the latest push and left no comments. Notify the user:
"PR #PR_NUMBER Copilot review is clean — ready for your final review: https://github.com/OWNER/REPO/pull/PR_NUMBER"

Then call CronDelete with this job's ID to stop the loop.

## Rules:
- NEVER post a PR comment to trigger re-reviews — use the API only
- Do NOT merge the PR
- Follow project lint/format conventions before committing
```

## After Setting Up

Tell the user:
- The cron job ID (for CronDelete if they want to cancel)
- That it fires every minute, auto-expires after 7 days
- That you'll notify them when the PR is clean

## Quick Reference

| Task | Command |
|------|---------|
| Request review | `gh api repos/O/R/pulls/N/requested_reviewers -X POST -f "reviewers[]=copilot-pull-request-reviewer[bot]"` |
| List reviews | `gh api repos/O/R/pulls/N/reviews --jq '.[] \| [.user.login, .state, .submitted_at] \| @tsv'` |
| Get unresolved threads | GraphQL `reviewThreads` with `select(.isResolved==false)` |
| Resolve thread | GraphQL `resolveReviewThread` mutation |
| Cancel loop | `CronDelete` with job ID |
