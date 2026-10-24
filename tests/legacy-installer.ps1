$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
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
        try{foreach($name in @('fabric.mod.json','example/Original.class','data/original.json')){$entry=$zip.CreateEntry($name);$writer=[IO.StreamWriter]::new($entry.Open(),[Text.UTF8Encoding]::new($false));try{$writer.Write('original-'+$book.mod+'-'+$name)}finally{$writer.Dispose()}}}finally{$zip.Dispose()}
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
            foreach($name in @('fabric.mod.json','example/Original.class','data/original.json')){$reader=[IO.StreamReader]::new($zip.GetEntry($name).Open());try{Assert ($reader.ReadToEnd() -eq 'original-'+$book.mod+'-'+$name) 'Original data was modified.'}finally{$reader.Dispose()}}
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
    $meta.books[0].files[0].path='../outside.json';$meta|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $manifestPath -Encoding UTF8
    Reject {& $installer -InstancePath $instance -CheckOnly}
    Write-Output 'PASS: preflight, payload checks, original entry preservation, idempotency, safe restore, selection, path rejection.'
}finally{
    $resolved=[IO.Path]::GetFullPath($fixtureRoot);$parent=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
    if($resolved.StartsWith($parent,[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($resolved) -match '^create-astral-ja-test-[a-f0-9]{32}$' -and (Test-Path -LiteralPath (Join-Path $resolved '.test-fixture'))){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
