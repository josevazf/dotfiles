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
- **Track last PROCESSED review timestamp, not just push timestamp** — when you resolve threads without pushing code and re-request a review, the old review is still newer than the last push. If you only compare review vs push, you'll falsely think the new review is in and find zero threads (because you just resolved them). Always wait for a review with a timestamp strictly newer than the last review you already acted on.
- **Race condition: review timestamp appears before threads are created** — when Copilot submits a review, the review object and its timestamp appear in the API before all review threads/comments are fully attached. If you immediately query for unresolved threads, you'll find 0 and falsely declare the PR clean. **Always wait 60 seconds after detecting a new review before checking threads.** Then verify: if the review has comments but you see 0 unresolved threads, wait and re-check.
- **NEVER declare "clean" without verification** — before stopping the loop, always cross-check by fetching the review's comment count. If comments > 0 but unresolved threads == 0, all comments were on already-resolved threads — that's genuinely clean. But if the review is brand new and has 0 threads at all, it's likely the race condition.
- **CRITICAL PAGINATION BUG: `first:100` misses threads on large PRs** — GraphQL `reviewThreads(first:100)` only returns the first 100 threads. After many review cycles, total threads can exceed 100 (e.g. 130+), and the newest threads from the latest review are NOT in the first 100. **Always use cursor-based pagination to fetch ALL unresolved threads.** Query `totalCount` first, then paginate with `after` cursor if needed. At minimum, also query `last:100` and deduplicate by thread ID — but cursor pagination is the only reliable approach for PRs with 100+ threads.
- **CRITICAL: Always check unresolved threads directly, not just review timestamps** — Copilot can add new threads to an existing review without submitting a new review object, or it may stop submitting new reviews entirely while unresolved threads remain. If you only compare review timestamps against the last push/processed epoch, you will miss these threads and falsely declare the PR clean. **On every poll tick, ALSO query for unresolved threads directly (both first:100 and last:100).** Only skip thread processing if both: (a) no new review timestamp AND (b) zero unresolved threads across all pagination windows.
- **CRITICAL STATE BUG: premature "clean" after fixing threads** — After fixing threads and pushing code, the next poll finds 0 unresolved threads (because you just resolved them) and no new review yet (Copilot hasn't reviewed the new code). The old verification logic (review comments > 0, unresolved == 0) declares "genuinely clean" — but Copilot hasn't even looked at the new code. **Track `AWAITING_REVIEW_AFTER_PUSH` state.** After Step 3a pushes code, set this to `true`. Only allow "clean" declaration when this is `false` — meaning a new review has arrived AND been processed since the last push. When `AWAITING_REVIEW_AFTER_PUSH` is `true` and 0 unresolved threads are found, output "Waiting for Copilot to review new code..." and stop — do NOT declare clean.

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
LAST_PROCESSED_REVIEW_EPOCH: 0
AWAITING_REVIEW_AFTER_PUSH: false

## Step 1 — Check for a NEW Copilot review

Run:
  git log origin/BRANCH -1 --format="%ct"
  gh api repos/OWNER/REPO/pulls/PR_NUMBER/reviews \
    --jq '[.[] | select(.user.login == "copilot-pull-request-reviewer[bot]")] | last | .submitted_at'

If no review exists: output "Waiting for Copilot review..." and stop.

Convert submitted_at to UTC epoch: TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "<timestamp>" +%s
⚠️ macOS `date -j` without TZ=UTC treats UTC times as local — always use TZ=UTC or the comparison will be wrong.

Compute the "floor" timestamp — the LARGER of:
  a) the last push epoch (from git log)
  b) LAST_PROCESSED_REVIEW_EPOCH (from the top of this prompt)

If review epoch > floor: this is a NEW review.
  ⚠️ Wait for threads to attach (race condition guard): sleep 60, then proceed to Step 2.

If review epoch <= floor: no new review yet.
  ⚠️ CRITICAL: Do NOT stop here. Copilot can add threads without submitting a new review, or stop reviewing entirely while unresolved threads remain. **Always proceed to Step 2 to check for unresolved threads regardless of review timestamp.** Only output "Waiting..." and stop if Step 2 also finds zero unresolved threads.

If a new review IS detected AND AWAITING_REVIEW_AFTER_PUSH is true:
  Set AWAITING_REVIEW_AFTER_PUSH to false (Copilot has now reviewed our latest code).

## Step 2 — Get unresolved threads

⚠️ CRITICAL: `reviewThreads(first:100)` only returns the FIRST 100 threads. After many review
cycles, total threads can exceed 100+ and the NEWEST threads (from the latest review) will be
INVISIBLE. You MUST check totalCount and paginate if needed.

Step 2a — Check total thread count:
gh api graphql -f query='{repository(owner:"OWNER",name:"REPO"){pullRequest(number:PR_NUMBER){reviewThreads(first:1){totalCount}}}}' \
  --jq '.data.repository.pullRequest.reviewThreads.totalCount'

⚠️ ALWAYS run Step 2 — even if no new review was detected in Step 1. Copilot can add threads
without a new review object, or stop reviewing entirely while threads remain unresolved.

Step 2b — If totalCount <= 100, a single query suffices:
gh api graphql -f query='{repository(owner:"OWNER",name:"REPO"){pullRequest(number:PR_NUMBER){reviewThreads(first:100){nodes{id isResolved comments(first:1){nodes{databaseId body path line}}}}}}}' \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved==false) | [.id, .comments.nodes[0].path, (.comments.nodes[0].line | tostring), .comments.nodes[0].body] | @tsv'

Step 2c — If totalCount > 100, use BOTH `first:100` AND `last:100` and deduplicate by thread ID:
Query 1: first:100 (as above)
Query 2:
gh api graphql -f query='{repository(owner:"OWNER",name:"REPO"){pullRequest(number:PR_NUMBER){reviewThreads(last:100){nodes{id isResolved comments(first:1){nodes{databaseId body path line}}}}}}}' \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved==false) | [.id, .comments.nodes[0].path, (.comments.nodes[0].line | tostring), .comments.nodes[0].body] | @tsv'

Combine results and deduplicate by thread ID. For PRs with 200+ threads, use cursor-based
pagination with `after` cursor from the first query's `pageInfo.endCursor`.

## Step 3a — If unresolved threads:

For each thread: read the file, implement the fix if valid (use judgment), run npm run check, fix lint errors.

**If code changes were made:**
  Commit: git add -A && git commit -m "fix(scope): address Copilot review feedback"
  Push: git push

Resolve each thread:
  gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "THREAD_ID"}) { thread { isResolved } } }'

Re-request review:
  gh api repos/OWNER/REPO/pulls/PR_NUMBER/requested_reviewers \
    -X POST -f "reviewers[]=copilot-pull-request-reviewer[bot]"

⚠️ Update the cron prompt state: CronDelete the current job, then CronCreate a new one with:
  - LAST_PROCESSED_REVIEW_EPOCH set to the current review's epoch
  - AWAITING_REVIEW_AFTER_PUSH set to `true` (if code was pushed) or `false` (if only threads were resolved without code changes)
This is essential — if AWAITING_REVIEW_AFTER_PUSH is not set to true after a push, the next poll
will see 0 unresolved threads and falsely declare the PR clean before Copilot reviews the new code.

Output: "Fixed N issues, re-requested Copilot review." and stop.

## Step 3b — If zero unresolved threads (verify before declaring clean):

⚠️ NEVER immediately declare clean. Cross-check first:

**Step 3b-GATE: Check AWAITING_REVIEW_AFTER_PUSH first.**
If AWAITING_REVIEW_AFTER_PUSH is `true`: Copilot has NOT yet reviewed the code you just pushed.
Finding 0 unresolved threads is EXPECTED (you just resolved them all). This is NOT "clean."
Output: "Waiting for Copilot to review new code..." and STOP. Do NOT proceed to verification.
Do NOT declare clean. Do NOT delete the cron job. Just wait for the next tick.

**Only if AWAITING_REVIEW_AFTER_PUSH is `false`**, proceed with verification:

1. Count the review's comments:
   gh api repos/OWNER/REPO/pulls/PR_NUMBER/reviews \
     --jq '[.[] | select(.user.login == "copilot-pull-request-reviewer[bot]")] | last | .id' \
   → then: gh api repos/OWNER/REPO/pulls/PR_NUMBER/reviews/REVIEW_ID/comments --jq 'length'

2. Count total unresolved threads (⚠️ must cover ALL threads, not just first:100):
   First get totalCount, then if > 100 use BOTH first:100 and last:100:
   gh api graphql -f query='{repository(owner:"OWNER",name:"REPO"){pullRequest(number:PR_NUMBER){reviewThreads(last:100){nodes{isResolved}}}}}' \
     --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved==false)] | length'
   Also check first:100 and combine — threads in the gap between first:100 and last:100 would be missed on PRs with 200+ threads.

3. If review comments > 0 but unresolved == 0: genuinely clean (all threads were resolved).
   If review comments == 0 AND this is a new review: likely race condition — wait another 60 seconds and re-check threads.
   If unresolved > 0: go back to Step 3a.

Only when verified clean — notify the user:
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
