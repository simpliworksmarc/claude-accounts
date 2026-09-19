# Installing Claude accounts and voice alerts

This file sets up a Windows machine so each Claude account opens in its own VS Code window. Claude speaks an alert and shows a Windows notification that names the account whenever it needs you or finishes. Claude Code in VS Code does the setup itself. You paste one prompt, and after that you only sign in to each account and send one short message in each new window.

## Before pasting

1. In step 3 of the prompt, replace `[NAMES]` with the name each extra account should show on its window, such as `Work`. Replace `[PROJECT FOLDER]` with the folder you usually open in VS Code.

2. Open VS Code with Claude Code signed in to your main account, and paste everything below the line into the Claude panel.

---

Set up this Windows machine so I can run more than one Claude account in VS Code, each in its own window, with spoken alerts and a Windows notification that name the account. Do every step yourself in this session. I will do only two things by hand: sign in to each Claude account in my browser, and send one short message in each new window. Never ask me for, read or enter a password, code or key.

1. Clone the two public repositories at their release tag into `%USERPROFILE%\Tools`, with `git clone --branch v1.0.0 https://github.com/simpliworksmarc/claude-accounts` and `git clone --branch v1.0.0 https://github.com/simpliworksmarc/voice-alerts`. They need no sign in, and the tag means you run exactly the version these instructions describe. If Git is missing, install it with `winget install --id Git.Git -e` and tell me before you do. Read both README files and every script before you run anything, and tell me in one short paragraph what the scripts will change on this machine.

2. Install the voice alerts first, so that every account added afterwards inherits them. Run `powershell -ExecutionPolicy Bypass -File .\install.ps1` in the voice-alerts folder. It adds three hooks to every Claude settings file on this machine, keeps everything else in those files, and renders the spoken lines with a Windows voice. If Python 3 is present, it also installs pystray 0.19.5 and a recent pillow from PyPI for my user and adds a tray icon with a mute switch to my Startup folder. At the end it plays "Task completed" once. Tell me what the last log line says. If Python was missing, say so and move on, because the alerts work without the tray.

3. In the claude-accounts folder, run `powershell -ExecutionPolicy Bypass -File .\add-claude-account.ps1 -Name "<name>" -Folder "[PROJECT FOLDER]"` once for each of these names: [NAMES]. Each run creates:
   1. `%USERPROFILE%\.claude-<name>`, which holds that account's sign in.
   2. A VS Code settings folder whose title bar reads "Claude · <name>" in its own colour.
   3. A launcher.
   4. A shortcut named "Claude · <name>" on the Desktop and in the Start menu.
   5. A registry entry, so the alerts say the account's name.

   Each new account gets a copy of the main account's Claude settings and MCP server list, including any keys written in those servers' settings, but not the main account's sign in or stored API key. Tell me which MCP servers were copied, so I can decide whether the second account should keep them. Past chats are shared, because the new account's conversation folder points at the main one. After the first run the main account is registered as "Main", so its alerts end with "Main" too. Then run the voice-alerts installer once more, so the new names are rendered ahead of time.

4. Open each new shortcut from PowerShell with `explorer.exe` on its `.lnk` file, because a window started from your own shell would inherit that shell's variables. If that command is refused, tell me to double click the shortcut myself. Then stop and tell me which windows are open, because I sign in there myself. In each window's Claude panel I will choose the Claude.ai sign in and use the account that belongs to that window. Each account must be mine alone, because Anthropic's terms forbid sharing an account or making it available to anyone else.

5. When I tell you I have signed in and sent one short message in each window, prove the setup from the files:
   1. The title in each `%USERPROFILE%\.vscode-<name>\User\settings.json` names its account.
   2. Every `%USERPROFILE%\.claude*\settings.json` that belongs to an account carries the three voice-alerts hooks.
   3. `%USERPROFILE%\.claude\hooks\voice-alerts\voice-alerts.log` holds a line reading "played finished (rendered with the name)" with `account=<name>` for each window. That line proves the window's Claude ran as that account.

   If the log says "notification not shown", tell me to turn on notifications for Windows PowerShell under Settings, System, Notifications. Otherwise ask me whether the notification appeared, because you cannot see it.

6. Report as a numbered list: what exists now, what the log shows for each account, and anything that failed, with its exact error.
