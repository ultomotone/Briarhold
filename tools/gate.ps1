# The gate, by hand or from build.ps1:  pwsh tools\gate.ps1 [-NoShot] [-Export]
# import -> check (typecheck) -> tests -> shot (screenshot, windowed) [-> export]
# Exit 0 green · 1 the game is broken · 2 the harness is broken. Logs in logs\.
param([switch]$NoShot, [switch]$Export)
$ErrorActionPreference = "Continue"
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo
New-Item -ItemType Directory -Force -Path "$repo\logs" | Out-Null

function Find-Godot {
  if ($env:GODOT -and (Test-Path $env:GODOT)) { return $env:GODOT }
  $pk = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Directory -Filter "GodotEngine.GodotEngine_*" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($pk) {
    $c = Get-ChildItem $pk.FullName -Filter "Godot_v4*_console.exe" | Select-Object -First 1
    if ($c) { return $c.FullName }
  }
  $g = Get-Command godot_console -ErrorAction SilentlyContinue
  if ($g) { return $g.Source }
  $g = Get-Command godot -ErrorAction SilentlyContinue
  if ($g) { return $g.Source }
  return $null
}
$godot = Find-Godot
if (-not $godot) { Write-Host "GATE 2 godot not found (set `$env:GODOT)"; exit 2 }
Write-Host "godot: $godot"

function Run($label, $argv, $log) {
  if (Test-Path $log) { Remove-Item $log -Force }
  $p = Start-Process -FilePath $godot -ArgumentList $argv -NoNewWindow -PassThru -Wait -RedirectStandardOutput "$log.out" -RedirectStandardError "$log.err"
  $code = $p.ExitCode
  Get-Content "$log.out","$log.err" -ErrorAction SilentlyContinue | Out-File $log -Encoding utf8
  Remove-Item "$log.out","$log.err" -Force -ErrorAction SilentlyContinue
  $errs = @(Select-String -Path $log -Pattern 'SCRIPT ERROR|USER ERROR|^ERROR:|Parse Error|Parser Error' -ErrorAction SilentlyContinue)
  Write-Host ("{0}: exit={1} script-errors={2}" -f $label, $code, $errs.Count)
  foreach ($e in ($errs | Select-Object -First 12)) { Write-Host ("  " + $e.Line.Trim()) }
  return @{ code = $code; errs = $errs.Count }
}

# 1. import (populates .godot/ and the class_name cache). A cold cache cannot resolve class_name
# references from the autoloads on the first pass, so a cold tree imports twice and only the
# second pass is judged.
if (-not (Test-Path ".godot\global_script_class_cache.cfg")) {
  Run "import (cold cache)" @("--headless","--path",".","--import") "logs\import-cold.log" | Out-Null
}
$r = Run "import" @("--headless","--path",".","--import") "logs\import.log"
if ($r.errs -gt 0) { Write-Host "GATE 1 import produced script errors"; exit 1 }

# 2. typecheck
$r = Run "check" @("--headless","--path",".","-s","res://tools/check.gd") "logs\check.log"
if ($r.code -ne 0 -or $r.errs -gt 0) { Write-Host "GATE 1 check failed"; exit 1 }

# 3. tests
$r = Run "tests" @("--headless","--path",".","-s","res://addons/gut/gut_cmdln.gd","-gdir=res://tests/unit","-ginclude_subdirs","-gexit","-glog=1") "logs\tests.log"
$summary = Select-String -Path "logs\tests.log" -Pattern '^\s*(Passing|Failing|Tests|Asserts)' -ErrorAction SilentlyContinue | ForEach-Object { $_.Line.Trim() }
$summary | ForEach-Object { Write-Host "  $_" }
if ($r.code -ne 0 -or $r.errs -gt 0) { Write-Host "GATE 1 tests failed"; exit 1 }

# 4. shot (needs a display; soft-gated by build.ps1 when the workstation is locked)
if (-not $NoShot) {
  if (Test-Path "logs\latest-desktop.png") { Remove-Item "logs\latest-desktop.png" -Force }
  $p = Start-Process -FilePath $godot -ArgumentList @("--path",".","--rendering-method","forward_plus","--windowed","--resolution","1600x900","--position","0,0","--log-file","logs/shot.log","res://tools/shot.tscn") -PassThru
  $done = $p | Wait-Process -Timeout 150 -ErrorAction SilentlyContinue
  if (-not $p.HasExited) { $p | Stop-Process -Force; Write-Host "GATE 2 shot timed out"; exit 2 }
  $errs = @(Select-String -Path "logs\shot.log" -Pattern 'SCRIPT ERROR|USER ERROR|^ERROR:' -ErrorAction SilentlyContinue)
  Write-Host ("shot: exit={0} script-errors={1}" -f $p.ExitCode, $errs.Count)
  foreach ($e in ($errs | Select-Object -First 12)) { Write-Host ("  " + $e.Line.Trim()) }
  if ($p.ExitCode -eq 2) { Write-Host "GATE 2 shot harness broken"; exit 2 }
  if ($p.ExitCode -ne 0 -or $errs.Count -gt 0 -or -not (Test-Path "logs\latest-desktop.png")) { Write-Host "GATE 1 shot failed"; exit 1 }
}

# 5. export (weekly; needs templates in %APPDATA%\Godot\export_templates\4.7.2.stable)
if ($Export) {
  New-Item -ItemType Directory -Force -Path "$repo\build" | Out-Null
  $r = Run "export" @("--headless","--path",".","--export-release","`"Windows Desktop`"","build/Briarhold.exe") "logs\export.log"
  $exe = Get-Item "build\Briarhold.exe" -ErrorAction SilentlyContinue
  if (-not $exe -or $exe.Length -lt 20MB -or $r.errs -gt 0) { Write-Host "GATE 1 export failed"; exit 1 }
  Write-Host ("export: {0} MB" -f [math]::Round($exe.Length / 1MB))
}

Write-Host "GATE 0 green"
exit 0
