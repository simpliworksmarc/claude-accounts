# remove-claude-account.ps1: takes an account's window away again.
#
# 1. Stops if the account's window is open, before anything is removed, so a refused run changes nothing.
# 2. Removes the shortcuts, the launcher and the window's settings folder (%USERPROFILE%\.vscode-<name>).
# 3. Takes the account out of %USERPROFILE%\.claude-accounts.json.
# 4. Keeps %USERPROFILE%\.claude-<name>, because it holds the sign in, unless -DeleteLogin is given; then its
#    junctions are unlinked first, so the shared past chats and skills of the main account are never touched.
#
# Run from PowerShell:  powershell -ExecutionPolicy Bypass -File .\remove-claude-account.ps1 -Name Work
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [switch]$DeleteLogin,
    [string]$UserHome = $env:USERPROFILE,
    [string]$ShortcutFolder = [Environment]::GetFolderPath("Desktop"),
    [string]$StartMenuFolder = [Environment]::GetFolderPath("Programs")
)

$ErrorActionPreference = "Stop"
$utf8 = New-Object Text.UTF8Encoding $false
$Name = $Name.Trim()
# The same rule as add-claude-account.ps1, so a wildcard or a path can never reach a delete below.
if ($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9 _-]{0,30}$') {
    Write-Host "Stopped: '$Name' is not an account name this setup could have made."
    exit 1
}
$slug = ($Name -replace '\s+', '-').ToLower()
if ($slug -in @("main", "claude", "accounts")) { Write-Host "Stopped: '$Name' is not an added account."; exit 1 }
$cfg = Join-Path $UserHome ".claude-$slug"
$ud = Join-Path $UserHome ".vscode-$slug"
$launcher = Join-Path (Join-Path $UserHome ".claude-accounts") "claude-$slug.cmd"
$registry = Join-Path $UserHome ".claude-accounts.json"
$dot = [string][char]0x00B7

# The shortcut carries the name the account was added with, which may be spelled differently from the one given here.
$shortcutNames = @($Name)
if (Test-Path -LiteralPath $registry) {
    try {
        foreach ($a in @(([IO.File]::ReadAllText($registry) | ConvertFrom-Json).accounts)) {
            if ("$($a.configDir)".TrimEnd('\') -ieq $cfg.TrimEnd('\') -and "$($a.name)") { $shortcutNames += "$($a.name)" }
        }
    } catch {}
}

# 1. The open window check, first.
$udPattern = [System.Management.Automation.WildcardPattern]::Escape($ud)
$running = Get-CimInstance Win32_Process -Filter "Name = 'Code.exe'" -ErrorAction SilentlyContinue | Where-Object { "$($_.CommandLine)" -like "*--user-data-dir*$udPattern*" }
if ($running) { Write-Host "Stopped: the '$Name' window is open (VS Code pid $(@($running)[0].ProcessId)); close it and run this again. Nothing was removed."; exit 1 }

# 2. Shortcuts, launcher, window folder.
foreach ($place in @($ShortcutFolder, $StartMenuFolder)) {
    if (-not $place) { continue }
    foreach ($n in ($shortcutNames | Select-Object -Unique)) {
        $lnk = Join-Path $place "Claude $dot $n.lnk"
        if (Test-Path -LiteralPath $lnk) { Remove-Item -LiteralPath $lnk -Force }
    }
}
if (Test-Path -LiteralPath $launcher) { Remove-Item -LiteralPath $launcher -Force }
if (Test-Path -LiteralPath $ud) { Remove-Item -LiteralPath $ud -Recurse -Force }
Write-Host "1. Shortcuts, launcher and $ud removed"

# 3. The registry.
$obj = $null
if (Test-Path -LiteralPath $registry) { $text = [IO.File]::ReadAllText($registry); if ($text.Trim()) { $obj = $text | ConvertFrom-Json } }
if ($obj -and $obj.accounts) {
    $kept = @(@($obj.accounts) | Where-Object { "$($_.configDir)".TrimEnd('\') -ine $cfg.TrimEnd('\') })
    [IO.File]::WriteAllText($registry, ([pscustomobject]@{ accounts = [array]$kept } | ConvertTo-Json -Depth 8), $utf8)
}
Write-Host "2. Account taken out of $registry"

# 4. The Claude folder, only on request, junctions unlinked first.
if ($DeleteLogin) {
    if (Test-Path -LiteralPath $cfg) {
        foreach ($j in "projects", "skills") {
            $p = Join-Path $cfg $j
            if ((Test-Path -LiteralPath $p) -and ((Get-Item -LiteralPath $p -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                [IO.Directory]::Delete($p)      # removes the junction itself and nothing behind it
            }
        }
        Remove-Item -LiteralPath $cfg -Recurse -Force
    }
    Write-Host "3. $cfg deleted, sign in included; the main account's chats and skills were left in place"
} else {
    Write-Host "3. $cfg kept (it holds the sign in); add -DeleteLogin to delete it"
}
Write-Host "Done."
