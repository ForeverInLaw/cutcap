<#
.SYNOPSIS
  Downloads the pinned Inno Setup, verifies its sha256 and installs it for
  the current user into a directory, so ISCC.exe ends up in that directory.

.DESCRIPTION
  For CI, which caches the destination keyed on $Version and $Sha256 (bump
  both together). The installer runs silently without admin rights and adds
  no shortcuts; on a dev box an existing Inno Setup 6 works just as well
  (tool/build_installer.ps1 finds it).

.EXAMPLE
  pwsh tool/fetch_inno_setup.ps1 -Destination build/innosetup
#>
param(
  [Parameter(Mandatory)]
  [string] $Destination
)

$ErrorActionPreference = 'Stop'

$Version = '6.7.4'
$Url = "https://github.com/jrsoftware/issrc/releases/download/is-$($Version -replace '\.', '_')/innosetup-$Version.exe"
$Sha256 = 'a549929319f9120716677c685535ca4671e4b937b5fdc87e2585f32d8eb30e8c'

$work = Join-Path ([System.IO.Path]::GetTempPath()) "cutcap-innosetup-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $work | Out-Null
try {
  $installer = Join-Path $work "innosetup-$Version.exe"
  Write-Host "Downloading $Url"
  Invoke-WebRequest -Uri $Url -OutFile $installer -UseBasicParsing

  $actual = (Get-FileHash -Algorithm SHA256 -Path $installer).Hash.ToLowerInvariant()
  if ($actual -ne $Sha256) {
    throw "sha256 mismatch for $Url`n  expected $Sha256`n  actual   $actual"
  }

  $target = [System.IO.Path]::GetFullPath($Destination)
  $arguments = @(
    '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-',
    '/CURRENTUSER', '/NOICONS', "/DIR=`"$target`""
  )
  $process = Start-Process -FilePath $installer -ArgumentList $arguments -Wait -PassThru
  if ($process.ExitCode -ne 0) { throw "Inno Setup installer failed (exit $($process.ExitCode))" }

  $iscc = Join-Path $target 'ISCC.exe'
  if (-not (Test-Path $iscc)) { throw "ISCC.exe not found in $target after install" }
  Write-Host "Inno Setup $Version (sha256 $Sha256) -> $iscc"
}
finally {
  Remove-Item -Recurse -Force -Path $work -ErrorAction SilentlyContinue
}
