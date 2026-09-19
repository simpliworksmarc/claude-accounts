# Claude accounts, one VS Code window each

Claude Code keeps everything about a sign in inside one folder, and its VS Code extension can be told which folder to use, but one window can only use one folder. So a second Claude account is a second VS Code window: the same VS Code install and the same extensions, with its own settings folder, a title that names the account, a colour of its own on the title and status bars, and Claude signed in as that account. Both windows can have the same project open, and both list the same past chats, because the new account shares the main account's conversation folder.

This is an independent project and is not made or endorsed by Anthropic. It pairs with [voice-alerts](https://github.com/simpliworksmarc/voice-alerts), which speaks the account's name when Claude needs you or finishes.

## 1. What you need

1.1 Windows 10 or 11 with Windows PowerShell 5.1, VS Code installed for your user or for all users, and the Claude Code extension signed in to your main Claude account in the normal window, because the new window copies that window's settings and the main account's Claude settings.

1.2 Every account used this way must be yours alone, because Anthropic's consumer terms forbid sharing an account or making it available to anyone else. Read Anthropic's terms and usage policy yourself before running several accounts, and do not use this to share accounts or to get around usage limits; it is for keeping your own accounts apart.

1.3 Git to clone this repository at a release tag, such as `git clone --branch v1.0.0 https://github.com/simpliworksmarc/claude-accounts`, or the ZIP from the Code button; after a ZIP download, run `Get-ChildItem -Recurse | Unblock-File` in the folder, because Windows marks downloaded scripts as coming from the internet.

## 2. Adding an account

2.1 Read the scripts before you run them, as you should with any script from the internet, then open PowerShell in this folder and run the add script with the name you want to see on the window and, optionally, the project it should open.

```
powershell -ExecutionPolicy Bypass -File .\add-claude-account.ps1 -Name Work -Folder "C:\projects\my-project"
```

2.2 It reads every file it needs first, so a file it cannot read stops it before anything is created. Then it creates:
   1. `%USERPROFILE%\.claude-<name>`, the account's Claude folder, with a copy of the main account's settings.json, CLAUDE.md and `.claude.json`, and junctions to the main account's `projects` and `skills` folders.
   2. `%USERPROFILE%\.vscode-<name>`, the window's own VS Code settings, copied from the main window's settings and keybindings, with the account's folder handed to Claude Code, a title "Claude · <name> · project", and a colour on the title and status bars.
   3. `%USERPROFILE%\.claude-accounts\claude-<name>.cmd`, a launcher that clears Claude, Anthropic and Codex variables a terminal could hand down, then starts VS Code on the window's settings.
   4. A shortcut "Claude · <name>" on the Desktop and in the Start menu.
   5. An entry in `%USERPROFILE%\.claude-accounts.json`, which voice-alerts reads to say the account's name.

2.3 Open the shortcut, and in the Claude panel of that window choose the Claude.ai sign in and sign in as that account, once.

2.4 Add as many as you need with further names; each keeps its own folder, launcher, shortcut and colour, the colours repeat after eight accounts, and two names that would share a folder, such as "Work Two" and "work-two", are refused, while a name that differs only in capitals renames the same account.

2.5 Options: `-Colour "#1f4e9c"` sets the bar colour, `-NoShortcut` skips the shortcuts, and `-UserHome`, `-CodeUserDir`, `-ShortcutFolder` and `-StartMenuFolder` point the script at other folders for testing.

## 3. What to know before you use it

3.1 The new account's `.claude.json` is a copy of the main one without its sign in record or stored API key, so MCP servers carry over with any keys written in their settings. Delete the servers or keys the second account should not have, from that window's Claude settings or from the file.

3.2 A settings.json with an `env` block carries it over too, so an `ANTHROPIC_API_KEY` there would bill that key in the new account instead of its subscription; remove it from `%USERPROFILE%\.claude-<name>\settings.json` if so.

3.3 Past chats are shared, because the account's conversation folder points at the main one, so a chat started in either window shows in both, and so does the per project memory Claude keeps there. Plugins, custom commands and agents stay separate per account.

3.4 Skills are shared through the junction, so a skill added in either account shows in both.

3.5 Updates of VS Code and of its extensions happen in the main window, because the account windows are set to leave them alone; an update in the main window may ask the account windows to close first.

3.6 Settings and MCP servers are copied at the moment the account is added, so a change made later in one account is not made in the other.

3.7 VS Code Insiders and portable installs are not found; the script looks for the normal user or system install.

## 4. Removing an account

4.1 The remove script refuses while the account's window is open, then deletes the window's shortcuts, launcher and settings folder, takes the account out of the registry, and keeps the account's Claude folder, because that folder holds the sign in. Add `-DeleteLogin` to delete it too; the shared chats and skills of the main account are unlinked first and never deleted.

```
powershell -ExecutionPolicy Bypass -File .\remove-claude-account.ps1 -Name Work
```

## 5. Licence

MIT, in `LICENSE`, so anyone can use, change and share it with the notice kept.
