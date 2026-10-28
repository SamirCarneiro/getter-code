param(
    [ValidateSet('desktop', 'web', 'server', 'build', 'package', 'check')]
    [string]$Mode = 'desktop',
    [string]$HomeDirectory = $env:GETTER_HOME,
    [string]$ToolchainHome = $env:GETTER_TOOLCHAIN_HOME,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$AdditionalArguments
)

$ErrorActionPreference = 'Stop'
if (-not $ToolchainHome) { $ToolchainHome = Join-Path $env:LOCALAPPDATA 'GetterCode/toolchain' }
$toolchainFile = Join-Path $ToolchainHome 'getter-toolchain.json'
if (-not (Test-Path -LiteralPath $toolchainFile)) { throw 'Run scripts/getter/setup.ps1 first, using the same -ToolchainHome.' }
$toolchain = Get-Content -LiteralPath $toolchainFile -Raw | ConvertFrom-Json
if (-not $HomeDirectory) { $HomeDirectory = Join-Path $PSScriptRoot '.getter-code' }
$HomeDirectory = [IO.Path]::GetFullPath($HomeDirectory)
$checkTempRoot = $null
$checkTempDirectory = $null
$savedEnvironment = @{}
foreach ($name in @('PATH', 'VP_HOME', 'TEMP', 'TMP', 'TMPDIR', 'GETTER_HOME', 'T3CODE_HOME', 'T3CODE_NO_BROWSER', 'T3CODE_DEV_SEED', 'T3CODE_DESKTOP_UPDATE_REPOSITORY')) {
    $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
try {
    $env:PATH = $toolchain.nodeFolder + ';' + $toolchain.cliFolder + ';' + (Join-Path $toolchain.tooling 'node_modules/.bin') + ';' + $env:PATH
    if ($Mode -eq 'check') {
        $gitCommand = Get-Command git.exe -ErrorAction SilentlyContinue
        if ($gitCommand) {
            $gitShellDirectory = [IO.Path]::GetFullPath((Join-Path (Split-Path $gitCommand.Source) '../usr/bin'))
            if (Test-Path -LiteralPath (Join-Path $gitShellDirectory 'sh.exe')) { $env:PATH += ';' + $gitShellDirectory }
        }
        # Bundle probes require a temporary directory with no ancestor node_modules.
        $checkTempRoot = Join-Path ([IO.Path]::GetPathRoot($PSScriptRoot)) 'GetterCodeCheckTemp'
        $checkTempDirectory = Join-Path $checkTempRoot ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $checkTempDirectory -Force | Out-Null
        $env:TEMP = $checkTempDirectory
        $env:TMP = $checkTempDirectory
        $env:TMPDIR = $checkTempDirectory
    }
    $env:VP_HOME = Join-Path $ToolchainHome 'vp'
    $env:GETTER_HOME = $HomeDirectory
    $env:T3CODE_HOME = $HomeDirectory
    if ($Mode -eq 'check') {
        Remove-Item Env:GETTER_HOME, Env:T3CODE_HOME -ErrorAction SilentlyContinue
    }
    $env:T3CODE_NO_BROWSER = '1'
    $env:T3CODE_DEV_SEED = '0'
    $env:T3CODE_DESKTOP_UPDATE_REPOSITORY = 'SamirCarneiro/getter-code'
    $task = @{ desktop = 'dev:desktop'; web = 'dev'; server = 'dev:server'; build = 'build:desktop'; package = 'dist:desktop:win:x64'; check = 'check:changed' }[$Mode]
    $arguments = @('run', $task)
    if ($Mode -in @('desktop', 'web', 'server')) { $arguments += @('--home-dir', $HomeDirectory, '--no-seed', '--no-browser') }
    $arguments += $AdditionalArguments
    Push-Location $PSScriptRoot
    try {
        & (Join-Path $toolchain.cliFolder 'vp.exe') @arguments
        $commandExitCode = $LASTEXITCODE
    } finally { Pop-Location }
} finally {
    foreach ($name in $savedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process') }
    if ($checkTempDirectory) {
        $absoluteCheckRoot = [IO.Path]::GetFullPath($checkTempRoot).TrimEnd('\') + '\'
        $absoluteCheckDirectory = [IO.Path]::GetFullPath($checkTempDirectory)
        if (-not $absoluteCheckDirectory.StartsWith($absoluteCheckRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Refusing to clean a check directory outside GetterCodeCheckTemp.' }
        Remove-Item -LiteralPath $absoluteCheckDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}
exit $commandExitCode
