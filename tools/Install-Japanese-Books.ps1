param(
    [Parameter(Mandatory=$true)][string]$InstancePath,
    [ValidateSet('ad_astra','extended_drawers','phonos')][string[]]$Book,
    [switch]$CheckOnly,
    [switch]$Restore,
    [switch]$RecoverMissing
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
# A launcher may add whitespace or rename a JAR. Identify its Fabric mod ID,
# then still require the exact original/installed checksum before changing it.
$jarInventory=@(Get-ChildItem -LiteralPath $modsRoot -File|Where-Object {$_.Extension -ieq '.jar'}|ForEach-Object {
    $jarFile=$_;$modId=$null;$archive=$null;$reader=$null
    try{
        $archive=[IO.Compression.ZipFile]::OpenRead($jarFile.FullName)
        $metadata=$archive.GetEntry('fabric.mod.json')
        if($metadata){$reader=[IO.StreamReader]::new($metadata.Open(),[Text.Encoding]::UTF8);$modId=($reader.ReadToEnd()|ConvertFrom-Json).id}
    }catch{
        # An unreadable unrelated JAR must not stop discovery. Expected names
        # remain candidates and will fail the checksum/ZIP checks below.
    }finally{if($reader){$reader.Dispose()};if($archive){$archive.Dispose()}}
    [pscustomobject]@{Name=$jarFile.Name;ModId=$modId}
})
$plan=@();$found=0
foreach($item in $manifest.books){
    if($Book -and $item.mod -notin $Book){continue}
    if(-not $allowed.ContainsKey($item.mod) -or $allowed[$item.mod] -ne $item.jar){throw 'Unsupported JAR target.'}
    if($item.jarSha256 -notmatch '^[a-f0-9]{64}$'){throw 'Invalid original JAR fingerprint.'}
    $originalBackup=Join-Path $backupRoot ($item.mod+'-'+$item.jarSha256+'.jar.bak')
    $recordPath=Join-Path $backupRoot ($item.mod+'.json');$record=$null
    if(Test-Path -LiteralPath $recordPath){$record=Get-Content -LiteralPath $recordPath -Raw -Encoding UTF8|ConvertFrom-Json}
    $candidates=@($jarInventory|Where-Object {$_.Name.Trim() -ieq $item.jar -or $_.ModId -eq $item.mod})
    if($candidates.Count -gt 1){throw ('Multiple JARs for '+$item.mod+'; no changes made: '+(($candidates|ForEach-Object {'['+$_.Name+']'}) -join ', '))}
    $missing=$false;$source=$null;$currentHash=$null
    if(-not $candidates.Count){
        if($RecoverMissing -and $record){
            if($record.originalHash -ne $item.jarSha256 -or -not (Test-Path -LiteralPath $originalBackup -PathType Leaf) -or (Hash-File $originalBackup) -ne $item.jarSha256){throw ('Missing JAR cannot be recovered: original backup checksum mismatch for '+$item.mod)}
            $jar=Safe-Child $modsRoot $item.jar;$source=$originalBackup;$missing=$true
            Write-Output ('RECOVERY planned from verified original backup: '+$item.mod)
        }elseif($record -and -not $record.restored){
            throw ('Previously installed JAR is now missing: '+$item.mod+'. No changes made. Check the launcher/mods folder; original backups remain in '+$backupRoot+'. To explicitly recover it, use -RecoverMissing.')
        }else{Write-Output ('SKIP not installed: '+$item.mod);continue}
    }else{
        $jar=Safe-Child $modsRoot $candidates[0].Name
        if($candidates[0].Name -cne $item.jar){Write-Output ('FOUND renamed JAR: '+$item.mod+' ['+$candidates[0].Name+']')}
        $currentHash=Hash-File $jar;$source=$jar
    }
    $found++
    if(-not $missing -and $currentHash -ne $item.jarSha256){
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
        if(-not $missing -and $source -ne $jar){
            $existing=Read-ZipHashes $jar;$identical=$true
            foreach($file in $item.files){if($existing[$file.path] -ne $file.sha256){$identical=$false}}
            if($identical){Write-Output ('ALREADY INSTALLED: '+$item.mod);continue}
        }
    }
    # Verify the game has released this exact JAR; unrelated Java servers are fine.
    if(-not $missing){$lock=[IO.File]::Open($jar,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None);$lock.Dispose()}
    $plan+=@{item=$item;jar=$jar;source=$source;currentHash=$currentHash;backup=$originalBackup;record=$recordPath;missing=$missing}
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
        $installedHash=Hash-File $temp
        if($step.missing){
            # Move fails if anything has appeared at the target in the meantime.
            [IO.File]::Move($temp,$step.jar)
        }else{
            if((Hash-File $step.jar) -ne $step.currentHash){throw 'JAR changed while preparing installation.'}
            $transactionBackup=Join-Path $backupRoot ($item.mod+'-before-'+[guid]::NewGuid().ToString('N')+'.bak')
            [IO.File]::Replace($temp,$step.jar,$transactionBackup)
        }
        @{mod=$item.mod;jarName=[IO.Path]::GetFileName($step.jar);originalHash=$item.jarSha256;installedHash=$installedHash;restored=[bool]$Restore;updatedAt=(Get-Date).ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath $step.record -Encoding UTF8
        if(-not (Test-Path -LiteralPath $step.jar -PathType Leaf) -or (Hash-File $step.jar) -ne $installedHash){throw ('JAR changed or disappeared after writing: '+$item.mod+'. Close the launcher and inspect the mods folder. Original backups remain in '+$backupRoot)}
        Write-Output ((@{True='RESTORED';False='INSTALLED'}[[string][bool]$Restore])+': '+$item.mod)
    }finally{
        # This is a single, explicitly created .tmp file; backups are retained.
        if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Force}
    }
}
