<#
.SYNOPSIS
  Finish a feature branch per factory-standards WORKFLOW.md.

.DESCRIPTION
  fetch -> fast-forward local dev -> merge dev into the feature -> run gates ->
  run factory-check -> merge the feature into dev (--no-ff) -> push dev ->
  restart the local stack.

  Guards: feature branch containing a work-item id, clean tree, protected
  branch refusal, gate command required (unless -NoGate), factory-check
  required (unless -NoSecurityCheck, owner only), no force-push ever.
  Safe to re-run; on a conflict it stops and tells you what to do.

.USAGE
  .\finish-work.ps1 -Project C:\path\to\repo -GateCommand "pnpm lint; pnpm typecheck"
  .\finish-work.ps1 -Project . -GateCommand "npm test" -NoPush -NoRestart
  .\finish-work.ps1 -Project . -GateCommand "npm test" -StackScript stack.ps1

  The stack restart uses -StackScript if given, otherwise the single .ps1 script in
  the repository root (other than finish-work.ps1).
#>
param(
    [Parameter(Mandatory = $true)][string]$Project,
    [string]$DevBranch = 'dev',
    [string]$GateCommand = '',
    [switch]$NoGate,
    [switch]$NoSecurityCheck,
    [switch]$NoPush,
    [switch]$NoRestart,
    [string]$StackScript = ''
)

$ErrorActionPreference = 'Stop'
function Fail([string]$m) { Write-Host "FAIL: $m" -ForegroundColor Red; exit 1 }
function Step([string]$m) { Write-Host "== $m" -ForegroundColor Cyan }

if (-not $GateCommand -and -not $NoGate) {
    Fail 'pass -GateCommand "<gates>" (or -NoGate to skip deliberately)'
}

$repo = (Resolve-Path -LiteralPath $Project).Path
if (-not (Test-Path (Join-Path $repo '.git'))) { Fail "not a git repository: $repo" }

Push-Location $repo
try {
    $branch = (git branch --show-current).Trim()
    if (-not $branch) { Fail 'detached HEAD' }
    $protected = @('main', 'master', 'stage', 'prod', $DevBranch)
    if ($protected -contains $branch) { Fail "refusing to finish from protected branch '$branch'" }
    if ($branch -notmatch '[A-Za-z]+-\d+') {
        Fail "feature branch '$branch' has no work-item id (expected like feat/PROJ-42-slug)"
    }
    $dirty = git status --porcelain
    if ($dirty) { Fail "working tree is not clean:`n$dirty" }

    Step 'fetch origin'
    git fetch origin
    if ($LASTEXITCODE) { Fail 'git fetch failed' }

    Step "fast-forward local $DevBranch from origin/$DevBranch"
    git checkout $DevBranch
    if ($LASTEXITCODE) { Fail "checkout $DevBranch failed" }
    git pull --ff-only origin $DevBranch
    if ($LASTEXITCODE) {
        Fail "local $DevBranch diverged from origin/$DevBranch - reconcile manually (never force-push)"
    }

    Step "merge $DevBranch into $branch"
    git checkout $branch
    if ($LASTEXITCODE) { Fail "checkout $branch failed" }
    git merge $DevBranch --no-edit
    if ($LASTEXITCODE) {
        Fail "merge conflict - resolve on '$branch', run the gates, then re-run this script"
    }

    if ($GateCommand) {
        Step "gates: $GateCommand"
        Invoke-Expression $GateCommand
        if ($LASTEXITCODE) { Fail 'gates failed - fix before finishing' }
    } else {
        Write-Host '== gates skipped (-NoGate)' -ForegroundColor Yellow
    }

    if (-not $NoSecurityCheck) {
        $check = Get-Command factory-check -ErrorAction SilentlyContinue
        if (-not $check) {
            Fail 'factory-check not found on PATH - install it (factory-standards/scripts) or pass -NoSecurityCheck (owner only)'
        }
        Step "security: factory-check $DevBranch"
        & $check.Source $DevBranch
        if ($LASTEXITCODE) { Fail 'factory-check failed - fix the findings or report them and set Blocked' }
    } else {
        Write-Host '== factory-check skipped (-NoSecurityCheck) - CI will still scan dev' -ForegroundColor Yellow
    }

    Step "merge $branch into $DevBranch"
    git checkout $DevBranch
    if ($LASTEXITCODE) { Fail "checkout $DevBranch failed" }
    git merge --no-ff $branch -m "merge: $branch into $DevBranch"
    if ($LASTEXITCODE) { Fail "merge into $DevBranch failed" }

    if (-not $NoPush) {
        Step "push origin $DevBranch"
        git push origin $DevBranch
        if ($LASTEXITCODE) { Fail 'push failed - pull/re-merge, re-gate, retry' }
    } else {
        Write-Host '== push skipped (-NoPush)' -ForegroundColor Yellow
    }

    if (-not $NoRestart) {
        if ($StackScript) {
            $restart = Join-Path $repo $StackScript
        } else {
            $candidates = @(Get-ChildItem -LiteralPath $repo -Filter '*.ps1' -File |
                Where-Object { $_.Name -ne 'finish-work.ps1' })
            $restart = if ($candidates.Count -eq 1) { $candidates[0].FullName } else { $null }
        }
        if ($restart -and (Test-Path $restart)) {
            Step "restart stack: $restart start"
            & $restart start
        } else {
            Write-Host '== no single stack script found in the repo root - pass -StackScript or restart manually' -ForegroundColor Yellow
        }
    } else {
        Write-Host '== restart skipped (-NoRestart)' -ForegroundColor Yellow
    }

    Step 'finished. Now: GitHub promote (manual) dev -> stage -> production; then Plane: comment evidence, set In Review.'
} finally {
    Pop-Location
}
