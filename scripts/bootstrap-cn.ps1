param(
  [switch]$InitPm,
  [switch]$AutoInstallMissing,
  [switch]$InstallPython,
  [switch]$InstallGit,
  [switch]$InstallGodot,
  [switch]$InstallNode,
  [switch]$InstallExportTemplates,
  [switch]$InstallQualityTools
)

$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$ToolsDir = Join-Path $Root "tools"

function Write-Ok {
  param([string]$Message)
  Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warn {
  param([string]$Message)
  Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Fail {
  param([string]$Message)
  Write-Host "[FAIL] $Message" -ForegroundColor Red
}

function Write-Info {
  param([string]$Message)
  Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Add-PathForCurrentProcess {
  param([string]$PathToAdd)
  if ($PathToAdd -and (Test-Path -LiteralPath $PathToAdd) -and ($env:PATH -notlike "*$PathToAdd*")) {
    $env:PATH = "$PathToAdd;$env:PATH"
  }
}

function Find-FirstToolFile {
  param([string[]]$Patterns)

  if (-not (Test-Path -LiteralPath $ToolsDir)) {
    return ""
  }

  foreach ($pattern in $Patterns) {
    $match = Get-ChildItem -Path $ToolsDir -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue |
      Sort-Object FullName |
      Select-Object -First 1
    if ($match) {
      return $match.FullName
    }
  }

  return ""
}

function Find-LocalPython {
  $candidates = @(
    (Join-Path $ToolsDir "python/python.exe"),
    (Join-Path $ToolsDir "python3/python.exe"),
    (Join-Path $ToolsDir "python.exe")
  )

  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
      return $candidate
    }
  }

  return ""
}

function Find-Python {
  $local = Find-LocalPython
  if ($local) {
    return $local
  }

  $cmd = Get-Command python -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) {
    return $cmd.Source
  }

  $py = Get-Command py -ErrorAction SilentlyContinue
  if ($py -and $py.Source) {
    return $py.Source
  }

  return ""
}

function Find-LocalGit {
  $candidates = @(
    (Join-Path $ToolsDir "git/cmd/git.exe"),
    (Join-Path $ToolsDir "git/bin/git.exe"),
    (Join-Path $ToolsDir "PortableGit/cmd/git.exe")
  )

  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
      return $candidate
    }
  }

  return ""
}

function Find-LocalNode {
  $candidates = @(
    (Join-Path $ToolsDir "node/node.exe"),
    (Join-Path $ToolsDir "node/bin/node.exe"),
    (Join-Path $ToolsDir "nodejs/node.exe")
  )

  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
      return $candidate
    }
  }

  return ""
}

function Find-Node {
  $local = Find-LocalNode
  if ($local) {
    return $local
  }

  $cmd = Get-Command node -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) {
    return $cmd.Source
  }

  return ""
}

function Find-Npx {
  $candidates = @(
    (Join-Path $ToolsDir "node/npx.cmd"),
    (Join-Path $ToolsDir "node/npx.exe"),
    (Join-Path $ToolsDir "node/bin/npx")
  )

  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
      return $candidate
    }
  }

  $cmd = Get-Command npx -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) {
    return $cmd.Source
  }

  return ""
}

function Find-Git {
  $local = Find-LocalGit
  if ($local) {
    return $local
  }

  $cmd = Get-Command git -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) {
    return $cmd.Source
  }

  return ""
}

function Find-LocalGodot {
  $found = Find-FirstToolFile -Patterns @("Godot*console*.exe", "godot*console*.exe", "Godot*.exe", "godot*.exe")
  if ($found) {
    return $found
  }

  return ""
}

function Find-Godot {
  $local = Find-LocalGodot
  if ($local) {
    return $local
  }

  if ($env:GODOT4_PATH -and (Test-Path -LiteralPath $env:GODOT4_PATH)) {
    return $env:GODOT4_PATH
  }

  $cmd = Get-Command godot4 -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) {
    return $cmd.Source
  }

  $cmd = Get-Command godot -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) {
    return $cmd.Source
  }

  return ""
}

function Get-GodotTemplateVersion {
  $godot = Find-Godot
  if ($godot) {
    try {
      $versionText = (& $godot --version 2>$null | Select-Object -First 1).ToString().Trim()
      if ($versionText -match "^(\d+\.\d+(?:\.\d+)?\.[^.]+)") {
        return $Matches[1]
      }
    } catch {
    }
  }

  $tpz = Find-FirstToolFile -Patterns @("Godot_v*_export_templates.tpz", "*export_templates*.tpz")
  if ($tpz -and ([System.IO.Path]::GetFileName($tpz) -match "Godot_v(\d+\.\d+(?:\.\d+)?)-([A-Za-z]+)_export_templates")) {
    return "$($Matches[1]).$($Matches[2])"
  }

  return ""
}

function Test-ExportTemplatesInstalled {
  param([string]$TemplateVersion)

  if (-not $env:APPDATA) {
    return $false
  }

  $targetRoot = Join-Path $env:APPDATA "Godot/export_templates"
  if (-not (Test-Path -LiteralPath $targetRoot)) {
    return $false
  }

  $dirs = @()
  if ($TemplateVersion) {
    $versionDir = Join-Path $targetRoot $TemplateVersion
    if (Test-Path -LiteralPath $versionDir) {
      $dirs += Get-Item -LiteralPath $versionDir
    }
  } else {
    $dirs += Get-ChildItem -Path $targetRoot -Directory -ErrorAction SilentlyContinue
  }

  foreach ($dir in $dirs) {
    $hasWeb = Test-Path -LiteralPath (Join-Path $dir.FullName "web_nothreads_release.zip")
    $hasWebThreads = Test-Path -LiteralPath (Join-Path $dir.FullName "web_release.zip")
    if ($hasWeb -or $hasWebThreads) {
      return $true
    }
  }

  return $false
}

function Prepare-PythonFromTools {
  if (Find-LocalPython) {
    return $true
  }

  $archive = Find-FirstToolFile -Patterns @("python-*-embed-amd64.zip", "python-*-embed-win32.zip")
  if (-not $archive) {
    Write-Warn "Python portable archive not found under tools/."
    return $false
  }

  $target = Join-Path $ToolsDir "python"
  New-Item -ItemType Directory -Force -Path $target | Out-Null
  Write-Info "Extracting portable Python to tools/python: $archive"
  Expand-Archive -LiteralPath $archive -DestinationPath $target -Force
  return [bool](Find-Python)
}

function Prepare-GitFromTools {
  if (Find-LocalGit) {
    return $true
  }

  $archive = Find-FirstToolFile -Patterns @("PortableGit-*-64-bit.7z.exe", "PortableGit-*.7z.exe")
  if (-not $archive) {
    Write-Warn "PortableGit archive not found under tools/."
    return $false
  }

  $target = Join-Path $ToolsDir "git"
  New-Item -ItemType Directory -Force -Path $target | Out-Null
  Write-Info "Extracting PortableGit to tools/git: $archive"
  $process = Start-Process -FilePath $archive -ArgumentList @("-y", "-o$target") -Wait -PassThru
  if ($process.ExitCode -ne 0) {
    Write-Warn "PortableGit extraction failed with exit code $($process.ExitCode)."
    return $false
  }

  return [bool](Find-Git)
}

function Prepare-NodeFromTools {
  if (Find-LocalNode) {
    return $true
  }

  $archive = Find-FirstToolFile -Patterns @("node-v*-win-x64.zip", "node-v*-win-x86.zip", "node-v*-windows*.zip")
  if (-not $archive) {
    Write-Warn "Node.js portable archive not found under tools/."
    return $false
  }

  $target = Join-Path $ToolsDir "node"
  $temp = Join-Path ([System.IO.Path]::GetTempPath()) ("node-portable-" + [System.Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $target | Out-Null
  New-Item -ItemType Directory -Force -Path $temp | Out-Null

  try {
    Write-Info "Extracting portable Node.js to tools/node: $archive"
    Expand-Archive -LiteralPath $archive -DestinationPath $temp -Force
    $nodeExe = Get-ChildItem -Path $temp -Recurse -File -Filter "node.exe" -ErrorAction SilentlyContinue |
      Sort-Object FullName |
      Select-Object -First 1
    if (-not $nodeExe) {
      Write-Warn "Node.js archive structure is not recognized."
      return $false
    }

    $sourceRoot = $nodeExe.Directory.FullName
    Copy-Item -Path (Join-Path $sourceRoot "*") -Destination $target -Recurse -Force
    return [bool](Find-Node)
  } finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Prepare-GodotFromTools {
  if (Find-LocalGodot) {
    return $true
  }

  $archive = Find-FirstToolFile -Patterns @("Godot_v4*_win64.exe.zip", "Godot_v4*_win64.zip", "Godot_v4*_windows*.zip")
  $target = Join-Path $ToolsDir "godot"
  New-Item -ItemType Directory -Force -Path $target | Out-Null

  if ($archive) {
    Write-Info "Extracting Godot to tools/godot: $archive"
    Expand-Archive -LiteralPath $archive -DestinationPath $target -Force
    return [bool](Find-Godot)
  }

  $exe = Find-FirstToolFile -Patterns @(
    "Godot_v4*_win64_console.exe",
    "Godot*console*.exe",
    "Godot_v4*_win64.exe",
    "Godot_v4*_windows*.exe",
    "Godot*.exe"
  )
  if ($exe) {
    Write-Ok "Godot executable found: $exe"
    return $true
  }

  Write-Warn "Godot portable archive or executable not found under tools/."
  return $false
}

function Prepare-ExportTemplatesFromTools {
  $marker = Join-Path $Root ".godot-export-templates-ready"
  $templateVersion = Get-GodotTemplateVersion
  if (Test-ExportTemplatesInstalled -TemplateVersion $templateVersion) {
    Write-Ok "Export Templates already installed."
    Set-Content -Path $marker -Value "ok" -Encoding UTF8
    return $true
  }

  if (-not $env:APPDATA) {
    Write-Warn "APPDATA is not set. Install Export Templates from the Godot editor."
    return $false
  }

  $tpz = Find-FirstToolFile -Patterns @("Godot_v4*_export_templates.tpz", "*export_templates*.tpz", "*export_templates*.zip")
  if (-not $tpz) {
    Write-Warn "Export Templates package not found under tools/."
    return $false
  }

  $targetRoot = Join-Path $env:APPDATA "Godot/export_templates"
  $temp = Join-Path ([System.IO.Path]::GetTempPath()) ("godot-export-templates-" + [System.Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $temp | Out-Null

  try {
    $zipPath = Join-Path $temp "templates.zip"
    Copy-Item -LiteralPath $tpz -Destination $zipPath -Force
    Expand-Archive -LiteralPath $zipPath -DestinationPath $temp -Force

    $templateDirs = @()
    foreach ($dir in (Get-ChildItem -Path $temp -Recurse -Directory)) {
      $hasWeb = Test-Path -LiteralPath (Join-Path $dir.FullName "web_release.zip")
      $hasWebDlink = Test-Path -LiteralPath (Join-Path $dir.FullName "web_dlink_release.zip")
      $hasAndroid = Test-Path -LiteralPath (Join-Path $dir.FullName "template_release.apk")
      if ($hasWeb -or $hasWebDlink -or $hasAndroid) {
        $templateDirs += $dir
      }
    }

    if ($templateDirs.Count -eq 0) {
      Write-Warn "Export Templates package structure is not recognized. Use Godot editor installation instead."
      return $false
    }

    New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null
    foreach ($dir in $templateDirs) {
      $targetName = $dir.Name
      if ($targetName -eq "templates" -and $templateVersion) {
        $targetName = $templateVersion
      }
      $target = Join-Path $targetRoot $targetName
      New-Item -ItemType Directory -Force -Path $target | Out-Null
      Copy-Item -Path (Join-Path $dir.FullName "*") -Destination $target -Recurse -Force
      Write-Ok "Export Templates installed: $targetName"
    }

    Set-Content -Path $marker -Value "ok" -Encoding UTF8
    return $true
  } finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Run-Python {
  param(
    [string]$PythonExe,
    [string[]]$ScriptArgs
  )

  if (-not $PythonExe) {
    Write-Fail "Python was not found. Cannot run project scripts."
    $script:RunPythonExitCode = 1
    return
  }

  & $PythonExe @ScriptArgs
  $script:RunPythonExitCode = $LASTEXITCODE
}

Set-Location -LiteralPath $Root
New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null

Write-Info "Godot V1 Plus bootstrap"
Write-Info "Tool priority: tools/ portable archives > extracted tools > system PATH"

if ($AutoInstallMissing -or $InstallPython) {
  Prepare-PythonFromTools | Out-Null
}
$python = Find-Python
if ($python) {
  Write-Ok "Python: $python"
  Add-PathForCurrentProcess -PathToAdd (Split-Path -Parent $python)
} else {
  Write-Warn "Python was not found."
}

if ($AutoInstallMissing -or $InstallGit) {
  Prepare-GitFromTools | Out-Null
}
$git = Find-Git
if ($git) {
  Write-Ok "Git: $git"
  Add-PathForCurrentProcess -PathToAdd (Split-Path -Parent $git)
} else {
  Write-Warn "Git was not found."
}

if ($AutoInstallMissing -or $InstallNode) {
  Prepare-NodeFromTools | Out-Null
}
$node = Find-Node
if ($node) {
  Write-Ok "Node.js: $node"
  Add-PathForCurrentProcess -PathToAdd (Split-Path -Parent $node)
  $npx = Find-Npx
  if ($npx) {
    Write-Ok "npx: $npx"
  }
} else {
  Write-Warn "Node.js was not found."
}

if ($AutoInstallMissing -or $InstallGodot) {
  Prepare-GodotFromTools | Out-Null
}
$godot = Find-Godot
if ($godot) {
  Write-Ok "Godot: $godot"
  $env:GODOT4_PATH = $godot
} else {
  Write-Warn "Godot was not found."
}

if ($AutoInstallMissing -or $InstallExportTemplates) {
  Prepare-ExportTemplatesFromTools | Out-Null
}

if ($InitPm -and $python) {
  Run-Python -PythonExe $python -ScriptArgs @(".agents/skills/pm-agile/scripts/pm_cli.py", "init-backlog") | Out-Null
}

if ($python) {
  Write-Info "Configuring project AI MCP clients"
  & $python "scripts/setup_ai_mcp.py" "--apply-project"
  if ($LASTEXITCODE -ne 0) {
    Write-Warn "Project AI MCP configuration did not complete. You can retry with: python scripts/setup_ai_mcp.py --apply-project"
  }
}

if ($InstallQualityTools -and $python) {
  Write-Warn "Installing quality tools will download Python packages and (optionally) GDUnit4 addon into this project."
  Run-Python -PythonExe $python -ScriptArgs @("scripts/setup_quality_tools.py", "--install", "--yes") | Out-Null
  if ($script:RunPythonExitCode -ne 0) {
    exit $script:RunPythonExitCode
  }
}

if ($python) {
  Run-Python -PythonExe $python -ScriptArgs @("scripts/check_env.py", "--json")
  exit $script:RunPythonExitCode
}

exit 1
