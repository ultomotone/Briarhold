# Package the exported builds for sharing:  pwsh tools\package.ps1
# Run after `pwsh tools\gate.ps1 -Export`. Makes, in build\:
#   Briarhold-windows.zip      Briarhold.exe + HOW_TO_PLAY.txt
#   Briarhold-linux.tar.gz     Briarhold.x86_64 (executable bit set) + HOW_TO_PLAY.txt, if the
#                              Linux build exists
# Optional:  -Release v0.2   also publishes both to a GitHub Release with that tag (needs gh).
param([string]$Release = "")
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$build = Join-Path $repo "build"
$note = Join-Path $repo "docs\HOW_TO_PLAY.txt"
$made = @()

$exe = Join-Path $build "Briarhold.exe"
if (-not (Test-Path $exe)) { Write-Host "no build\Briarhold.exe: run  pwsh tools\gate.ps1 -Export  first"; exit 1 }
$stage = Join-Path $build "pkg-windows"
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $stage | Out-Null
Copy-Item $exe, $note $stage
$zip = Join-Path $build "Briarhold-windows.zip"
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zip -Force
Remove-Item $stage -Recurse -Force
$made += $zip

$bin = Join-Path $build "linux\Briarhold.x86_64"
if (Test-Path $bin) {
  # GNU tar from Git for Windows, so the binary keeps an executable bit inside the archive
  $tar = "C:\Program Files\Git\usr\bin\tar.exe"
  if (-not (Test-Path $tar)) { Write-Host "no GNU tar at $tar (Git for Windows); skipping Linux"; }
  else {
    Copy-Item $note (Join-Path $build "linux\HOW_TO_PLAY.txt") -Force
    $tgz = Join-Path $build "Briarhold-linux.tar.gz"
    Push-Location (Join-Path $build "linux")
    & $tar --mode="a+rx" -czf "../Briarhold-linux.tar.gz" "Briarhold.x86_64" "HOW_TO_PLAY.txt"
    Pop-Location
    $made += $tgz
  }
} else {
  Write-Host "no Linux build (build\linux\Briarhold.x86_64); Windows only"
}

foreach ($f in $made) { Write-Host ("{0}  {1} MB" -f (Split-Path $f -Leaf), [math]::Round((Get-Item $f).Length / 1MB, 1)) }

if ($Release) {
  gh release create $Release @made --title "Briarhold $Release" --notes "Windows: unzip and run Briarhold.exe. Linux: tar -xzf, then ./Briarhold.x86_64. See HOW_TO_PLAY.txt inside."
}
