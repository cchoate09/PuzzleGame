param(
  [string]$GodotConsolePath = $env:GODOT_CONSOLE_PATH
)

function Find-GodotConsole {
  param([string]$ExplicitPath)

  if ($ExplicitPath -and (Test-Path $ExplicitPath)) {
    return $ExplicitPath
  }

  $pathMatches = Get-Command godot_console.exe -ErrorAction SilentlyContinue
  if ($pathMatches) {
    return $pathMatches.Source
  }

  $packagesRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
  if (-not (Test-Path $packagesRoot)) {
    return $null
  }

  $matches = Get-ChildItem $packagesRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "GodotEngine.GodotEngine*" } |
    ForEach-Object { Get-ChildItem $_.FullName -Filter "Godot_v*_console.exe" -ErrorAction SilentlyContinue } |
    Sort-Object FullName -Descending

  return $matches[0].FullName
}

$godotConsole = Find-GodotConsole -ExplicitPath $GodotConsolePath
if (-not $godotConsole) {
  throw "Unable to locate a Godot console executable. Install Godot first or set GODOT_CONSOLE_PATH."
}

$versionOutput = & $godotConsole --version
$version = [regex]::Match($versionOutput, '\d+\.\d+\.\d+\.stable').Value
if (-not $version) {
  throw "Unable to parse a stable Godot version from '$versionOutput'."
}

$releaseTag = $version -replace '\.stable$', '-stable'
$downloadUrl = "https://github.com/godotengine/godot/releases/download/$releaseTag/Godot_v$releaseTag" + "_export_templates.tpz"
$cacheDir = Join-Path (Resolve-Path ".").Path "output\godot-templates"
$tpzPath = Join-Path $cacheDir "Godot_v$releaseTag" + "_export_templates.tpz"
$zipPath = Join-Path $cacheDir "templates.zip"
$unzipPath = Join-Path $cacheDir "unzipped"
$targetDir = Join-Path $env:APPDATA "Godot\export_templates\$version"

New-Item -ItemType Directory -Force $cacheDir | Out-Null
curl.exe -L $downloadUrl -o $tpzPath
Copy-Item $tpzPath $zipPath -Force
Remove-Item -Recurse -Force $unzipPath -ErrorAction SilentlyContinue
Expand-Archive -Path $zipPath -DestinationPath $unzipPath -Force
New-Item -ItemType Directory -Force $targetDir | Out-Null
Copy-Item (Join-Path $unzipPath "templates\*") $targetDir -Recurse -Force

Write-Output "Installed Godot export templates for $version to $targetDir"
