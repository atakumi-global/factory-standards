#!/usr/bin/env bash
# finish-work.sh — finish a feature branch per factory-standards WORKFLOW.md.
#
# fetch -> fast-forward local dev -> merge dev into the feature -> run gates ->
# run factory-check -> merge the feature into dev (--no-ff) -> push dev ->
# restart the local stack.
#
# Guards: feature branch containing a work-item id, clean tree, protected-branch
# refusal, gate command required (unless --no-gate), factory-check required
# (unless --no-security-check, owner only), no force-push ever.
# Safe to re-run; on a conflict it stops and says what to do.
#
# Usage:
#   finish-work.sh --project . --gate "npm run lint && npm test"
#   finish-work.sh --project . --gate "npm test" --no-push --no-restart
#
# In a git worktree whose dev branch is checked out elsewhere (Orca workspaces on the
# agent server), it merges on a detached HEAD at origin/dev and pushes HEAD:dev.
set -uo pipefail

project="."; dev_branch="dev"; gate=""; no_gate=0; no_sec=0; no_push=0; no_restart=0
while [ $# -gt 0 ]; do
  case "$1" in
    --project) project="$2"; shift 2 ;;
    --dev-branch) dev_branch="$2"; shift 2 ;;
    --gate) gate="$2"; shift 2 ;;
    --no-gate) no_gate=1; shift ;;
    --no-security-check) no_sec=1; shift ;;
    --no-push) no_push=1; shift ;;
    --no-restart) no_restart=1; shift ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    *) echo "FAIL: unknown argument '$1'" >&2; exit 1 ;;
  esac
done

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
step() { printf '== %s\n' "$1"; }

[ -n "$gate" ] || [ "$no_gate" -eq 1 ] || fail 'pass --gate "<gates>" (or --no-gate to skip deliberately)'
cd "$project" 2>/dev/null || fail "cannot enter $project"
git rev-parse --git-dir >/dev/null 2>&1 || fail "not a git repository: $project"

branch="$(git branch --show-current)"
[ -n "$branch" ] || fail 'detached HEAD'
for p in main master stage prod "$dev_branch"; do
  [ "$branch" = "$p" ] && fail "refusing to finish from protected branch '$branch'"
done
[[ "$branch" =~ [A-Za-z]+-[0-9]+ ]] || fail "feature branch '$branch' has no work-item id (expected like feat/PROJ-42-slug)"
dirty="$(git status --porcelain)"
[ -z "$dirty" ] || fail "working tree is not clean:
$dirty"

# In a git worktree (Orca workspaces on the agent server), dev is usually checked out in
# the main worktree and cannot be checked out here. Then the feature is merged into dev
# on a detached HEAD at origin/dev and pushed to dev directly; the local dev branch of
# the main worktree is left alone (the owner or the preview follows origin/dev).
here="$(git rev-parse --show-toplevel)"
dev_elsewhere="$(git worktree list --porcelain | awk -v me="$here" -v want="branch refs/heads/$dev_branch" \
  '/^worktree /{p=substr($0, 10)} $0 == want && p != me {print p}')"

step 'fetch origin'
git fetch origin || fail 'git fetch failed'

if [ -n "$dev_elsewhere" ]; then
  step "worktree mode: $dev_branch is checked out in $dev_elsewhere"
  step "merge origin/$dev_branch into $branch"
  git merge "origin/$dev_branch" --no-edit || fail "merge conflict - resolve on '$branch', run the gates, then re-run this script"
  if [ -n "$gate" ]; then
    step "gates: $gate"
    bash -c "$gate" || fail 'gates failed - fix before finishing'
  else
    step 'gates skipped (--no-gate)'
  fi
  if [ "$no_sec" -eq 0 ]; then
    command -v factory-check >/dev/null || fail 'factory-check not found on PATH - install it (factory-standards/scripts) or pass --no-security-check (owner only)'
    step "security: factory-check origin/$dev_branch"
    factory-check "origin/$dev_branch" || fail 'factory-check failed - fix the findings or report them and set Blocked'
  else
    step 'factory-check skipped (--no-security-check) - CI will still scan dev'
  fi
  step "merge $branch into $dev_branch (detached at origin/$dev_branch)"
  git checkout --quiet --detach "origin/$dev_branch" || fail "cannot check out origin/$dev_branch"
  if ! git merge --no-ff "$branch" -m "merge: $branch into $dev_branch"; then
    git merge --abort 2>/dev/null; git checkout --quiet "$branch"
    fail "merge into $dev_branch failed - origin/$dev_branch moved; re-run this script"
  fi
  merge_commit="$(git rev-parse HEAD)"
  if [ "$no_push" -eq 0 ]; then
    step "push origin HEAD:$dev_branch"
    if ! git push origin "HEAD:$dev_branch"; then
      git checkout --quiet "$branch"
      fail "push rejected - origin/$dev_branch moved; re-run this script (it merges the new $dev_branch first)"
    fi
  else
    step 'push skipped (--no-push)'
  fi
  git checkout --quiet "$branch" || fail "cannot return to $branch"
  step "merge commit $merge_commit"
  step 'restart skipped (worktree mode: the dev preview follows origin/dev by itself)'
  step 'finished. Now: Plane: comment evidence (branch, merge commit, gates, factory-check), set In Review.'
  exit 0
fi

step "fast-forward local $dev_branch from origin/$dev_branch"
git checkout "$dev_branch" || fail "checkout $dev_branch failed"
git pull --ff-only origin "$dev_branch" || fail "local $dev_branch diverged from origin/$dev_branch - reconcile manually (never force-push)"

step "merge $dev_branch into $branch"
git checkout "$branch" || fail "checkout $branch failed"
git merge "$dev_branch" --no-edit || fail "merge conflict - resolve on '$branch', run the gates, then re-run this script"

if [ -n "$gate" ]; then
  step "gates: $gate"
  bash -c "$gate" || fail 'gates failed - fix before finishing'
else
  step 'gates skipped (--no-gate)'
fi

if [ "$no_sec" -eq 0 ]; then
  command -v factory-check >/dev/null || fail 'factory-check not found on PATH - install it (factory-standards/scripts) or pass --no-security-check (owner only)'
  step "security: factory-check $dev_branch"
  factory-check "$dev_branch" || fail 'factory-check failed - fix the findings or report them and set Blocked'
else
  step 'factory-check skipped (--no-security-check) - CI will still scan dev'
fi

step "merge $branch into $dev_branch"
git checkout "$dev_branch" || fail "checkout $dev_branch failed"
git merge --no-ff "$branch" -m "merge: $branch into $dev_branch" || fail "merge into $dev_branch failed"

if [ "$no_push" -eq 0 ]; then
  step "push origin $dev_branch"
  git push origin "$dev_branch" || fail 'push failed - pull/re-merge, re-gate, retry'
else
  step 'push skipped (--no-push)'
fi

if [ "$no_restart" -eq 0 ]; then
  if [ -x ./stack.sh ]; then
    step 'restart stack: ./stack.sh restart'
    ./stack.sh restart || printf 'warning: stack restart failed - restart manually\n' >&2
  else
    step 'no ./stack.sh found - restart manually'
  fi
else
  step 'restart skipped (--no-restart)'
fi

step 'finished. Now: GitHub promote (manual) dev -> stage -> production; then Plane: comment evidence, set In Review.'
