# Build a shareable kit; exclude machine-local SSH and archived diagnostics.
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$releasePath = Join-Path $projectRoot 'dist/android-tv16-steamdeck.zip'
New-Item -ItemType Directory -Path (Join-Path $projectRoot 'dist') -Force | Out-Null
$names = @('README.md', 'LICENSE', '.gitattributes', 'install.sh', 'start.sh', 'add-to-steam.sh', 'doctor.sh', 'runtime', 'scripts', 'docs', 'tests')
$sources = $names | ForEach-Object { Join-Path $projectRoot $_ }
$stagePath = Join-Path $projectRoot ('dist/staging-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stagePath | Out-Null
foreach ($source in $sources) {
    $sourceItem = Get-Item -LiteralPath $source
    if ($sourceItem.PSIsContainer) {
        $files = Get-ChildItem -LiteralPath $source -File -Recurse | Where-Object { $_.Extension -ne '.pyc' -and $_.FullName -notmatch '[\\/]__pycache__[\\/]' }
        foreach ($file in $files) {
            $relativePath = $file.FullName.Substring($projectRoot.Length + 1)
            $targetPath = Join-Path $stagePath $relativePath
            New-Item -ItemType Directory -Path (Split-Path -Parent $targetPath) -Force | Out-Null
            Copy-Item -LiteralPath $file.FullName -Destination $targetPath
        }
    } else {
        Copy-Item -LiteralPath $source -Destination (Join-Path $stagePath $sourceItem.Name)
    }
}
$stagedItems = Get-ChildItem -LiteralPath $stagePath -Force | Select-Object -ExpandProperty FullName
# Windows PowerShell Compress-Archive writes backslash entry names, which
# cause warnings on Linux. Windows' bsdtar writes portable ZIP paths instead.
$entryNames = Get-ChildItem -LiteralPath $stagePath -Force | Select-Object -ExpandProperty Name
& tar.exe -a -cf $releasePath -C $stagePath @entryNames
if ($LASTEXITCODE -ne 0) { throw 'ZIP creation failed' }
# Delete only this validated, generated staging directory; source files stay intact.
$resolvedStage = (Resolve-Path -LiteralPath $stagePath).Path
$expectedDist = (Resolve-Path -LiteralPath (Join-Path $projectRoot 'dist')).Path
if ((Split-Path -Parent $resolvedStage) -ne $expectedDist -or (Split-Path -Leaf $resolvedStage) -notmatch '^staging-[0-9a-f]{32}$') { throw 'Unsafe staging path' }
Remove-Item -LiteralPath $resolvedStage -Recurse -Force
Get-FileHash -Algorithm SHA256 -LiteralPath $releasePath
Write-Output "Release: $releasePath"
