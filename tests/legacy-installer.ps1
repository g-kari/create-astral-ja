$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
$repo=Split-Path $PSScriptRoot -Parent
$fixtureRoot=Join-Path ([IO.Path]::GetTempPath()) ('create-astral-ja-test-'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($fixtureRoot)|Out-Null
Set-Content -LiteralPath (Join-Path $fixtureRoot '.test-fixture') -Value 'created by legacy-installer.ps1' -Encoding ASCII
function Assert([bool]$condition,[string]$message){if(-not $condition){throw $message}}
function Hash([string]$file){return (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()}
function Reject([scriptblock]$action){$rejected=$false;try{&$action}catch{$rejected=$true};Assert $rejected 'Unsafe operation was accepted.'}
try{
    $pkg=Join-Path $fixtureRoot 'package';Copy-Item -LiteralPath (Join-Path $repo 'legacy-books') -Destination $pkg -Recurse
    $installer=Join-Path $pkg 'Install-Japanese-Books.ps1';Copy-Item -LiteralPath (Join-Path $repo 'tools/Install-Japanese-Books.ps1') -Destination $installer
    $instance=Join-Path $fixtureRoot 'instance';$mods=Join-Path $instance 'mods';[IO.Directory]::CreateDirectory($mods)|Out-Null
    $manifestPath=Join-Path $pkg 'legacy-book-index.json';$meta=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8|ConvertFrom-Json
    $originals=@{}
    foreach($book in $meta.books){
        $jar=Join-Path $mods $book.jar;$zip=[IO.Compression.ZipFile]::Open($jar,[IO.Compression.ZipArchiveMode]::Create)
        try{foreach($name in @('fabric.mod.json','example/Original.class','data/original.json')){$entry=$zip.CreateEntry($name);$writer=[IO.StreamWriter]::new($entry.Open(),[Text.UTF8Encoding]::new($false));try{if($name -eq 'fabric.mod.json'){$writer.Write('{"id":"'+$book.mod+'","version":"test"}')}else{$writer.Write('original-'+$book.mod+'-'+$name)}}finally{$writer.Dispose()}}}finally{$zip.Dispose()}
        $book.jarSha256=Hash $jar;$originals[$book.mod]=$book.jarSha256
    }
    $meta|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $manifestPath -Encoding UTF8
    & $installer -InstancePath $instance -CheckOnly
    foreach($book in $meta.books){Assert ((Hash (Join-Path $mods $book.jar)) -eq $originals[$book.mod]) 'CheckOnly changed a JAR.'}
    # Corrupt a late payload: preflight must leave every JAR unchanged.
    $last=$meta.books[-1];$payload=Join-Path $pkg ('payload/'+$last.mod+'/'+$last.files[0].path);$saved=[IO.File]::ReadAllBytes($payload)
    try{[IO.File]::AppendAllText($payload,' ');Reject {& $installer -InstancePath $instance}}finally{[IO.File]::WriteAllBytes($payload,$saved)}
    foreach($book in $meta.books){Assert ((Hash (Join-Path $mods $book.jar)) -eq $originals[$book.mod]) 'Failed preflight changed a JAR.'}
    & $installer -InstancePath $instance
    $installed=@{}
    foreach($book in $meta.books){
        $jar=Join-Path $mods $book.jar;$installed[$book.mod]=Hash $jar;$zip=[IO.Compression.ZipFile]::OpenRead($jar)
        try{
            Assert ($zip.Entries.Count -eq 3+$book.files.Count) 'Unexpected installed entry count.'
            foreach($name in @('fabric.mod.json','example/Original.class','data/original.json')){$reader=[IO.StreamReader]::new($zip.GetEntry($name).Open());try{$expected=if($name -eq 'fabric.mod.json'){'{"id":"'+$book.mod+'","version":"test"}'}else{'original-'+$book.mod+'-'+$name};Assert ($reader.ReadToEnd() -eq $expected) 'Original data was modified.'}finally{$reader.Dispose()}}
            foreach($file in $book.files){Assert ($null -ne $zip.GetEntry($file.path)) 'A translated file was not installed.'}
        }finally{$zip.Dispose()}
    }
    & $installer -InstancePath $instance
    foreach($book in $meta.books){Assert ((Hash (Join-Path $mods $book.jar)) -eq $installed[$book.mod]) 'Reinstallation was not idempotent.'}
    # An updated/user-edited JAR must not be overwritten by restore.
    $firstJar=Join-Path $mods $meta.books[0].jar;$saved=[IO.File]::ReadAllBytes($firstJar)
    try{[IO.File]::AppendAllText($firstJar,'changed');$changed=Hash $firstJar;Reject {& $installer -InstancePath $instance -Restore};Assert ((Hash $firstJar) -eq $changed) 'Restore overwrote an unknown JAR.'}finally{[IO.File]::WriteAllBytes($firstJar,$saved)}
    & $installer -InstancePath $instance -Restore
    foreach($book in $meta.books){Assert ((Hash (Join-Path $mods $book.jar)) -eq $originals[$book.mod]) 'Restore did not recover exact original bytes.'}
    & $installer -InstancePath $instance -Book ad_astra
    foreach($book in $meta.books|Where-Object mod -ne 'ad_astra'){Assert ((Hash (Join-Path $mods $book.jar)) -eq $originals[$book.mod]) 'Book selection changed another mod.'}
    & $installer -InstancePath $instance -Restore -Book ad_astra
    # Filenames are not identity: exercise a leading space and arbitrary rename.
    $adPath=Join-Path $mods (' '+$meta.books[0].jar)
    [IO.File]::Move((Join-Path $mods $meta.books[0].jar),$adPath)
    $drawerPath=Join-Path $mods 'renamed-drawers.jar'
    [IO.File]::Move((Join-Path $mods $meta.books[1].jar),$drawerPath)
    & $installer -InstancePath $instance -CheckOnly
    Assert ((Hash $adPath) -eq $originals['ad_astra']) 'Renamed CheckOnly changed Ad Astra.'
    & $installer -InstancePath $instance
    $adInstalled=Hash $adPath;$drawerInstalled=Hash $drawerPath
    & $installer -InstancePath $instance
    Assert ((Hash $adPath) -eq $adInstalled) 'Leading-space JAR was not idempotent.'
    Assert ((Hash $drawerPath) -eq $drawerInstalled) 'Renamed JAR was not idempotent.'
    $duplicate=Join-Path $mods 'duplicate-astra.jar';[IO.File]::Copy($adPath,$duplicate,$false)
    try{Reject {& $installer -InstancePath $instance -CheckOnly}}finally{Remove-Item -LiteralPath $duplicate}
    # Simulate a launcher moving an installed JAR away. Do not silently skip it.
    $removedDrawer=Join-Path $fixtureRoot 'drawer-moved-outside-mods.jar'
    [IO.File]::Move($drawerPath,$removedDrawer)
    Reject {& $installer -InstancePath $instance -CheckOnly}
    $recovered=Join-Path $mods $meta.books[1].jar
    & $installer -InstancePath $instance -RecoverMissing -CheckOnly
    Assert (-not (Test-Path -LiteralPath $recovered)) 'Recovery CheckOnly created a JAR.'
    # An invalid original backup must never be used to recover a missing mod.
    $backup=Join-Path $instance ('.create-astral-ja-books-backups/extended_drawers-'+$originals['extended_drawers']+'.jar.bak')
    $savedBackup=[IO.File]::ReadAllBytes($backup)
    try{[IO.File]::AppendAllText($backup,'corrupt');Reject {& $installer -InstancePath $instance -RecoverMissing}}finally{[IO.File]::WriteAllBytes($backup,$savedBackup)}
    Assert (-not (Test-Path -LiteralPath $recovered)) 'Corrupt backup produced a recovered JAR.'
    & $installer -InstancePath $instance -RecoverMissing
    Assert (Test-Path -LiteralPath $recovered) 'Verified missing JAR was not recovered.'
    $restoredZip=[IO.Compression.ZipFile]::OpenRead($recovered)
    try{foreach($file in $meta.books[1].files){Assert ($null -ne $restoredZip.GetEntry($file.path)) 'Recovered JAR is missing a translated page.'}}finally{$restoredZip.Dispose()}
    & $installer -InstancePath $instance -Restore
    Assert ((Hash $adPath) -eq $originals['ad_astra']) 'Renamed Ad Astra did not restore exactly.'
    Assert ((Hash $recovered) -eq $originals['extended_drawers']) 'Recovered drawers did not restore exactly.'
    Assert ((Hash (Join-Path $mods $meta.books[2].jar)) -eq $originals['phonos']) 'Phonos did not restore exactly.'
    $meta.books[0].files[0].path='../outside.json';$meta|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $manifestPath -Encoding UTF8
    Reject {& $installer -InstancePath $instance -CheckOnly}
    Write-Output 'PASS: preflight, payload checks, preservation, renamed/space-prefixed JARs, duplicates, missing JAR detection/recovery, idempotency, restore, selection, paths.'
}finally{
    $resolved=[IO.Path]::GetFullPath($fixtureRoot);$parent=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
    if($resolved.StartsWith($parent,[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($resolved) -match '^create-astral-ja-test-[a-f0-9]{32}$' -and (Test-Path -LiteralPath (Join-Path $resolved '.test-fixture'))){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
