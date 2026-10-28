#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ClientPath,
    [string]$GameDirectory,
    [string]$LauncherDirectory,
    [string]$DownloadCache,
    [switch]$Check,
    [switch]$Undo,
    [switch]$AllowDifferentClient,
    [switch]$ShaderPacksOnly
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'

function Full-Path([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { throw 'The path is empty.' }
    return [IO.Path]::GetFullPath($Path)
}
function Hash([string]$Path, [string]$Algorithm = 'SHA256') {
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $hasher = if ($Algorithm -eq 'SHA512') { [Security.Cryptography.SHA512]::Create() } else { [Security.Cryptography.SHA256]::Create() }
    $stream = [IO.File]::OpenRead($Path)
    try { return [BitConverter]::ToString($hasher.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() }
    finally { $stream.Dispose(); $hasher.Dispose() }
}
function Save-Json($Value, [string]$Path) {
    $temp = "$Path.tmp"
    [IO.File]::WriteAllText($temp, ($Value | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
    if ([IO.File]::Exists($Path)) { [IO.File]::Replace($temp, $Path, "$Path.previous") }
    else { [IO.File]::Move($temp, $Path) }
}
function Refuse-Links([string]$Path) {
    $cursor = $Path
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "The destination uses a link/junction: $cursor. Specify the real path."
            }
        }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }; $cursor = $parent
    }
}
function Assert-Closed {
    $busy = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        if ($_.ProcessName -eq 'horizon-launcher') { $true }
        elseif ($_.ProcessName -in @('horizon-client','gbzyuuu-client','gbzyuuu')) {
            $runningPath = $_.Path
            if (!$runningPath) { $true }
            else {
                $runningPath -eq $script:ClientPath -or
                ($_.ProcessName -eq 'gbzyuuu' -and $script:ClientPath.StartsWith(([IO.Path]::GetDirectoryName($runningPath) + '\'), [StringComparison]::OrdinalIgnoreCase))
            }
        } else { $false }
    })
    if ($busy.Count) { throw 'Save your world and close the game and launcher before installing or restoring. No process was terminated.' }
}
function Get-Pack($Pack, [string]$Cache) {
    $target = Join-Path $Cache $Pack.file
    if ((Hash $target 'SHA512') -eq $Pack.sha512) { return $target }
    $uri = [Uri]$Pack.url
    if ($uri.Scheme -ne 'https' -or $uri.Host -ne 'cdn.modrinth.com') { throw 'The shader download origin is not allowed.' }
    $part = "$target.download-$([Guid]::NewGuid().ToString('N'))"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing -Uri $Pack.url -OutFile $part -Headers @{'User-Agent'='HorizonShadersTest/0.2.0'} -TimeoutSec 180
    if ((Hash $part 'SHA512') -ne $Pack.sha512) { throw "The downloaded hash does not match: $($Pack.file). File was not installed: $part" }
    if (Test-Path -LiteralPath $target) { [IO.File]::Replace($part, $target, "$part.previous") }
    else { [IO.File]::Move($part, $target) }
    return $target
}
function Restore-Receipt($Receipt, [string]$ReceiptPath) {
    if ($Receipt.client -ne $script:ClientPath -or $Receipt.game -ne $script:GameDirectory) { throw 'The receipt belongs to another installation.' }
    $allowed = @($script:ClientPath) + @($script:Manifest.runtime | ForEach-Object { Join-Path ([IO.Path]::GetDirectoryName($script:ClientPath)) $_.file }) + @($script:Manifest.packs | ForEach-Object { Join-Path $script:GameDirectory "shaderpacks\$($_.file)" })
    if ([IO.Path]::GetDirectoryName((Full-Path $Receipt.backup_dir)) -ne $script:backupRoot) { throw 'Unexpected backup directory in the receipt.' }
    Refuse-Links $Receipt.backup_dir
    # Validate every destination and every backup before restoring anything.
    foreach ($e in $Receipt.files) {
        if ($e.path -notin $allowed) { throw "Unexpected destination in the receipt: $($e.path)" }
        Refuse-Links $e.path
        if ($e.backup -and ([IO.Path]::GetDirectoryName((Full-Path $e.backup)) -ne $Receipt.backup_dir)) { throw 'The backup is outside the recorded directory.' }
        $current = Hash $e.path
        if ($current -ne $e.after -and $current -ne $e.before) { throw "The file changed after installation: $($e.path). Nothing will be overwritten; preserve it and inspect the backup." }
        if ($e.before -and (Hash $e.backup) -ne $e.before) { throw "Missing or modified backup: $($e.backup)" }
    }
    foreach ($e in $Receipt.files) {
        if ((Hash $e.path) -eq $e.before) { continue }
        if ($e.before) {
            $temp = "$($e.path).restore-$([Guid]::NewGuid().ToString('N'))"
            [IO.File]::Copy($e.backup, $temp, $false)
            [IO.File]::Replace($temp, $e.path, (Join-Path $Receipt.backup_dir "removed-$([Guid]::NewGuid().ToString('N')).bin"))
        } else { Remove-Item -LiteralPath $e.path }
    }
    $Receipt.status = 'restored'; Save-Json $Receipt $ReceiptPath
    Write-Host 'Restored. Worlds, accounts and settings were not changed.'
}

$Manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw | ConvertFrom-Json
foreach ($entry in @($Manifest.runtime) + @($Manifest.packs)) {
    if ($entry.file -notmatch '^[A-Za-z0-9_.-]+$') { throw 'Unsafe file name in the manifest.' }
}
if (!$LauncherDirectory) { $LauncherDirectory = Join-Path $env:APPDATA 'horizon-launcher' }
$LauncherDirectory = Full-Path $LauncherDirectory
$settingsPath = Join-Path $LauncherDirectory 'settings.json'
$settings = if (Test-Path -LiteralPath $settingsPath) { Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json } else { $null }
if (!$ClientPath) {
    if (!$settings -or !$settings.selected) { throw 'Horizon was not found. Specify -ClientPath for horizon-client.exe and -GameDirectory for the game directory.' }
    if ($settings.selected -notmatch '^v[0-9][A-Za-z0-9.\-]*$') { throw 'The selected version has an unexpected name.' }
    $ClientPath = Join-Path $LauncherDirectory "versions\$($settings.selected)\horizon-client.exe"
}
if (!$GameDirectory) {
    if ($settings -and $settings.PSObject.Properties['instance'] -and $settings.instance -and $settings.instance -ne 'horizon') {
        throw 'You use a custom instance. Specify -GameDirectory and -ClientPath for that instance.'
    }
    $GameDirectory = if ($env:HORIZON_HOME) { $env:HORIZON_HOME } else { Join-Path $env:APPDATA 'horizon' }
}
$ClientPath = Full-Path $ClientPath; $GameDirectory = Full-Path $GameDirectory
Refuse-Links $ClientPath; Refuse-Links $GameDirectory
if (!(Test-Path -LiteralPath $ClientPath -PathType Leaf)) { throw "Client not found: $ClientPath" }
if (!(Test-Path -LiteralPath $GameDirectory -PathType Container)) { throw "Game directory not found: $GameDirectory. Run Horizon at least once." }
$backupRoot = Join-Path ([IO.Path]::GetDirectoryName($ClientPath)) '.gbzyuuu-shaders-backup'
$receiptPath = Join-Path $backupRoot 'active.json'
Refuse-Links $backupRoot
if ($Undo) {
    Assert-Closed
    if (!(Test-Path -LiteralPath $receiptPath)) { throw 'There is no recorded installation to restore.' }
    Restore-Receipt (Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json) $receiptPath
    exit 0
}
# Keep all pack metadata for restoring historical receipts, but download only Photon.
$AutomaticShaderPacks = @($Manifest.packs | Where-Object { $_.file -eq 'photon_v1.4.zip' -and $_.version_id -eq 'BnGklH5y' })
$payload = Join-Path $PSScriptRoot 'horizon-client.exe'
if ((Hash $payload) -ne $Manifest.client.sha256) { throw 'The package executable is missing or modified. Extract the complete package again.' }
foreach ($file in $Manifest.runtime) {
    if ((Hash (Join-Path $PSScriptRoot $file.file)) -ne $file.sha256) { throw "Missing or modified package file: $($file.file)" }
}
$currentHash = Hash $ClientPath
$alreadyClient = $currentHash -eq $Manifest.client.sha256
$legacyUpgrade = $false
$legacyReceipt = $null
if (!$ShaderPacksOnly -and !$alreadyClient -and $currentHash -eq 'cb31ef27e827e1ed21c859994ff8896c8b082b7969a162dc7a94248f34cd64ff' -and (Test-Path -LiteralPath $receiptPath)) {
    $legacyReceipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
    if ($legacyReceipt.package -in @('horizon-shaders-test-0.1.0','horizon-shaders-test-0.1.1') -and $legacyReceipt.status -eq 'installed' -and $legacyReceipt.client -eq $ClientPath -and $legacyReceipt.game -eq $GameDirectory) {
        $legacyClientEntry = @($legacyReceipt.files | Where-Object { $_.path -eq $ClientPath })
        if ($legacyClientEntry.Count -eq 1 -and $legacyClientEntry[0].before -in $Manifest.client.known_original_sha256 -and (Hash $legacyClientEntry[0].backup) -eq $legacyClientEntry[0].before) { $legacyUpgrade = $true }
    }
}
if (!$alreadyClient -and !$legacyUpgrade -and $currentHash -notin $Manifest.client.known_original_sha256 -and !$AllowDifferentClient) {
    throw 'This client is not the verified official build. Installation stopped to preserve other patches. -AllowDifferentClient explicitly allows replacing the entire client with the experimental v0.2.93 base and a backup; mods requiring custom APIs may stop working.'
}
$lockFile = Join-Path ([IO.Path]::GetDirectoryName($ClientPath)) 'research-lock.json'
if (Test-Path -LiteralPath $lockFile) {
    $lock = Get-Content -LiteralPath $lockFile -Raw | ConvertFrom-Json
    if ($lock.minecraft.version -ne $Manifest.minecraft) { throw 'This package requires Minecraft 26.3 resources.' }
}
Write-Host "Client: $ClientPath"
Write-Host "Shaders: $(Join-Path $GameDirectory 'shaderpacks')"
if ($ShaderPacksOnly) { Write-Host 'Shader-packs-only mode: the Horizon executable and DLLs will remain unchanged. Unsupported shaders may still fail in the official client.' }
else { Write-Host 'EXPERIMENTAL package: Horizon v0.2.93 client with shader fixes. This is not an official release or full visual parity with Java.' }
Write-Host 'Complementary is optional and is not downloaded by this installer. Download the original ZIP manually from https://modrinth.com/shader/complementary-unbound and place it in the shaderpacks folder shown above. Existing copies are preserved.'
if ($Check) {
    foreach ($pack in $AutomaticShaderPacks) { Write-Host "$($pack.name): installed=$((Hash (Join-Path $GameDirectory "shaderpacks\$($pack.file)") 'SHA512') -eq $pack.sha512)" }
    Write-Host "Experimental client installed=$alreadyClient"; exit 0
}
Assert-Closed
if (Test-Path -LiteralPath $receiptPath) {
    $prior = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
    if ($prior.client -ne $ClientPath -or $prior.game -ne $GameDirectory) { throw 'The existing backup belongs to another game directory. Use the original paths with -Undo.' }
    if ($prior.status -ne 'restored' -and !$legacyUpgrade) {
        $requestedMode = if ($ShaderPacksOnly) { 'packs-only' } else { 'full-client' }
        $previousMode = if ($prior.PSObject.Properties['mode']) { $prior.mode } else { 'full-client' }
        if ($previousMode -ne $requestedMode) { throw 'Restore the previous installation with -Undo before switching installation modes.' }
        $runtimeOk = @($Manifest.runtime | Where-Object { (Hash (Join-Path ([IO.Path]::GetDirectoryName($ClientPath)) $_.file)) -ne $_.sha256 }).Count -eq 0
        if (($ShaderPacksOnly -or ($alreadyClient -and $runtimeOk)) -and (@($AutomaticShaderPacks | Where-Object { (Hash (Join-Path $GameDirectory "shaderpacks\$($_.file)") 'SHA512') -ne $_.sha512 }).Count -eq 0)) {
            Write-Host 'This package is already installed. The original backup was preserved.'; exit 0
        }
        throw 'There is a previous or interrupted installation. Run -Undo before installing again; the original backup was preserved.'
    }
}
if (!$DownloadCache) { $DownloadCache = Join-Path $env:LOCALAPPDATA 'HorizonShadersTest\downloads' }
$DownloadCache = Full-Path $DownloadCache; Refuse-Links $DownloadCache
[IO.Directory]::CreateDirectory($DownloadCache) | Out-Null
$planned = @()
if (!$ShaderPacksOnly) {
    $planned += [pscustomobject]@{source=$payload;path=$ClientPath}
    foreach ($file in $Manifest.runtime) {
        $planned += [pscustomobject]@{source=(Join-Path $PSScriptRoot $file.file);path=(Join-Path ([IO.Path]::GetDirectoryName($ClientPath)) $file.file)}
    }
}
foreach ($pack in $AutomaticShaderPacks) {
    $download = Get-Pack $pack $DownloadCache
    $planned += [pscustomobject]@{source=$download;path=(Join-Path $GameDirectory "shaderpacks\$($pack.file)")}
}
# Downloads and hashes are complete before touching the installed client.
Assert-Closed
if ($legacyUpgrade) {
    Write-Host 'Upgrading the verified older shader patch. Restoring its verified official backup first; all prior backups are preserved.'
    Restore-Receipt $legacyReceipt $receiptPath
    if ((Hash $ClientPath) -notin $Manifest.client.known_original_sha256) { throw 'The restored client does not match the verified official build.' }
}
$backupDir = Join-Path $backupRoot ([Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($backupDir) | Out-Null
$entries = @(); $index = 0
foreach ($item in $planned) {
    Refuse-Links $item.path
    $before = Hash $item.path; $after = Hash $item.source
    $backup = if ($before) { Join-Path $backupDir "$index.original" } else { $null }
    if ($backup) { [IO.File]::Copy($item.path, $backup, $false) }
    $entries += [pscustomobject]@{path=$item.path;before=$before;after=$after;backup=$backup}; $index++
}
$receipt = [pscustomobject]@{schema=1;package=$Manifest.id;status='installing';mode=$(if($ShaderPacksOnly){'packs-only'}else{'full-client'});client=$ClientPath;game=$GameDirectory;backup_dir=$backupDir;files=$entries}
Save-Json $receipt $receiptPath
try {
    for ($i=0; $i -lt $planned.Count; $i++) {
        $item = $planned[$i]; $entry = $entries[$i]
        if ((Hash $item.path) -ne $entry.before) { throw "The destination changed during installation: $($item.path)" }
        if ($entry.before -eq $entry.after) { continue }
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($item.path)) | Out-Null
        $temp = "$($item.path).install-$([Guid]::NewGuid().ToString('N'))"
        [IO.File]::Copy($item.source, $temp, $false)
        if ($entry.before) { [IO.File]::Replace($temp, $item.path, (Join-Path $backupDir "$i.replace-original")) }
        else { [IO.File]::Move($temp, $item.path) }
        if ((Hash $item.path) -ne $entry.after) { throw 'Installed file verification failed.' }
    }
    $receipt.status = 'installed'; Save-Json $receipt $receiptPath
} catch {
    $reason = $_
    try { Restore-Receipt $receipt $receiptPath } catch { Write-Warning "Restoration requires review: $_. Backup: $backupDir" }
    throw $reason
}
Write-Host 'Installed. Open your usual launcher and select a shader in video settings. The first compilation may take longer.'
Write-Host 'Restart the game after switching graphics APIs. To restore the previous client, run this command with -Undo.'
Write-Host "Backup: $backupDir"
