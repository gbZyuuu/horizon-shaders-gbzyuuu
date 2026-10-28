#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$CacheDirectory,
    [string]$ClientPath,
    [string]$GameDirectory,
    [string]$LauncherDirectory,
    [switch]$Check,
    [switch]$Undo,
    [switch]$ShaderPacksOnly
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Get-ShaderFileHash([string]$Path) {
    if (![IO.File]::Exists($Path)) { return '' }
    $sha = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($Path)
    try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','').ToLowerInvariant() }
    finally { $stream.Dispose(); $sha.Dispose() }
}

function Assert-ShaderRealPath([string]$Path) {
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "The directory uses a link/junction. Specify its real path with -CacheDirectory: $cursor"
            }
        }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }; $cursor = $parent
    }
}

# Supported payload identities; other clients retain their custom host APIs.
$script:ShaderClientHashes = @(
    '5a640f0bb75e31e9fa06369a0127b88a3012a6a08bad45809bdf27fec0519a8c',
    '63e03f4491764eeafba04ad0ff01a2c11a59659adeb03167bd1fde32756649d0',
    'cb31ef27e827e1ed21c859994ff8896c8b082b7969a162dc7a94248f34cd64ff'
)

function Read-ShaderProfile([string]$Launcher, [string]$GameHome) {
    $Launcher = [IO.Path]::GetFullPath($Launcher)
    $GameHome = [IO.Path]::GetFullPath($GameHome)
    Assert-ShaderRealPath $Launcher
    Assert-ShaderRealPath $GameHome
    $settingsFile = Join-Path $Launcher 'settings.json'
    if (![IO.File]::Exists($settingsFile)) { return }
    $settings = Get-Content -LiteralPath $settingsFile -Raw | ConvertFrom-Json
    if (!$settings.selected -or $settings.selected -notmatch '^v[0-9][A-Za-z0-9.\-]*$') { return }
    $client = Join-Path $Launcher "versions\$($settings.selected)\horizon-client.exe"
    $hash = Get-ShaderFileHash $client
    $reason = if (!$hash) { 'Selected client is missing' } elseif ($hash -notin $script:ShaderClientHashes) { 'Selected client has an unsupported/custom build' } elseif (![IO.Directory]::Exists($GameHome)) { 'Game directory is missing' } else { '' }
    if ($settings.PSObject.Properties['instance'] -and $settings.instance -and $settings.instance -ne 'horizon') {
        $reason = 'Custom instance: specify -ClientPath and -GameDirectory'
    }
    [pscustomobject]@{Launcher=$Launcher;Game=$GameHome;Client=$client;Version=$settings.selected;Hash=$hash;Supported=(!$reason);Reason=$reason}
}

function Find-ShaderPortableProfiles([string[]]$Roots) {
    $seen = @{}
    foreach ($root in $Roots) {
        if (!$root -or ![IO.Directory]::Exists($root)) { continue }
        # Bounded search: root, its children and grandchildren, never links or whole disks.
        $level = @((Get-Item -LiteralPath $root))
        for ($depth = 0; $depth -le 2; $depth++) {
            $next = @()
            foreach ($directory in $level) {
                if ($directory.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
                if ($seen.ContainsKey($directory.FullName)) { continue }
                $seen[$directory.FullName] = $true
                $launcher = Join-Path $directory.FullName 'launcher-data'
                $gameHome = Join-Path $directory.FullName 'game'
                if ([IO.File]::Exists((Join-Path $launcher 'settings.json')) -and
                    [IO.Directory]::Exists($gameHome) -and
                    [IO.File]::Exists((Join-Path $directory.FullName 'bin\horizon-launcher.exe'))) {
                    Read-ShaderProfile $launcher $gameHome
                }
                if ($depth -lt 2) {
                    $next += @(Get-ChildItem -LiteralPath $directory.FullName -Directory -ErrorAction SilentlyContinue)
                }
            }
            $level = $next
        }
    }
}

function Select-ShaderProfile($Candidates, [bool]$Interactive) {
    $unique = @{}
    foreach ($candidate in $Candidates) {
        if ($candidate) { $unique[$candidate.Client] = $candidate }
    }
    $compatible = @($unique.Values | Where-Object Supported | Sort-Object Client)
    foreach ($rejected in @($unique.Values | Where-Object { !$_.Supported })) {
        Write-Host "Preserved: $($rejected.Client) - $($rejected.Reason)"
    }
    if (!$compatible.Count) {
        throw 'No compatible profile was found. This package supports the verified Horizon v0.2.93 client and its shader patches. Custom clients were preserved. Select/prepare v0.2.93, or specify -LauncherDirectory and -GameDirectory for another profile. No package was downloaded or extracted.'
    }
    if ($compatible.Count -eq 1) { return $compatible[0] }
    Write-Host 'Several compatible installations were found:'
    for ($index=0; $index -lt $compatible.Count; $index++) {
        Write-Host "[$($index+1)] $($compatible[$index].Client)"
        Write-Host "    Game data: $($compatible[$index].Game)"
    }
    if (!$Interactive) { throw 'Specify -LauncherDirectory and -GameDirectory to choose an installation in non-interactive/check mode.' }
    $answer = Read-Host 'Installation number to update (Enter cancels)'
    $number = 0
    if (![int]::TryParse($answer,[ref]$number) -or $number -lt 1 -or $number -gt $compatible.Count) { throw 'Installation cancelled; no files changed.' }
    return $compatible[$number-1]
}

function Expand-ShaderPackage([string]$ArchivePath, [string]$Destination, [string]$Id) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $expected = @(
        'Installer.ps1', 'Install.cmd', 'LOCATE-AND-INSTALL.txt',
        'README.txt', 'README.pt-BR.txt', 'manifest.json', 'VALIDATION.json', 'horizon-client.exe',
        'dxcompiler.dll', 'dxil.dll', 'LICENSE-HORIZON', 'DXC-LICENSE-LLVM.txt',
        'DXC-LICENSE-MIT.txt', 'DXC-LICENSE-MS.txt', 'DXC-LICENSE.txt',
        'DXC-provenance.json', 'source.zip', 'shader-fixes.patch',
        'THIRD-PARTY-NOTICES.zip', 'SHA256SUMS.txt'
    )
    $archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        $names = @{}; [long]$bytes = 0
        # Check the entire inventory before creating a single extracted file.
        foreach ($entry in $archive.Entries) {
            $prefix = "$Id/"
            if (!$entry.FullName.StartsWith($prefix, [StringComparison]::Ordinal)) { throw 'Unexpected ZIP structure.' }
            $name = $entry.FullName.Substring($prefix.Length)
            if ($name -notin $expected -or $names.ContainsKey($name) -or
                ((($entry.ExternalAttributes -shr 16) -band 61440) -eq 40960)) {
                throw "Unexpected or duplicate ZIP entry: $($entry.FullName)"
            }
            $names[$name] = $true; $bytes += $entry.Length
        }
        if ($names.Count -ne $expected.Count -or $bytes -gt 188743680) { throw 'The ZIP contents or size differ from the expected package.' }
        if ([IO.Directory]::Exists($Destination)) { throw 'The temporary extraction directory already exists.' }
        [IO.Directory]::CreateDirectory($Destination) | Out-Null
        foreach ($entry in $archive.Entries) {
            $target = Join-Path $Destination $entry.FullName.Substring($Id.Length + 1)
            $inputStream = $entry.Open()
            $outputStream = [IO.File]::Open($target, [IO.FileMode]::CreateNew)
            try { $inputStream.CopyTo($outputStream) }
            finally { $outputStream.Dispose(); $inputStream.Dispose() }
        }
    } finally { $archive.Dispose() }

    $covered = @{}
    foreach ($line in [IO.File]::ReadAllLines((Join-Path $Destination 'SHA256SUMS.txt'))) {
        if ($line -notmatch '^([a-f0-9]{64})  ([A-Za-z0-9_.-]+)$') { throw 'Invalid checksum list.' }
        $digest = $Matches[1]; $name = $Matches[2]
        if ($name -notin $expected -or $name -eq 'SHA256SUMS.txt' -or $covered.ContainsKey($name)) { throw 'Unexpected checksum inventory.' }
        if ((Get-ShaderFileHash (Join-Path $Destination $name)) -ne $digest) { throw "Extracted file hash mismatch: $name" }
        $covered[$name] = $true
    }
    if ($covered.Count -ne ($expected.Count - 1)) { throw 'Extracted file checksums are missing.' }
}

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or ![Environment]::Is64BitOperatingSystem) {
    throw 'This package requires Windows x64.'
}
$packageId = 'horizon-shaders-1.0.0'
$packageHash = '2932c03775da4262e1bcb105d70e22f450c7eca61eaa1ee6f4177a6357a33675'
$packageUrl = 'https://github.com/gbZyuuu/horizon-shaders-gbzyuuu/releases/download/v1.0.0/horizon-shaders-1.0.0.zip'
# Resolve the destination before downloading/extracting the package.
if (!$ClientPath) {
    $gameHome = if ($GameDirectory) { $GameDirectory } elseif ($env:HORIZON_HOME) { $env:HORIZON_HOME } else { Join-Path $env:APPDATA 'horizon' }
    if ($LauncherDirectory -or $env:HORIZON_LAUNCHER_HOME) {
        if (!$LauncherDirectory) { $LauncherDirectory = $env:HORIZON_LAUNCHER_HOME }
        $profiles = @(Read-ShaderProfile $LauncherDirectory $gameHome)
    } else {
        $profiles = @(Read-ShaderProfile (Join-Path $env:APPDATA 'horizon-launcher') $gameHome)
        $roots = @((Join-Path $env:USERPROFILE 'Downloads'), (Join-Path $env:USERPROFILE 'Desktop'), (Join-Path $env:USERPROFILE 'Documents'))
        foreach ($process in @(Get-Process -Name horizon-launcher -ErrorAction SilentlyContinue)) {
            try {
                if ($process.Path) {
                    $directory = [IO.Path]::GetDirectoryName($process.Path)
                    $roots += $directory
                    $roots += [IO.Path]::GetDirectoryName($directory)
                }
            } catch { }
        }
        $profiles += @(Find-ShaderPortableProfiles $roots)
    }
    $selected = Select-ShaderProfile $profiles (!$Check -and [Environment]::UserInteractive)
    $ClientPath = $selected.Client
    $LauncherDirectory = $selected.Launcher
    $GameDirectory = $selected.Game
} else {
    $ClientPath = [IO.Path]::GetFullPath($ClientPath)
    Assert-ShaderRealPath $ClientPath
    if ((Get-ShaderFileHash $ClientPath) -notin $script:ShaderClientHashes) {
        throw "Unsupported/custom client preserved: $ClientPath. No package was downloaded or extracted."
    }
}
Write-Host "Selected client: $ClientPath"
if ($GameDirectory) { Write-Host "Selected game data: $GameDirectory" }

if (!$CacheDirectory) { $CacheDirectory = Join-Path $env:LOCALAPPDATA 'HorizonShadersTest\packages' }
$CacheDirectory = [IO.Path]::GetFullPath($CacheDirectory)
Assert-ShaderRealPath $CacheDirectory
[IO.Directory]::CreateDirectory($CacheDirectory) | Out-Null
$archivePath = Join-Path $CacheDirectory "$packageId-$($packageHash.Substring(0,12)).zip"
if ((Get-ShaderFileHash $archivePath) -ne $packageHash) {
    Write-Host 'Downloading the shader package from GitHub (approximately 60 MB)...'
    $partial = "$archivePath.download-$([Guid]::NewGuid().ToString('N'))"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing -Uri $packageUrl -OutFile $partial -TimeoutSec 300 -Headers @{'User-Agent'='HorizonShadersBootstrap/1.0.0'}
    if ((Get-Item -LiteralPath $partial).Length -gt 104857600 -or (Get-ShaderFileHash $partial) -ne $packageHash) {
        throw "The download does not match the published package. No client was changed. File: $partial"
    }
    if ([IO.File]::Exists($archivePath)) { [IO.File]::Replace($partial, $archivePath, "$partial.previous") }
    else { [IO.File]::Move($partial, $archivePath) }
} else { Write-Host 'Using the previously downloaded and verified package.' }

$work = Join-Path $CacheDirectory "$packageId-$([Guid]::NewGuid().ToString('N'))"
Write-Host 'Verifying and extracting the package...'
Expand-ShaderPackage $archivePath $work $packageId
$arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $work 'Installer.ps1'))
if ($ClientPath) { $arguments += @('-ClientPath',$ClientPath) }
if ($GameDirectory) { $arguments += @('-GameDirectory',$GameDirectory) }
if ($LauncherDirectory) { $arguments += @('-LauncherDirectory',$LauncherDirectory) }
if ($Check) { $arguments += '-Check' }
if ($Undo) { $arguments += '-Undo' }
if ($ShaderPacksOnly) { $arguments += '-ShaderPacksOnly' }
Write-Host 'Starting the installer. It locates the current user''s Horizon and preserves a backup.'
& powershell.exe @arguments
if ($LASTEXITCODE -ne 0) { throw "Installation did not complete (exit code $LASTEXITCODE). See the message above. Package preserved at: $work" }
