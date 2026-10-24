param(
    [Parameter(Mandatory=$true)][string]$InstancePath,
    [ValidateSet('ad_astra','extended_drawers','phonos')][string[]]$Book,
    [switch]$CheckOnly,
    [switch]$Restore
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'legacy-book-index.json')){
    $packageRoot=$PSScriptRoot
}else{
    $packageRoot=Join-Path (Split-Path $PSScriptRoot -Parent) 'legacy-books'
}
$manifest=Get-Content -LiteralPath (Join-Path $packageRoot 'legacy-book-index.json') -Raw -Encoding UTF8|ConvertFrom-Json
if($manifest.schema -ne 1 -or $manifest.minecraft -ne '1.18.2'){throw 'Unsupported translation manifest.'}
$instanceRoot=[IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InstancePath).Path)
$modsRoot=Join-Path $instanceRoot 'mods'
if(-not (Test-Path -LiteralPath $modsRoot -PathType Container)){throw 'The instance must contain a mods directory.'}
$backupRoot=Join-Path $instanceRoot '.create-astral-ja-books-backups'
$allowed=@{'ad_astra'='ad_astra-fabric-1.18.2-1.0.9.jar';'extended_drawers'='ExtendedDrawers-1.3.7+mc.1.18.2.jar';'phonos'='phonos-0.3+1.18.2.jar'}
function Hash-File([string]$file){return (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()}
function Safe-Child([string]$base,[string]$relative){
    if([IO.Path]::IsPathRooted($relative) -or $relative.Contains('\') -or @($relative.Split('/')|Where-Object {$_ -eq '..' -or $_ -eq '.' -or $_ -eq ''}).Count){throw 'Unsafe relative path in manifest.'}
    $full=[IO.Path]::GetFullPath((Join-Path $base $relative))
    if(-not $full.StartsWith([IO.Path]::GetFullPath($base).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Path escapes package directory.'}
    return $full
}
function Read-ZipHashes([string]$file){
    $zip=[IO.Compression.ZipFile]::OpenRead($file);$map=@{}
    try{
        foreach($entry in $zip.Entries){
            if($map.ContainsKey($entry.FullName)){throw 'Duplicate entry in JAR.'}
            $stream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create()
            try{$map[$entry.FullName]=([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose();$stream.Dispose()}
        }
    }finally{$zip.Dispose()}
    return ,$map
}
$plan=@();$found=0
foreach($item in $manifest.books){
    if($Book -and $item.mod -notin $Book){continue}
    if(-not $allowed.ContainsKey($item.mod) -or $allowed[$item.mod] -ne $item.jar){throw 'Unsupported JAR target.'}
    if($item.jarSha256 -notmatch '^[a-f0-9]{64}$'){throw 'Invalid original JAR fingerprint.'}
    $jar=Safe-Child $modsRoot $item.jar
    if(-not (Test-Path -LiteralPath $jar -PathType Leaf)){Write-Output ('SKIP not installed: '+$item.mod);continue}
    $found++
    $originalBackup=Join-Path $backupRoot ($item.mod+'-'+$item.jarSha256+'.jar.bak')
    $recordPath=Join-Path $backupRoot ($item.mod+'.json');$currentHash=Hash-File $jar;$record=$null
    if(Test-Path -LiteralPath $recordPath){$record=Get-Content -LiteralPath $recordPath -Raw|ConvertFrom-Json}
    $source=$jar
    if($currentHash -ne $item.jarSha256){
        if(-not $record -or $record.installedHash -ne $currentHash -or -not (Test-Path -LiteralPath $originalBackup) -or (Hash-File $originalBackup) -ne $item.jarSha256){throw ('Unexpected JAR checksum; no changes made: '+$item.mod)}
        $source=$originalBackup
    }
    if($Restore){
        if($source -eq $jar){Write-Output ('ALREADY ORIGINAL: '+$item.mod);continue}
    }else{
        foreach($file in $item.files){
            if($file.path -notmatch ('^data/'+[regex]::Escape($item.mod)+'/patchouli_books/[^/]+/ja_jp/.+\.json$')){throw 'Only Japanese book JSON may be installed.'}
            $payload=Safe-Child (Join-Path $packageRoot ('payload/'+$item.mod)) $file.path
            if((Hash-File $payload) -ne $file.sha256){throw ('Translation payload hash mismatch: '+$file.path)}
        }
        if($source -ne $jar){
            $existing=Read-ZipHashes $jar;$identical=$true
            foreach($file in $item.files){if($existing[$file.path] -ne $file.sha256){$identical=$false}}
            if($identical){Write-Output ('ALREADY INSTALLED: '+$item.mod);continue}
        }
    }
    # Verify the game has released this exact JAR; unrelated Java servers are fine.
    $lock=[IO.File]::Open($jar,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None);$lock.Dispose()
    $plan+=@{item=$item;jar=$jar;source=$source;currentHash=$currentHash;backup=$originalBackup;record=$recordPath}
}
if(-not $found){throw 'No supported JARs found. Check the instance path and modpack version.'}
if(-not $plan.Count){Write-Output 'No changes required.';return}
if($CheckOnly){$plan|ForEach-Object {Write-Output ('CHECK OK: '+$_.item.mod)};return}
[IO.Directory]::CreateDirectory($backupRoot)|Out-Null
foreach($step in $plan){
    $item=$step.item;$temp=Join-Path $modsRoot ('.create-astral-ja-'+[guid]::NewGuid().ToString('N')+'.tmp')
    try{
        [IO.File]::Copy($step.source,$temp,$false)
        if(-not $Restore){
            $before=Read-ZipHashes $step.source
            # Rebuild the ZIP while preserving every original entry's bytes.
            # Updating some mod JAR layouts in-place corrupts local headers in .NET.
            $sourceZip=[IO.Compression.ZipFile]::OpenRead($step.source)
            $outputStream=[IO.File]::Open($temp,[IO.FileMode]::Create,[IO.FileAccess]::Write)
            $zip=[IO.Compression.ZipArchive]::new($outputStream,[IO.Compression.ZipArchiveMode]::Create,$false)
            try{
                foreach($originalEntry in $sourceZip.Entries){
                    $copy=$zip.CreateEntry($originalEntry.FullName,[IO.Compression.CompressionLevel]::Optimal)
                    $copy.LastWriteTime=$originalEntry.LastWriteTime
                    $copy.ExternalAttributes=$originalEntry.ExternalAttributes
                    $input=$originalEntry.Open();$output=$copy.Open()
                    try{$input.CopyTo($output)}finally{$output.Dispose();$input.Dispose()}
                }
                foreach($file in $item.files){
                    if($sourceZip.GetEntry($file.path)){throw 'Original JAR unexpectedly has this Japanese file.'}
                    $payload=Safe-Child (Join-Path $packageRoot ('payload/'+$item.mod)) $file.path
                    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$payload,$file.path,[IO.Compression.CompressionLevel]::Optimal)|Out-Null
                }
            }finally{$zip.Dispose();$outputStream.Dispose();$sourceZip.Dispose()}
            $after=Read-ZipHashes $temp
            if($after.Count -ne $before.Count+$item.files.Count){throw 'Unexpected added JAR entries.'}
            foreach($key in $before.Keys){if($before[$key] -ne $after[$key]){throw ('Original JAR data changed: '+$key)}}
            foreach($file in $item.files){if($after[$file.path] -ne $file.sha256){throw 'Installed translation hash mismatch.'}}
            if(-not (Test-Path -LiteralPath $step.backup)){[IO.File]::Copy($step.source,$step.backup,$false)}
            if((Hash-File $step.backup) -ne $item.jarSha256){throw 'Original backup checksum mismatch.'}
        }elseif((Hash-File $temp) -ne $item.jarSha256){throw 'Restored file is not the original JAR.'}
        if((Hash-File $step.jar) -ne $step.currentHash){throw 'JAR changed while preparing installation.'}
        $transactionBackup=Join-Path $backupRoot ($item.mod+'-before-'+[guid]::NewGuid().ToString('N')+'.bak')
        $installedHash=Hash-File $temp
        [IO.File]::Replace($temp,$step.jar,$transactionBackup)
        @{mod=$item.mod;originalHash=$item.jarSha256;installedHash=$installedHash;restored=[bool]$Restore;updatedAt=(Get-Date).ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath $step.record -Encoding UTF8
        Write-Output ((@{True='RESTORED';False='INSTALLED'}[[string][bool]$Restore])+': '+$item.mod)
    }finally{
        # This is a single, explicitly created .tmp file; backups are retained.
        if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Force}
    }
}
