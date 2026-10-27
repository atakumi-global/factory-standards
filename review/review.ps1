# review: open a project's dev preview from the factory's agent server (Windows).
# Installed by review-setup.ps1; the same commands as review (Linux, macOS).
#
#   review airtime start     start the preview if needed, tunnel in the background,
#                            print the links and open the browser
#   review airtime stop      close your tunnel (the server stops the preview itself
#                            2 hours after the last tunnel closes)
#   review airtime status    the preview's state on the server and your tunnel
#   review status            all previews you have access to
#
# The project is its Plane identifier (AIRTIME), its key (ATAK-AIRTIME) or its name, in
# any case; "review start airtime" works too. No window stays open: the tunnel is a
# hidden ssh process. Connects to the SSH host "factory-review" (written by
# review-setup.ps1 into ~/.ssh/config); you need your WireGuard connection on.
param(
  [Parameter(Position = 0)][string]$First,
  [Parameter(Position = 1)][string]$Second,
  [switch]$NoBrowser
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$SshHost = 'factory-review'
# Local ports = the project's ports + this offset (e.g. 10000 when something on your
# computer already uses 3500-3509: the preview then opens on 13500).
$Offset = 0
if ($env:FACTORY_REVIEW_PORT_OFFSET) {
  if ($env:FACTORY_REVIEW_PORT_OFFSET -notmatch '^[0-9]+$') { Write-Host "FACTORY_REVIEW_PORT_OFFSET must be a number"; exit 2 }
  $Offset = [int]$env:FACTORY_REVIEW_PORT_OFFSET
}
$State = Join-Path $env:LOCALAPPDATA 'factory-review'
New-Item -ItemType Directory -Force -Path $State | Out-Null

$actions = @('start', 'stop', 'status')
if ($actions -contains $First) { $Action = $First; $Name = $Second } else { $Name = $First; $Action = $Second }
if (-not $Action) { $Action = 'status' }
if ($actions -notcontains $Action) { Write-Host "usage: review <project> start|stop|status   or   review status"; exit 2 }

function Invoke-Gate([string]$request) {
  $out = ssh -o BatchMode=yes -o ConnectTimeout=10 $SshHost $request 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Host "The agent server did not answer '$request':"
    $out | ForEach-Object { Write-Host "  $_" }
    Write-Host "Is your WireGuard connection on? Has the factory owner added your key yet?"
    exit 1
  }
  return @($out | ForEach-Object { "$_" })
}
function Get-Tunnel($key) {
  $pidFile = Join-Path $State "$key.pid"
  if (-not (Test-Path $pidFile)) { return $null }
  $tunnelPid = [int](Get-Content $pidFile -Raw).Trim()
  $proc = Get-Process -Id $tunnelPid -ErrorAction SilentlyContinue
  if ($proc -and $proc.ProcessName -eq 'ssh') { return $proc }
  Remove-Item $pidFile -ErrorAction SilentlyContinue
  return $null
}
function Test-Answers($url) {
  try { Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5 | Out-Null; return $true }
  catch { if ($_.Exception.Response) { return $true } else { return $false } }
}

# ---------------------------------------------------------------- review status (all)
if (-not $Name) {
  if ($Action -ne 'status') { Write-Host "usage: review <project> $Action"; exit 2 }
  Invoke-Gate 'status' | ForEach-Object { Write-Host $_ }
  exit 0
}

$projects = @()
foreach ($row in (Invoke-Gate 'list')) {
  $f = $row.Trim() -split '\|'
  if ($f.Count -lt 5) { continue }
  $projects += [pscustomobject]@{ Key = $f[0]; Ident = $f[1]; Name = $f[2]; Base = [int]$f[3]; Path = $f[4] }
}
$proj = $projects | Where-Object { $_.Key -ieq $Name -or $_.Ident -ieq $Name -or $_.Name -ieq $Name } | Select-Object -First 1
if (-not $proj) {
  Write-Host "No preview '$Name' for you. Yours:"
  foreach ($p in $projects) { Write-Host "  $(if ($p.Ident) { $p.Ident.ToLower() } else { $p.Key })  ($($p.Key), $($p.Name))" }
  exit 2
}
$label = if ($proj.Ident) { $proj.Ident.ToLower() } else { $proj.Key }
$pidFile = Join-Path $State "$($proj.Key).pid"
$outFile = Join-Path $State "$($proj.Key).out"
$errFile = Join-Path $State "$($proj.Key).err"
$lbase = $proj.Base + $Offset
$probe = "http://127.0.0.1:$lbase$($proj.Path)"
$app = "http://localhost:$lbase$($proj.Path)"

function Show-Links {
  Write-Host ""
  Write-Host "$($proj.Name) ($($proj.Key)) dev preview"
  Write-Host "  App:     $app"
  Write-Host "  Ports:   $lbase-$($lbase + 9) on this computer, forwarded from the agent server"
  Write-Host "  Close:   review $label stop"
}

if ($Action -eq 'start') {
  if ((Get-Tunnel $proj.Key) -and (Test-Answers $probe)) {
    Write-Host "The preview of $label is already open."
    Show-Links
    if (-not $NoBrowser) { Start-Process $app }
    exit 0
  }
  $old = Get-Tunnel $proj.Key
  if ($old) { Stop-Process -Id $old.Id -Force -ErrorAction SilentlyContinue }
  Remove-Item $outFile, $errFile -ErrorAction SilentlyContinue
  $forwards = (0..9 | ForEach-Object { $lp = $lbase + $_; $rp = $proj.Base + $_; "-L 127.0.0.1:${lp}:127.0.0.1:${rp}" }) -join ' '
  $sshArgs = "-n -T -o BatchMode=yes -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 $forwards $SshHost `"start $($proj.Key)`""
  $tunnel = Start-Process ssh -ArgumentList $sshArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput $outFile -RedirectStandardError $errFile
  Set-Content -Path $pidFile -Value $tunnel.Id
  Write-Host "Starting the preview of $label (latest dev). The first start can take a few minutes."
  $deadline = (Get-Date).AddMinutes(15)
  $next = (Get-Date).AddSeconds(15)
  while ($true) {
    Start-Sleep -Seconds 2
    if ($tunnel.HasExited) {
      Write-Host "The preview did not start:"
      Get-Content $outFile, $errFile -ErrorAction SilentlyContinue | Where-Object { $_ -notlike 'in use *' } | ForEach-Object { Write-Host "  $_" }
      Write-Host "If a port is 'already in use', something on your computer uses $lbase-$($lbase + 9);"
      Write-Host "then try:  `$env:FACTORY_REVIEW_PORT_OFFSET = 10000; review $label start"
      Remove-Item $pidFile -ErrorAction SilentlyContinue
      exit 1
    }
    if (Test-Answers $probe) { break }
    if ((Get-Date) -gt $deadline) { Write-Host "Not up after 15 minutes; the tunnel is left open. Check: review $label status"; exit 1 }
    if ((Get-Date) -gt $next) { Write-Host "  still starting..."; $next = (Get-Date).AddSeconds(15) }
  }
  Show-Links
  Write-Host "The tunnel runs in the background; you can close this window."
  if (-not $NoBrowser) { Start-Process $app }
  exit 0
}

if ($Action -eq 'stop') {
  $t = Get-Tunnel $proj.Key
  if ($t) { Stop-Process -Id $t.Id -Force -ErrorAction SilentlyContinue; Write-Host "Tunnel to $label closed." }
  else { Write-Host "No tunnel to $label was open." }
  Remove-Item $pidFile -ErrorAction SilentlyContinue
  Write-Host "The server stops the preview 2 hours after the last tunnel closes."
  exit 0
}

$t = Get-Tunnel $proj.Key
Write-Host "Your tunnel to $label`: $(if ($t) { 'open' } else { 'closed' })"
Invoke-Gate "status $($proj.Key)" | ForEach-Object { Write-Host $_ }
exit 0
