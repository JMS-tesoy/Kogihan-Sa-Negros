$ErrorActionPreference = 'Stop'

$toolsPath = $PSScriptRoot
$screenshotsPath = Split-Path -Parent $toolsPath
$projectRoot = Split-Path -Parent $screenshotsPath
$outputPath = Join-Path $screenshotsPath 'home.png'

if (Test-Path $outputPath) {
  Remove-Item $outputPath -Force
}

Push-Location $projectRoot
try {
  flutter screenshot -o $outputPath
} finally {
  Pop-Location
}

Write-Host "Saved screenshot to $outputPath"
