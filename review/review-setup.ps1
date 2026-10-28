# review-setup: get this Windows computer ready to open the factory's dev previews.
# Run it once, with the values from the factory owner's invitation (copy the whole line):
#
#   powershell -ExecutionPolicy Bypass -File review-setup.ps1 -Server 10.77.0.1 -Port 2222 `
#     -HostKey "ssh-ed25519 AAAA..." -VpnAddress 10.77.0.N -VpnServerKey "..." -VpnEndpoint <ip>:<port>
#
# Needs the WireGuard app (https://www.wireguard.com/install/) and the OpenSSH client.
# What it does (nothing else, and nothing outside your own user account):
#   1. Creates your WireGuard key and the tunnel file factory-review.conf in
#      %USERPROFILE%\factory-review (kept if it exists). The tunnel carries only the
#      traffic to the review server, nothing else of yours.
#   2. Creates an SSH key only for previews: ~/.ssh/factory_review_ed25519 (kept if it exists).
#   3. Adds the host "factory-review" to ~/.ssh/config and pins the server's host key
#      in ~/.ssh/known_hosts, so ssh never has to ask whether to trust it.
#   4. Installs the "review" command (into %LOCALAPPDATA%\factory-review and your
#      PowerShell profiles).
#   5. Prints your two PUBLIC keys: send them to the factory owner. The private keys
#      never leave this computer.
# Safe to run again (e.g. to update review, or with a new invitation).
param(
  [Parameter(Mandatory = $true)][string]$Server,
  [Parameter(Mandatory = $true)][int]$Port,
  [Parameter(Mandatory = $true)][string]$HostKey,
  [Parameter(Mandatory = $true)][string]$VpnAddress,
  [Parameter(Mandatory = $true)][string]$VpnServerKey,
  [Parameter(Mandatory = $true)][string]$VpnEndpoint
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Base = 'https://raw.githubusercontent.com/atakumi-global/factory-standards/main/review'
$utf8 = New-Object System.Text.UTF8Encoding($false)   # no byte-order mark: ssh and WireGuard would misread it

$ip4 = '^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$'
if ($Server -notmatch $ip4) { throw "Server should be an address like 10.77.0.1 (copy it from the invitation)" }
if ($VpnAddress -notmatch $ip4) { throw "VpnAddress should be an address like 10.77.0.5 (copy it from the invitation)" }
if ($Port -lt 1 -or $Port -gt 65535) { throw "Port should be a number like 2222" }
if ($VpnServerKey -notmatch '^[A-Za-z0-9+/]{42}[AEIMQUYcgkosw480]=$') { throw "VpnServerKey should be 44 characters ending in = (copy it from the invitation)" }
if ($VpnEndpoint -notmatch '^[A-Za-z0-9.-]+:\d{1,5}$') { throw "VpnEndpoint should look like 203.0.113.7:51877 (copy it from the invitation)" }
$hk = ($HostKey.Trim() -split '\s+')
if ($hk.Count -lt 2 -or $hk[0] -notmatch '^(ssh-ed25519|ecdsa-sha2-nistp256|ssh-rsa)$' -or $hk[1] -notmatch '^[A-Za-z0-9+/=]+$') {
  throw "HostKey should look like: ssh-ed25519 AAAA... (copy it from the invitation)"
}
if (-not (Get-Command ssh -ErrorAction SilentlyContinue) -or -not (Get-Command ssh-keygen -ErrorAction SilentlyContinue)) {
  throw "OpenSSH client not found. Install it: Settings > System > Optional features > OpenSSH Client"
}
$wg = Join-Path $env:ProgramFiles 'WireGuard\wg.exe'
if (-not (Test-Path $wg)) { throw "WireGuard not found ($wg). Install it from https://www.wireguard.com/install/ and run this again." }

Write-Host "== 1. WireGuard tunnel factory-review"
$vpnDir = Join-Path $HOME 'factory-review'
New-Item -ItemType Directory -Force -Path $vpnDir | Out-Null
$tunnel = Join-Path $vpnDir 'factory-review.conf'
$private = $null
if (Test-Path $tunnel) {
  $m = Select-String -Path $tunnel -Pattern '^PrivateKey\s*=\s*(\S+)\s*$' | Select-Object -First 1
  if ($m) { $private = $m.Matches[0].Groups[1].Value }
}
if ($private) { Write-Host "kept your key from $tunnel" }
else { $private = (& $wg genkey).Trim(); Write-Host "created your WireGuard key" }
$vpnPublic = ($private | & $wg pubkey).Trim()
$conf = @(
  '[Interface]',
  "PrivateKey = $private",
  "Address = $VpnAddress/32",
  '',
  '[Peer]',
  "PublicKey = $VpnServerKey",
  "Endpoint = $VpnEndpoint",
  "AllowedIPs = $Server/32",
  'PersistentKeepalive = 25'
)
[IO.File]::WriteAllLines($tunnel, [string[]]$conf, $utf8)
# Only you may read the file: it holds your private key.
& icacls $tunnel /inheritance:r /grant:r "$($env:USERNAME):F" | Out-Null
Write-Host "ok: $tunnel"

Write-Host "== 2. SSH key for previews"
$sshDir = Join-Path $HOME '.ssh'
New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
$key = Join-Path $sshDir 'factory_review_ed25519'
if (Test-Path $key) {
  Write-Host "kept: $key"
} else {
  # No passphrase: the key only opens the previews you were given, only through your
  # factory-review tunnel, and review runs the SSH tunnel in the background.
  # One raw command line: PowerShell 5.1 and 7 pass an empty argument differently.
  $comment = ("$env:USERNAME@$env:COMPUTERNAME factory-review" -replace '[^A-Za-z0-9@._ -]', '')
  $kg = Start-Process ssh-keygen -ArgumentList "-q -t ed25519 -N `"`" -C `"$comment`" -f `"$key`"" -NoNewWindow -Wait -PassThru
  if ($kg.ExitCode -ne 0 -or -not (Test-Path $key)) { throw "ssh-keygen did not create $key" }
  Write-Host "created: $key"
}

Write-Host "== 3. SSH host factory-review"
$config = Join-Path $sshDir 'config'
$block = @(
  '# factory-review: dev previews (written by review-setup)',
  'Host factory-review',
  "  HostName $Server",
  "  Port $Port",
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
[IO.File]::WriteAllLines($config, [string[]]($block + '' + $kept), $utf8)
$known = Join-Path $sshDir 'known_hosts'
$hostId = if ($Port -eq 22) { $Server } else { "[$Server]:$Port" }
$have = @(); if (Test-Path $known) { $have = @(Get-Content $known) }
$have = @($have | Where-Object { $_ -notmatch ('^' + [regex]::Escape($hostId) + ' ') })
[IO.File]::WriteAllLines($known, [string[]]($have + "$hostId $($hk[0]) $($hk[1])"), $utf8)
Write-Host "ok: factory-review = review@${Server}:$Port, host key pinned"

Write-Host "== 4. The review command"
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
Write-Host "== 5. Send these two PUBLIC keys to the factory owner:"
Write-Host ""
Write-Host "ssh:       $((Get-Content "$key.pub" -Raw).Trim())"
Write-Host "wireguard: $vpnPublic"
Write-Host ""
Write-Host "Next: in the WireGuard app choose 'Import tunnel(s) from file' and pick"
Write-Host "  $tunnel"
Write-Host "When the owner confirms you are added: activate factory-review in WireGuard, open a"
Write-Host "new PowerShell window and run:   review status"
