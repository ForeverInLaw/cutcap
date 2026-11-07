<#
.SYNOPSIS
  Compiles the Windows installer, build/installer/cutcap-setup-x.y.z.exe,
  from an existing `flutter build windows --release`.

.DESCRIPTION
  The version is pubspec.yaml's x.y.z (the +build part is dropped).
  ffmpeg.exe and ffprobe.exe come from -FFmpegDir; when they are not there
  yet, tool/fetch_ffmpeg.ps1 fetches them. ISCC is -Iscc, else ISCC.exe on
  PATH, else a per-user or machine-wide Inno Setup 6. Prints the path of
  the installer it wrote.

.EXAMPLE
  flutter build windows --release
  pwsh tool/build_installer.ps1
#>
param(
  [string] $Iscc,
  [string] $FFmpegDir = 'build/ffmpeg'
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

$match = Select-String -Path (Join-Path $root 'pubspec.yaml') -Pattern '^version:\s*(\d+\.\d+\.\d+)'
if (-not $match) { throw 'No x.y.z version in pubspec.yaml' }
$version = $match.Matches[0].Groups[1].Value

$release = Join-Path $root 'build/windows/x64/runner/Release'
if (-not (Test-Path (Join-Path $release 'cutcap.exe'))) {
  throw "No release build in $release; run 'flutter build windows --release' first"
}

$ffmpeg = if ([System.IO.Path]::IsPathRooted($FFmpegDir)) { $FFmpegDir } else { Join-Path $root $FFmpegDir }
if (-not ((Test-Path (Join-Path $ffmpeg 'ffmpeg.exe')) -and (Test-Path (Join-Path $ffmpeg 'ffprobe.exe')))) {
  & (Join-Path $PSScriptRoot 'fetch_ffmpeg.ps1') -Destination $ffmpeg
}

if (-not $Iscc) {
  $Iscc = @(
    (Get-Command 'ISCC.exe' -ErrorAction SilentlyContinue).Source
    (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
    (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe')
  ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
  if (-not $Iscc) { throw 'Inno Setup 6 not found; pass -Iscc or run tool/fetch_inno_setup.ps1' }
}

& $Iscc /Q "/DAppVersion=$version" "/DBuildDir=$release" "/DFFmpegDir=$ffmpeg" (Join-Path $root 'installer/cutcap.iss') | Out-Host
if ($LASTEXITCODE -ne 0) { throw "ISCC failed (exit $LASTEXITCODE)" }

Join-Path $root "build/installer/cutcap-setup-$version.exe"
