# Runs one increment, verifies it (import + typecheck + tests + screenshots), reverts only if the
# GAME broke. Called by Task Scheduler (10:00 / 15:00 / 21:00, never Embermarch's 09/14/20).
# Safe to run by hand.  -Export adds the weekly Windows build.
param([switch]$Export)
$ErrorActionPreference = "Continue"
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repo

New-Item -ItemType Directory -Force -Path "$repo\logs" | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$log   = "$repo\logs\build-$stamp.log"
function Say($m) { $m | Out-File -Append -FilePath $log -Encoding utf8 }
"=== build start $stamp ===" | Out-File -FilePath $log -Encoding utf8
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { Say "console encoding unavailable: $_" }

# ---- outcome ledger + toast --------------------------------------------------------------------
$runsFile   = "$repo\logs\RUNS.tsv"
$statusFile = "$repo\BUILD_STATUS.md"

function Toast($title, $body) {
  try {
    $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    $null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
    $t = $title -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;'
    $b = $body  -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;'
    $xml = "<toast><visual><binding template=""ToastGeneric""><text>$t</text><text>$b</text></binding></visual></toast>"
    $doc = New-Object Windows.Data.Xml.Dom.XmlDocument
    $doc.LoadXml($xml)
    $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show((New-Object Windows.UI.Notifications.ToastNotification $doc))
  } catch { Say "toast failed: $_" }
}

function Outcome($status, $summary) {
  $now = Get-Date -Format "yyyy-MM-dd HH:mm"
  "$now`t$status`t$summary" | Out-File -Append -FilePath $runsFile -Encoding utf8
  $all = @(Get-Content $runsFile)
  $tail = $all | Select-Object -Last 12
  [array]::Reverse($tail)
  $okLines = @($all | Where-Object { $_ -match "`tok`t" })
  if ($okLines.Count -gt 0) { $lastOk = ($okLines | Select-Object -Last 1).Split("`t")[0] } else { $lastOk = "none yet" }
  $lines = @(
    "# BUILD STATUS", "",
    "Written by ``build.ps1`` at the end of every run. Do not edit by hand. A status other than ok",
    "fires a Windows toast. Full logs: ``logs\build-*.log`` (machine-local). Slots: 10:00, 15:00, 21:00.", "",
    "- **Last run:** $now - **$status** - $summary",
    "- **Last successful build:** $lastOk", "",
    "## Recent runs, newest first", ""
  ) + ($tail | ForEach-Object { "- " + ($_ -replace "`t", " - ") })
  ($lines -join "`r`n") + "`r`n" | Out-File -FilePath $statusFile -Encoding utf8
  Say "outcome: $status - $summary"
  if ($status -ne "ok") { Toast "Briarhold build: $status" $summary }
}

# ---- lock ----------------------------------------------------------------------------------------
$lockFile = "$repo\logs\build.lock"
if (Test-Path $lockFile) {
  $age = (Get-Date) - (Get-Item $lockFile).LastWriteTime
  if ($age.TotalMinutes -lt 90) {
    Outcome "skip" "another build already running (lock $([int]$age.TotalMinutes) min old)"
    exit 4
  }
  Remove-Item $lockFile -Force
}
"$PID $(Get-Date -Format o)" | Out-File -FilePath $lockFile -Encoding utf8

try {

# ---- preflight -----------------------------------------------------------------------------------
$required = @("CLAUDE.md","RUN.md","PROMPT.md","project.godot","tools\gate.ps1","tools\check.gd","tools\shot.gd","tools\shot.tscn",
  "00_MASTER_INSTRUCTIONS.md","02_SAVE_SCHEMA.md","03_CHANGELOG.md","04_BUILD_DOCTRINE.md","05_PLAYER_PROFILE.md",
  "06_VERDICTS.md","07_WORKBENCH.md","08_FOUNDATION.md","09_WISHLIST.md","11_RESOURCES.md","13_ENGINE_PRINCIPLES.md",
  "docs\ROADMAP.md","docs\design\CODEX.md","addons\gut\plugin.cfg","tests\fixtures\save-v1.json")
$missing = $required | Where-Object { -not (Test-Path (Join-Path $repo $_)) }
if ($missing.Count -gt 0) {
  Outcome "FAIL" ("preflight: missing " + ($missing -join ", ") + " - builder never started")
  exit 3
}

# ---- is the workstation locked? (LogonUI only runs while the lock screen is up) ------------------
function Locked { return [bool](Get-Process LogonUI -ErrorAction SilentlyContinue) }

# ---- the gate: 0 green, 1 game broken, 2 harness broken. Soft-gates the shot when locked. ------
function Gate {
  $locked = Locked
  if ($locked) { Say "workstation locked: shot soft-gated this run" }
  if ($locked) { pwsh -NoProfile -File "$repo\tools\gate.ps1" -NoShot 2>&1 | Out-File -Append $log -Encoding utf8 }
  else         { pwsh -NoProfile -File "$repo\tools\gate.ps1"         2>&1 | Out-File -Append $log -Encoding utf8 }
  $code = $LASTEXITCODE
  if ($locked -and $code -eq 0) { "pending" | Out-File "$repo\logs\shot-pending" -Encoding utf8 }
  Say "gate exit=$code locked=$locked"
  return $code
}

# ---- a shot owed from a locked run? take it now before building --------------------------------
if ((Test-Path "$repo\logs\shot-pending") -and -not (Locked)) {
  Say "re-shooting a pending screenshot from a locked run"
  pwsh -NoProfile -File "$repo\tools\gate.ps1" 2>&1 | Out-File -Append $log -Encoding utf8
  if ($LASTEXITCODE -eq 0) { Remove-Item "$repo\logs\shot-pending" -Force }
}

$before = Gate
if ($before -eq 2) { Outcome "FAIL" "harness cannot gate at baseline (exit 2); builder never started"; exit 2 }

# never build on top of uncommitted work
if (Test-Path "$repo\.git") {
  $dirty = git status --porcelain 2>$null
  if ($dirty) {
    git add -A 2>&1 | Out-File -Append $log -Encoding utf8
    git commit -m "wip: uncommitted work preserved before build $stamp" 2>&1 | Out-File -Append $log -Encoding utf8
  }
}

# ---- the builder --------------------------------------------------------------------------------
$instruction = Get-Content -Raw "$repo\PROMPT.md"
$preSha = (git rev-parse HEAD 2>$null)
Say "pre-run HEAD: $preSha"
$clBefore = (Get-FileHash "$repo\03_CHANGELOG.md").Hash
$bnBefore = (Get-FileHash "$repo\BUILD_NOTE.md").Hash
$rmBefore = (Get-FileHash "$repo\docs\ROADMAP.md").Hash
$frozen = @("build.ps1","tools\gate.ps1")
$frozenBefore = @{}
foreach ($f in $frozen) { $frozenBefore[$f] = (Get-FileHash "$repo\$f").Hash }

Say "--- claude ---"
claude -p $instruction --permission-mode acceptEdits --allowedTools "Read,Write,Edit,Glob,Grep,Bash" *>> $log
$claudeExit = $LASTEXITCODE
Say "claude exit=$claudeExit"

$note = ""
foreach ($f in $frozen) {
  if ((Get-FileHash "$repo\$f").Hash -ne $frozenBefore[$f]) {
    Say "TRIPWIRE: builder touched frozen $f. reverting that file."
    git checkout $preSha -- $f 2>&1 | Out-File -Append $log -Encoding utf8
    $note += " [frozen $f touched - reverted]"
  }
}

# ---- verify ---------------------------------------------------------------------------------------
$after = Gate
if ($after -eq 2) {
  $note += " (unverified: harness failure)"
} elseif ($after -eq 1 -and $before -eq 0) {
  Say "GAME BROKEN by this run. reverting to pre-run commit $preSha."
  git checkout $preSha -- sim game content tests tools project.godot 03_CHANGELOG.md 07_WORKBENCH.md BUILD_NOTE.md 06_VERDICTS.md 05_PLAYER_PROFILE.md docs/ROADMAP.md 2>&1 | Out-File -Append $log -Encoding utf8
  git clean -fd -- sim game content tests 2>&1 | Out-File -Append $log -Encoding utf8
  $note += " (REVERTED: this run broke the game)"
} elseif ($after -eq 1 -and $before -eq 1) {
  $note += " (still broken, pre-existing)"
}

$docTouched = ((Get-FileHash "$repo\03_CHANGELOG.md").Hash -ne $clBefore)
$noteTouched = ((Get-FileHash "$repo\BUILD_NOTE.md").Hash -ne $bnBefore)
$mapTouched = ((Get-FileHash "$repo\docs\ROADMAP.md").Hash -ne $rmBefore)
if (-not $docTouched)  { $note += " [undocumented]" }
if (-not $noteTouched) { Say "WARNING: BUILD_NOTE.md not updated." }
if (-not $mapTouched -and $after -eq 0) { Say "note: docs/ROADMAP.md unchanged (fine for a fix run)." }

# ---- weekly export ---------------------------------------------------------------------------------
if ($Export -and $after -eq 0) {
  pwsh -NoProfile -File "$repo\tools\gate.ps1" -NoShot -Export 2>&1 | Out-File -Append $log -Encoding utf8
  if ($LASTEXITCODE -ne 0) { $note += " [export failed]" } else { Say "export ok" }
}

$status = "ok"; $summary = "build verified and committed"
if ($after -eq 2) { $status = "WARN"; $summary = "verify harness failure; game left alone, unverified" }
elseif ($after -eq 1 -and $before -eq 0) { $status = "FAIL"; $summary = "run broke the game; reverted to pre-run commit" }
elseif ($after -eq 1 -and $before -eq 1) { $status = "FAIL"; $summary = "game broken before and after this run" }
if (Locked -and $status -eq "ok") { $summary += "; visuals unverified (locked)" }
if ($claudeExit -ne 0) { if ($status -eq "ok") { $status = "WARN" }; $summary += "; builder exited $claudeExit" }
if (-not $docTouched)  { if ($status -eq "ok") { $status = "WARN" }; $summary += "; changelog not updated" }
if ($note -match "frozen") { if ($status -eq "ok") { $status = "WARN" }; $summary += "; frozen-file edit reverted" }
Outcome $status $summary

Get-Date -Format "yyyy-MM-dd" | Out-File "$repo\BUILD_STAMP.txt" -Encoding ascii
if (Test-Path "$repo\.git") {
  git add -A 2>&1 | Out-File -Append $log -Encoding utf8
  git commit -m "build $stamp$note" 2>&1 | Out-File -Append $log -Encoding utf8
}
"=== build end $(Get-Date -Format 'yyyyMMdd-HHmmss') before=$before after=$after ===" | Out-File -Append -FilePath $log -Encoding utf8
}
catch {
  Outcome "FAIL" ("build script crashed: " + $_.Exception.Message)
  exit 5
}
finally {
  if (Test-Path $lockFile) { Remove-Item $lockFile -Force }
}
