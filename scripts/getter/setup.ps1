param([string]$ToolchainHome = $env:GETTER_TOOLCHAIN_HOME)

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $ToolchainHome) { $ToolchainHome = Join-Path $env:LOCALAPPDATA 'GetterCode/toolchain' }
$ToolchainHome = [IO.Path]::GetFullPath($ToolchainHome)
$package = Get-Content (Join-Path $repoRoot 'package.json') -Raw | ConvertFrom-Json
$nodeVersion = $package.engines.node
if ($nodeVersion -notmatch '^\d+\.\d+\.\d+$') { throw 'Getter setup requires an exact Node version in package.json.' }
$pnpmVersion = $package.packageManager -replace '^pnpm@', ''
$workspace = Get-Content (Join-Path $repoRoot 'pnpm-workspace.yaml') -Raw
$viteVersion = [regex]::Match($workspace, '(?m)^\s+vite-plus:\s*([^\s]+)').Groups[1].Value
if (-not $viteVersion) { throw 'Cannot find the Vite+ version in pnpm-workspace.yaml.' }
$arch = if ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq 'Arm64') { 'arm64' } else { 'x64' }
$nodeFolder = Join-Path $ToolchainHome "node-v$nodeVersion-win-$arch"
$nodeExe = Join-Path $nodeFolder 'node.exe'
New-Item -ItemType Directory -Force -Path $ToolchainHome | Out-Null
if (-not (Test-Path -LiteralPath $nodeExe)) {
    $archiveName = "node-v$nodeVersion-win-$arch.zip"
    $archivePath = Join-Path $ToolchainHome $archiveName
    $baseUrl = "https://nodejs.org/dist/v$nodeVersion"
    Invoke-WebRequest "$baseUrl/$archiveName" -OutFile $archivePath
    $sums = (Invoke-WebRequest "$baseUrl/SHASUMS256.txt").Content
    $sumLine = $sums -split "`n" | Where-Object { $_.Trim().EndsWith(' ' + $archiveName) } | Select-Object -First 1
    if (-not $sumLine) { throw 'Node archive is absent from the official SHA-256 manifest.' }
    $expected = ($sumLine.Trim() -split '\s+')[0]
    $actual = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $expected) { throw 'Node archive SHA-256 does not match. Nothing was installed.' }
    Expand-Archive -LiteralPath $archivePath -DestinationPath $ToolchainHome -Force
    Remove-Item -LiteralPath $archivePath
}
$previousPath = $env:PATH
$previousVpHome = $env:VP_HOME
try {
    $tooling = Join-Path $ToolchainHome 'tooling'
    $cliRoot = Join-Path $ToolchainHome "cli-v$viteVersion-win-$arch"
    $cliFolder = Join-Path $cliRoot 'package'
    $vpExe = Join-Path $cliFolder 'vp.exe'
    if (-not (Test-Path -LiteralPath $vpExe)) {
        $metadata = Invoke-RestMethod "https://registry.npmjs.org/@voidzero-dev%2Fvite-plus-cli-win32-$arch-msvc/$viteVersion"
        if ($metadata.dist.integrity -notlike 'sha512-*') { throw 'The Vite+ CLI archive has no SHA-512 integrity value.' }
        New-Item -ItemType Directory -Force -Path $cliRoot | Out-Null
        $cliArchive = Join-Path $cliRoot 'cli.tgz'
        Invoke-WebRequest $metadata.dist.tarball -OutFile $cliArchive
        $expectedCliHash = [BitConverter]::ToString([Convert]::FromBase64String($metadata.dist.integrity.Substring(7))).Replace('-', '')
        if ((Get-FileHash -LiteralPath $cliArchive -Algorithm SHA512).Hash -ne $expectedCliHash) { throw 'Vite+ CLI integrity mismatch.' }
        & (Join-Path $env:SystemRoot 'System32/tar.exe') -xzf $cliArchive -C $cliRoot
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $vpExe)) { throw 'Cannot extract the Vite+ CLI.' }
        Remove-Item -LiteralPath $cliArchive
    }
    $env:PATH = $nodeFolder + ';' + $cliFolder + ';' + (Join-Path $tooling 'node_modules/.bin') + ';' + $previousPath
    $env:VP_HOME = Join-Path $ToolchainHome 'vp'
    & (Join-Path $nodeFolder 'npm.cmd') install --prefix $tooling --no-audit --no-fund "vite-plus@$viteVersion" "pnpm@$pnpmVersion"
    if ($LASTEXITCODE -ne 0) { throw 'Getter toolchain installation failed.' }
    @{ nodeFolder = $nodeFolder; cliFolder = $cliFolder; tooling = $tooling; nodeVersion = $nodeVersion } | ConvertTo-Json | Set-Content (Join-Path $ToolchainHome 'getter-toolchain.json') -Encoding UTF8
    Push-Location $repoRoot
    try {
        & $vpExe install --frozen-lockfile
        if ($LASTEXITCODE -ne 0) { throw 'Getter workspace installation failed.' }
    } finally { Pop-Location }
    Write-Host "Getter Code dependencies are ready. Toolchain: $ToolchainHome"
} finally { $env:PATH = $previousPath; $env:VP_HOME = $previousVpHome }
