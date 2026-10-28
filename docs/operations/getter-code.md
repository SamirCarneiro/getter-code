# Build and run Getter Code

Getter Code is the Getter desktop coding workspace based on the MIT-licensed
[T3 Code](https://github.com/pingdotgg/t3code). Keep the internal package names and
orchestration protocol compatible with upstream when updating the fork.
[Getter Tots](https://github.com/SamirCarneiro/getter-tots) is its local agent
companion, based on [T3 Tots](https://github.com/Deepusleepy/t3-tots).

The initial Getter base is T3 Code `0.1.3` at upstream commit
`67661cfbb57fd353845c6f3c8c96663560031d1e`. Refresh upstream deliberately so the
Getter runtime and companion stay compatible with the selected revision.

## Windows development

Run these commands in the Getter Code checkout:

```powershell
./scripts/getter/setup.ps1
./Start-Getter-Code.ps1
```

Setup downloads the exact Node version pinned by the repository, verifies its
official SHA-256 checksum, and installs the pinned Vite+ and pnpm tools under
`%LOCALAPPDATA%/GetterCode/toolchain`. It does not change the system Node or PATH.
Use `-ToolchainHome <path>` on both commands for a different location.

The default command starts the Electron desktop with the local renderer. To run
only the web stack, use `-Mode web`; to run only the backend, use `-Mode server`.
The source launcher uses `<checkout>/.getter-code` for data and disables importing
existing T3 state. `-HomeDirectory <path>` selects another Getter data directory.
The installed desktop uses `~/.getter-code` by default. Explicit `T3CODE_HOME`
remains supported for compatibility.

Read the actual local ports from the dev-runner output. No browser opens
automatically. Treat any pairing URL printed at startup as a private credential.

## Connect Getter Tots

Clone Getter Tots next to Getter Code. Point its commands at the exact home used
by the running desktop or source launcher:

```powershell
$env:GETTER_HOME = Join-Path (Get-Location) '.getter-code'
node ../getter-tots/tools/getterq health
node ../getter-tots/tools/getterq overview
node ../getter-tots/tools/getterctl skills list
Remove-Item Env:GETTER_HOME
```

Database queries open SQLite read-only. Skills can be listed and verified without
a token. Authenticated thread commands require a separately authorized token
issued by the running Getter server. Follow Getter Tots' setup instructions for
that step. Its approval guards apply to thread actions. Webhook delivery and
listener installation are optional setup steps.

## Validation and packaging

```powershell
./Start-Getter-Code.ps1 -Mode check
./Start-Getter-Code.ps1 -Mode build
./Start-Getter-Code.ps1 -Mode package
```

The Windows package additionally needs Rust, Python, the Visual Studio C++ build
tools, Windows SDK and MSVC Spectre libraries documented by upstream. Local
packages are unsigned and written to `release/`. Release downloads and updates
belong to `SamirCarneiro/getter-code`; create a Getter release before enabling
updates in a distributed build.

Both forks retain the original MIT notices. Maintain the third-party license
notices when distributing desktop packages.
