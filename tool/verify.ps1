[CmdletBinding()]
param(
  [switch]$BuildInstaller,
  [string]$InnoCompiler,
  [string]$VcRedistSource
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$expectedFlutterVersion =
  (Get-Content -Raw (Join-Path $repoRoot '.fvmrc') | ConvertFrom-Json).flutter

function Invoke-Native {
  param(
    [Parameter(Mandatory)] [string]$Executable,
    [Parameter(Mandatory)] [string[]]$Arguments
  )

  & $Executable @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$Executable $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
  }
}

function Invoke-PackageVerification {
  param(
    [Parameter(Mandatory)] [string]$Name,
    [Parameter(Mandatory)] [string]$Path,
    [Parameter(Mandatory)] [string]$Executable
  )

  Write-Host "`n==> $Name"
  $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
  Push-Location $Path
  try {
    Invoke-Native $Executable @('pub', 'get')
    Invoke-Native $Executable @('analyze')
    Invoke-Native $Executable @('test')
  } finally {
    Pop-Location
    $stopwatch.Stop()
  }
  Write-Host "<== $Name passed in $([Math]::Round($stopwatch.Elapsed.TotalSeconds, 1))s"
}

$flutterInfo = Invoke-Native 'flutter' @('--version', '--machine') |
  ConvertFrom-Json
if ($flutterInfo.frameworkVersion -ne $expectedFlutterVersion) {
  throw "Flutter $expectedFlutterVersion is required; found $($flutterInfo.frameworkVersion)."
}

$dartVersionOutput = (Invoke-Native 'dart' @('--version') 2>&1 | Out-String)
if ($dartVersionOutput -notmatch 'Dart SDK version: (?<version>\d+\.\d+\.\d+)') {
  throw "Could not determine the Dart SDK version: $dartVersionOutput"
}
if ([version]$Matches.version -lt [version]'3.7.0') {
  throw "Dart 3.7.0 or newer is required; found $($Matches.version)."
}

Invoke-PackageVerification 'core' (Join-Path $repoRoot 'core') 'dart'
Invoke-PackageVerification 'server' (Join-Path $repoRoot 'server') 'dart'
Invoke-PackageVerification 'mcp' (Join-Path $repoRoot 'mcp') 'dart'
Invoke-PackageVerification 'app' (Join-Path $repoRoot 'app') 'flutter'

if ($BuildInstaller) {
  if (-not $IsWindows) {
    throw 'The Windows installer can only be built on Windows.'
  }

  Write-Host "`n==> Windows installer"
  Push-Location (Join-Path $repoRoot 'app')
  try {
    Invoke-Native 'flutter' @('build', 'windows', '--release')
  } finally {
    Pop-Location
  }

  $sqlcipherLibrary =
    Join-Path $repoRoot 'app\build\windows\x64\runner\Release\sqlite3.dll'
  if (-not (Test-Path -LiteralPath $sqlcipherLibrary)) {
    throw "The Windows build did not produce $sqlcipherLibrary."
  }
  $env:KANGOOS_SQLCIPHER_LIBRARY = $sqlcipherLibrary
  Push-Location (Join-Path $repoRoot 'core')
  try {
    Invoke-Native 'dart' @(
      'test',
      'test/encrypted_database_upgrade_test.dart',
      '--reporter',
      'expanded'
    )
  } finally {
    Remove-Item Env:KANGOOS_SQLCIPHER_LIBRARY
    Pop-Location
  }

  if ([string]::IsNullOrWhiteSpace($InnoCompiler)) {
    $InnoCompiler = @(
      (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
      (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
  }
  if ([string]::IsNullOrWhiteSpace($InnoCompiler)) {
    throw 'Inno Setup 6 was not found. Pass -InnoCompiler with the ISCC.exe path.'
  }

  if ([string]::IsNullOrWhiteSpace($VcRedistSource)) {
    $VcRedistSource = @(
      (Join-Path $env:TEMP 'vc_redist.x64.exe'),
      (Join-Path $env:USERPROFILE 'Downloads\vc_redist.x64.exe')
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
  }
  if ([string]::IsNullOrWhiteSpace($VcRedistSource)) {
    throw 'vc_redist.x64.exe was not found. Pass -VcRedistSource with its path.'
  }

  $installerScript = Join-Path $repoRoot 'app\windows\installer\kangoos.iss'
  Invoke-Native $InnoCompiler @(
    "/DVcRedistSource=$((Resolve-Path -LiteralPath $VcRedistSource).Path)",
    $installerScript
  )
}

Write-Host "`nKangoOS verification passed."
