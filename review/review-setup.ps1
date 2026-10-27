# review-setup: get this Windows computer ready to open the factory's dev previews.
# Run it once, with the server address and host key from the factory owner's invitation:
#
#   powershell -ExecutionPolicy Bypass -File review-setup.ps1 -Server <address> -HostKey "<ssh-ed25519 AAAA...>"
#
# What it does (nothing else, and nothing outside your own user account):
#   1. Creates an SSH key only for previews: ~/.ssh/factory_review_ed25519 (kept if it exists).
#   2. Adds the host "factory-review" to ~/.ssh/config and pins the server's host key
#      in ~/.ssh/known_hosts, so ssh never has to ask whether to trust it.
#   3. Installs the "review" command (into %LOCALAPPDATA%\factory-review and your
#      PowerShell profile).
#   4. Prints your PUBLIC key: send that to the factory owner. Never send the file
#      without .pub; it stays on this computer.
# Safe to run again (e.g. to update review, or after the server address changes).
param(
  [Parameter(Mandatory = $true)][string]$Server,
  [Parameter(Mandatory = $true)][string]$HostKey
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Base = 'https://raw.githubusercontent.com/atakumi-global/factory-standards/main/review'

if ($Server -notmatch '^[A-Za-z0-9.-]+$') { throw "Server should be an address like 192.168.1.227 or a host name" }
$hk = ($HostKey.Trim() -split '\s+')
if ($hk.Count -lt 2 -or $hk[0] -notmatch '^(ssh-ed25519|ecdsa-sha2-nistp256|ssh-rsa)$' -or $hk[1] -notmatch '^[A-Za-z0-9+/=]+$') {
  throw "HostKey should look like: ssh-ed25519 AAAA... (copy it from the invitation)"
}
if (-not (Get-Command ssh -ErrorAction SilentlyContinue) -or -not (Get-Command ssh-keygen -ErrorAction SilentlyContinue)) {
  throw "OpenSSH client not found. Install it: Settings > System > Optional features > OpenSSH Client"
}

Write-Host "== 1. SSH key for previews"
$sshDir = Join-Path $HOME '.ssh'
New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
$key = Join-Path $sshDir 'factory_review_ed25519'
if (Test-Path $key) {
  Write-Host "kept: $key"
} else {
  # No passphrase: the key only opens previews you were given, from your WireGuard
  # connection, and review runs the tunnel in the background without asking.
  # One raw command line: PowerShell 5.1 and 7 pass an empty argument differently.
  $comment = ("$env:USERNAME@$env:COMPUTERNAME factory-review" -replace '[^A-Za-z0-9@._ -]', '')
  $kg = Start-Process ssh-keygen -ArgumentList "-q -t ed25519 -N `"`" -C `"$comment`" -f `"$key`"" -NoNewWindow -Wait -PassThru
  if ($kg.ExitCode -ne 0 -or -not (Test-Path $key)) { throw "ssh-keygen did not create $key" }
  Write-Host "created: $key"
}

Write-Host "== 2. SSH host factory-review"
$config = Join-Path $sshDir 'config'
$block = @(
  '# factory-review: dev previews (written by review-setup)',
  'Host factory-review',
  "  HostName $Server",
  '  User review',
  '  IdentityFile ~/.ssh/factory_review_ed25519',
  '  IdentitiesOnly yes',
  '  ServerAliveInterval 30',
  '# end factory-review'
)
$lines = @()
if (Test-Path $config) { $lines = @(Get-Content $config) }
$kept = @(); $skip = $false
foreach ($l in $lines) {
  if ($l -eq '# factory-review: dev previews (written by review-setup)') { $skip = $true; continue }
  if ($skip -and $l -eq '# end factory-review') { $skip = $false; continue }
  if (-not $skip) { $kept += $l }
}
# The block goes first: in ssh_config the first value found wins, so a broad "Host *"
# further down cannot override it.
$utf8 = New-Object System.Text.UTF8Encoding($false)   # no byte-order mark: ssh would misread the first line
[IO.File]::WriteAllLines($config, [string[]]($block + '' + $kept), $utf8)
$known = Join-Path $sshDir 'known_hosts'
$entry = "$Server $($hk[0]) $($hk[1])"
$have = @(); if (Test-Path $known) { $have = @(Get-Content $known) }
$have = @($have | Where-Object { $_ -notmatch ('^' + [regex]::Escape($Server) + ' ') })
[IO.File]::WriteAllLines($known, [string[]]($have + $entry), $utf8)
Write-Host "ok: factory-review = review@$Server, host key pinned"

Write-Host "== 3. The review command"
$bin = Join-Path $env:LOCALAPPDATA 'factory-review'
New-Item -ItemType Directory -Force -Path $bin | Out-Null
$script = Join-Path $bin 'review.ps1'
Invoke-WebRequest -Uri "$Base/review.ps1" -UseBasicParsing -OutFile $script
Unblock-File $script -ErrorAction SilentlyContinue
# Both Windows PowerShell 5.1 and PowerShell 7 (each has its own profile folder).
$docs = [Environment]::GetFolderPath('MyDocuments')
foreach ($prof in @((Join-Path $docs 'WindowsPowerShell\profile.ps1'), (Join-Path $docs 'PowerShell\profile.ps1'))) {
  if (-not (Test-Path $prof)) { New-Item -ItemType File -Force -Path $prof | Out-Null }
  $keep = @(Get-Content $prof | Where-Object { $_ -notmatch '^function review \{' })
  Set-Content -Path $prof -Value ($keep + "function review { & '$script' @args }   # factory-review")
}
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -eq 'Undefined' -or $policy -eq 'Restricted') {
  $effective = Get-ExecutionPolicy
  if ($effective -eq 'Restricted' -or $effective -eq 'AllSigned') {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
    Write-Host "PowerShell may now run local scripts for your account (RemoteSigned), needed for review."
  }
}
Write-Host "ok: review installed ($script)"

Write-Host ""
Write-Host "== 4. Send this PUBLIC key to the factory owner:"
Write-Host ""
Write-Host (Get-Content "$key.pub" -Raw).Trim()
Write-Host ""
Write-Host "When the owner confirms you are added: switch on your WireGuard connection, open a"
Write-Host "new PowerShell window and run:   review status"
