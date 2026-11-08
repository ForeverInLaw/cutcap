<#
.SYNOPSIS
  Downloads the pinned FFmpeg build for Windows (ADR 0002), verifies its
  sha256 and puts ffmpeg.exe and ffprobe.exe into a directory.

.DESCRIPTION
  The Windows build and installer bundle these two executables. CI caches the
  destination keyed on $Version and $Sha256, so bump both together.
  Extraction uses the Windows tar.exe (libarchive), which reads .7z.

.EXAMPLE
  pwsh tool/fetch_ffmpeg.ps1 -Destination build/ffmpeg
#>
param(
  [Parameter(Mandatory)]
  [string] $Destination
)

$ErrorActionPreference = 'Stop'

$Version = '9.0.2'
$Url = "https://github.com/GyanD/codexffmpeg/releases/download/$Version/ffmpeg-$Version-essentials_build.7z"
$Sha256 = '4705843ccaaf54257c16ad90f3e952ece33c17df964ecf7bfdbb0f49c7171077'
$Executables = @('ffmpeg.exe', 'ffprobe.exe')

$work = Join-Path ([System.IO.Path]::GetTempPath()) "cutcap-ffmpeg-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $work | Out-Null
try {
  $archive = Join-Path $work 'ffmpeg.7z'
  Write-Host "Downloading $Url"
  Invoke-WebRequest -Uri $Url -OutFile $archive -UseBasicParsing

  $actual = (Get-FileHash -Algorithm SHA256 -Path $archive).Hash.ToLowerInvariant()
  if ($actual -ne $Sha256) {
    throw "sha256 mismatch for $Url`n  expected $Sha256`n  actual   $actual"
  }

  $extracted = Join-Path $work 'x'
  New-Item -ItemType Directory -Path $extracted | Out-Null
  & "$env:SystemRoot\System32\tar.exe" -xf $archive -C $extracted
  if ($LASTEXITCODE -ne 0) { throw "tar failed to extract $archive (exit $LASTEXITCODE)" }

  New-Item -ItemType Directory -Force -Path $Destination | Out-Null
  foreach ($exe in $Executables) {
    $found = Get-ChildItem -Path $extracted -Recurse -Filter $exe | Where-Object { $_.Directory.Name -eq 'bin' }
    if (@($found).Count -ne 1) { throw "Expected one bin/$exe in the archive, found $(@($found).Count)" }
    Copy-Item -Path $found.FullName -Destination $Destination -Force
  }
  Write-Host "FFmpeg $Version (sha256 $Sha256) -> $(Resolve-Path $Destination)"
}
finally {
  Remove-Item -Recurse -Force -Path $work -ErrorAction SilentlyContinue
}
