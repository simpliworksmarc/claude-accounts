# add-claude-account.ps1: gives this machine one more Claude account as its own VS Code window, in one run.
#
# Claude Code keeps everything about a sign in inside one folder (%USERPROFILE%\.claude by default), and its VS Code
# extension runs Claude with whatever folder the setting claudeCode.environmentVariables names in CLAUDE_CONFIG_DIR.
# One VS Code window can only hold one value of that setting, so a second account is a second VS Code window with its
# own settings folder: the same VS Code install, the same extensions, a different colour and title, and Claude signed
# in as the other account. Both windows can have the same project open, and both see the same past chats, because the
# new account's conversation folder is a junction to the main one.
#
# 1. Makes %USERPROFILE%\.claude-<name> with a copy of the main account's settings.json (hooks included), a copy of
#    .claude.json without the main account's sign in record (so MCP servers carry over), CLAUDE.md, and junctions to
#    the main projects and skills folders.
# 2. Makes %USERPROFILE%\.vscode-<name>\User\settings.json from the main VS Code settings plus the account's config
#    folder, a title that names the account, a colour for its title and status bars, and updates left to the main window.
# 3. Writes a launcher, %USERPROFILE%\.claude-accounts\claude-<name>.cmd, that clears every Claude, Anthropic and Codex
#    variable a terminal could hand down and starts VS Code on the account's settings folder.
# 4. Puts a shortcut "Claude · <name>" on the Desktop and in the Start menu, and registers the account in
#    %USERPROFILE%\.claude-accounts.json, which the voice alerts read to say the account's name.
#
# Run from PowerShell:  powershell -ExecutionPolicy Bypass -File .\add-claude-account.ps1 -Name Work
# Options: -Folder opens a project by default, -Colour sets the bar colour (hex), -UserHome, -CodeUserDir and
# -ShortcutFolder point elsewhere for testing, -NoShortcut skips the shortcuts.
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$Folder = "",
    [string]$Colour = "",
    [string]$UserHome = $env:USERPROFILE,
    [string]$CodeUserDir = (Join-Path $env:APPDATA "Code\User"),
    [string]$ShortcutFolder = [Environment]::GetFolderPath("Desktop"),
    [string]$StartMenuFolder = [Environment]::GetFolderPath("Programs"),
    [switch]$NoShortcut
)

$ErrorActionPreference = "Stop"
$utf8 = New-Object Text.UTF8Encoding $false

$Name = $Name.Trim()
if ($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9 _-]{0,30}$') {
    Write-Host "Stopped: the name may hold letters, digits, spaces, dashes and underscores only, and it starts with a letter or digit."
    exit 1
}
$slug = ($Name -replace '\s+', '-').ToLower()
# main and claude are the main account's own folder, and accounts is the folder that holds every launcher.
if ($slug -in @("main", "claude", "accounts")) {
    Write-Host "Stopped: '$Name' names a folder this setup already uses; pick another name."
    exit 1
}
$mainCfg = Join-Path $UserHome ".claude"
$cfg = Join-Path $UserHome ".claude-$slug"
$ud = Join-Path $UserHome ".vscode-$slug"
$launcherDir = Join-Path $UserHome ".claude-accounts"
$launcher = Join-Path $launcherDir "claude-$slug.cmd"
$registry = Join-Path $UserHome ".claude-accounts.json"

function ReadJson([string]$path, [switch]$Jsonc) {
    if (-not (Test-Path $path)) { return $null }
    $text = [IO.File]::ReadAllText($path)
    if (-not $text.Trim()) { return $null }
    if ($Jsonc) {
        # VS Code's settings file allows comments and trailing commas, which Windows PowerShell cannot parse. One pass
        # walks strings, comments and commas in order, so a string is always kept whole (a URL's // or a value such
        # as "a,}" survives), and only comments and a comma that closes an object or list are removed.
        $text = [regex]::Replace($text, '"(?:[^"\\]|\\.)*"|//[^\r\n]*|/\*[\s\S]*?\*/|,(?=(?:\s|//[^\r\n]*|/\*[\s\S]*?\*/)*[}\]])', {
            param($m)
            if ($m.Value.StartsWith('"')) { return $m.Value }
            return ""
        })
    }
    return ($text | ConvertFrom-Json)
}
function WriteJson([string]$path, $obj) {
    [IO.File]::WriteAllText($path, ($obj | ConvertTo-Json -Depth 32), $utf8)
}
function Junction([string]$link, [string]$target) {
    if (Test-Path $link) { return "kept" }
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    New-Item -ItemType Junction -Path $link -Target $target | Out-Null
    return "made"
}

# VS Code itself, wherever it was installed.
$codeExe = ""
foreach ($candidate in @((Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code\Code.exe"), (Join-Path $env:ProgramFiles "Microsoft VS Code\Code.exe"))) {
    if ($candidate -and (Test-Path $candidate)) { $codeExe = $candidate; break }
}
if (-not $codeExe) {
    $cmd = Get-Command code -ErrorAction SilentlyContinue
    if ($cmd) { $probe = Join-Path (Split-Path -Parent (Split-Path -Parent $cmd.Source)) "Code.exe"; if (Test-Path $probe) { $codeExe = $probe } }
}
if (-not $codeExe) { Write-Host "Stopped: VS Code was not found (looked in the user and system install folders and on the PATH)."; exit 1 }

# Everything that can fail is read before anything is created, so a bad file never leaves half an account behind.
$registryObj = $null
try { $registryObj = ReadJson $registry } catch { Write-Host "Stopped: $registry is not valid JSON, so nothing was changed."; exit 1 }
$existing = if ($registryObj -and $registryObj.accounts) { @($registryObj.accounts) } else { @() }
foreach ($a in $existing) {
    if (("$($a.configDir)".TrimEnd('\') -ieq $cfg.TrimEnd('\')) -and ("$($a.name)" -ine $Name)) {
        Write-Host "Stopped: '$Name' would use the folder of the existing account '$($a.name)'; pick a name that differs by more than spaces or dashes."
        exit 1
    }
}
$userDir = Join-Path $ud "User"
$mainSettings = Join-Path $CodeUserDir "settings.json"
$settings = $null
try {
    $settings = ReadJson (Join-Path $userDir "settings.json") -Jsonc
    if (-not $settings) { $settings = ReadJson $mainSettings -Jsonc }
} catch {
    Write-Host "Stopped: VS Code's settings file ($mainSettings) could not be read as JSON, so nothing was changed. Open it in VS Code, fix what it underlines, and run this again."
    exit 1
}
if (-not $settings) { $settings = [pscustomobject]@{} }
$mainUser = Join-Path $UserHome ".claude.json"
$cfgUser = Join-Path $cfg ".claude.json"
$userCopy = $null
$userNote = ""
if ((Test-Path $mainUser) -and -not (Test-Path $cfgUser)) {
    try { $userCopy = ReadJson $mainUser } catch { $userNote = ".claude.json not copied because Windows PowerShell could not read it, so MCP servers have to be added again in this account" }
}

# 1. The account's Claude folder.
New-Item -ItemType Directory -Force -Path $cfg | Out-Null
$made = @()
if ((Test-Path (Join-Path $mainCfg "settings.json")) -and -not (Test-Path (Join-Path $cfg "settings.json"))) {
    Copy-Item (Join-Path $mainCfg "settings.json") (Join-Path $cfg "settings.json"); $made += "settings.json copied"
}
if ((Test-Path (Join-Path $mainCfg "CLAUDE.md")) -and -not (Test-Path (Join-Path $cfg "CLAUDE.md"))) {
    Copy-Item (Join-Path $mainCfg "CLAUDE.md") (Join-Path $cfg "CLAUDE.md"); $made += "CLAUDE.md copied"
}
if ($userCopy) {
    # The sign in record and any stored API key stay with the main account; MCP servers, with their keys, carry over.
    foreach ($key in "oauthAccount", "userID", "primaryApiKey", "customApiKeyResponses") {
        if ($userCopy.PSObject.Properties.Name -contains $key) { $userCopy.PSObject.Properties.Remove($key) }
    }
    WriteJson $cfgUser $userCopy; $made += ".claude.json copied without the main sign in record or API key"
}
if ($userNote) { $made += $userNote }
$made += "projects junction " + (Junction (Join-Path $cfg "projects") (Join-Path $mainCfg "projects"))
if (Test-Path (Join-Path $mainCfg "skills")) { $made += "skills junction " + (Junction (Join-Path $cfg "skills") (Join-Path $mainCfg "skills")) }
Write-Host "1. $cfg ready ($($made -join ', '))"

# 2. The window's settings.
New-Item -ItemType Directory -Force -Path $userDir | Out-Null
if (-not $Colour) {
    # An account keeps the colour it was given, and a new one takes the first colour no other account holds.
    $mine = @($existing | Where-Object { "$($_.configDir)".TrimEnd('\') -ieq $cfg.TrimEnd('\') -and "$($_.colour)" })
    if ($mine.Count) {
        $Colour = "$($mine[0].colour)"
    } else {
        $palette = @("#5b2a86", "#0b6e4f", "#1f4e9c", "#9c3d1f", "#6b6b1f", "#8a1f5c", "#2f6f73", "#7a4b1c")
        $taken = @($existing | ForEach-Object { "$($_.colour)".ToLower() })
        $free = @($palette | Where-Object { $taken -notcontains $_ })
        $Colour = if ($free.Count) { $free[0] } else { $palette[$existing.Count % $palette.Count] }
    }
}
$envList = @()
if ($settings.PSObject.Properties.Name -contains "claudeCode.environmentVariables") {
    foreach ($e in @($settings.'claudeCode.environmentVariables')) { if ("$($e.name)" -ne "CLAUDE_CONFIG_DIR") { $envList += $e } }
}
$envList += [pscustomobject]@{ name = "CLAUDE_CONFIG_DIR"; value = $cfg }
$colours = if ($settings.PSObject.Properties.Name -contains "workbench.colorCustomizations" -and $settings.'workbench.colorCustomizations') { $settings.'workbench.colorCustomizations' } else { [pscustomobject]@{} }
foreach ($pair in @(
        @("titleBar.activeBackground", $Colour), @("titleBar.activeForeground", "#ffffff"),
        @("titleBar.inactiveBackground", $Colour), @("titleBar.inactiveForeground", "#d9d9d9"),
        @("statusBar.background", $Colour), @("statusBar.foreground", "#ffffff"))) {
    $colours | Add-Member -NotePropertyName $pair[0] -NotePropertyValue $pair[1] -Force
}
$settings | Add-Member -NotePropertyName "claudeCode.environmentVariables" -NotePropertyValue ([array]$envList) -Force
$settings | Add-Member -NotePropertyName "window.title" -NotePropertyValue ("Claude " + [char]0x00B7 + " $Name " + [char]0x00B7 + ' ${rootName}${separator}${activeEditorShort}${dirty}') -Force
$settings | Add-Member -NotePropertyName "window.commandCenter" -NotePropertyValue $false -Force
$settings | Add-Member -NotePropertyName "workbench.colorCustomizations" -NotePropertyValue $colours -Force
$settings | Add-Member -NotePropertyName "update.mode" -NotePropertyValue "manual" -Force
$settings | Add-Member -NotePropertyName "extensions.autoUpdate" -NotePropertyValue $false -Force
$json = $settings | ConvertTo-Json -Depth 32
if (-not ($json -match '"claudeCode\.environmentVariables":\s*\[')) { throw "The environment list did not serialise as a list, so nothing was written." }
[IO.File]::WriteAllText((Join-Path $userDir "settings.json"), $json, $utf8)
if ((Test-Path (Join-Path $CodeUserDir "keybindings.json")) -and -not (Test-Path (Join-Path $userDir "keybindings.json"))) {
    Copy-Item (Join-Path $CodeUserDir "keybindings.json") (Join-Path $userDir "keybindings.json")
}
$dot = [string][char]0x00B7
Write-Host "2. $userDir\settings.json written (title 'Claude $dot $Name', bars $Colour, updates left to the main window)"

# 3. The launcher.
New-Item -ItemType Directory -Force -Path $launcherDir | Out-Null
$lines = @(
    "@echo off",
    "rem Opens VS Code as the Claude account '$Name': its own settings folder, so Claude Code signs in to $cfg.",
    "rem Clears what a terminal inside VS Code or a Claude session would hand down, because those variables would",
    "rem reach this window's Claude and an API key would bill that key instead of the account's subscription.",
    "setlocal",
    "for /f `"delims==`" %%V in ('set CLAUDE 2^>nul') do set `"%%V=`"",
    "for /f `"delims==`" %%V in ('set ANTHROPIC 2^>nul') do set `"%%V=`"",
    "for /f `"delims==`" %%V in ('set CODEX 2^>nul') do set `"%%V=`"",
    "for %%V in (ELECTRON_RUN_AS_NODE VSCODE_IPC_HOOK_CLI OPENAI_API_KEY) do set `"%%V=`"",
    "set `"CLAUDE_CONFIG_DIR=$cfg`"",
    "start `"`" `"$codeExe`" --user-data-dir `"$ud`" %*",
    "exit /b 0"
)
[IO.File]::WriteAllText($launcher, (($lines -join "`r`n") + "`r`n"), (New-Object Text.ASCIIEncoding))
Write-Host "3. Launcher written: $launcher"

# 4. Shortcuts and the registry.
if (-not $NoShortcut) {
    $shell = New-Object -ComObject WScript.Shell
    foreach ($place in @($ShortcutFolder, $StartMenuFolder)) {
        if (-not $place) { continue }
        New-Item -ItemType Directory -Force -Path $place | Out-Null
        $lnk = $shell.CreateShortcut((Join-Path $place ("Claude " + [char]0x00B7 + " $Name.lnk")))
        $lnk.TargetPath = $launcher
        $lnk.Arguments = if ($Folder) { "`"$Folder`"" } else { "" }
        $lnk.WorkingDirectory = $UserHome
        $lnk.WindowStyle = 7
        $lnk.IconLocation = "$codeExe,0"
        $lnk.Description = "VS Code signed in to Claude as $Name"
        $lnk.Save()
    }
    Write-Host "4. Shortcut 'Claude $dot $Name' placed on the Desktop and in the Start menu"
} else {
    Write-Host "4. Shortcuts skipped (-NoShortcut)"
}
$accounts = @()
$mainPresent = $false
foreach ($a in $existing) {
    if ("$($a.configDir)".TrimEnd('\') -ieq $cfg.TrimEnd('\')) { continue }
    if ("$($a.configDir)".TrimEnd('\') -ieq $mainCfg.TrimEnd('\')) { $mainPresent = $true }
    $accounts += $a
}
if (-not $mainPresent) { $accounts += [pscustomobject]@{ name = "Main"; configDir = $mainCfg } }
$accounts += [pscustomobject]@{ name = $Name; configDir = $cfg; colour = $Colour }
WriteJson $registry ([pscustomobject]@{ accounts = [array]$accounts })
Write-Host "   Registered in $registry, so the voice alerts say '$Name'"
Write-Host "Done. Open the shortcut, and in its Claude panel choose the Claude.ai sign in for this account; the window is the one with $Colour bars."
