# TeamKit-m installers

TeamKit-m is a local, multi-agent workspace for CI360 and repository work. It
installs a verified TeamKit command-line client, a local read-only CI360
knowledge bundle, and launchers for Claude, Codex, GitHub Copilot, and Zed.

The goal is to give a teammate a reproducible setup without building Go code
or manually assembling a KB bundle. The installer selects the correct platform
files, verifies their SHA-256 hashes before use, and keeps the gateway URL and
key in the user's local configuration rather than this repository.

Current release: **0.1.76**.

## Before you start

You need:

- a 64-bit Windows PC or a Mac with Apple silicon or Intel hardware;
- the TeamKit HTTPS APIM gateway URL and APIM key from your administrator;
- the client you plan to use already installed, such as GitHub Copilot CLI;
- GitHub Copilot authentication for the normal Copilot route.

The installer does not install Copilot, Claude, Codex, or Zed for you.

On Windows, TeamKit supports **Visual Studio Code with Claude Code chat** and
with GitHub Copilot. It does not require the full Visual Studio IDE, a
compiler, Go, Python, PowerShell, or administrator access. Claude Code and
GitHub Copilot are separate clients; install the one you intend to use, or
both.

## Choose a client

The normal Windows and macOS installers prepare all four supported clients:

| Client | What TeamKit-m provides |
| --- | --- |
| Claude | A managed TeamKit workspace launcher. |
| Codex | A managed TeamKit workspace launcher. |
| GitHub Copilot | A managed workspace launcher and the optional APIM BYOK fallback. |
| Zed | A workspace launcher with TeamKit policy files. |

After installing all clients, choose the default with `tk --default claude`,
`tk --default codex`, `tk --default copilot`, or `tk --default zed`. The
platform-specific install sections below also show how to install one selected
client only.

## Install on macOS

1. Open **Terminal**.
2. Paste and run:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/lablelee/cx-artifact-teamkit-m/main/bootstrap/install-teamkit.sh | sh
   ```

3. Enter the TeamKit gateway URL and APIM key when prompted. The key input is hidden.
4. Wait for `TeamKit 0.1.76 is ready`.
5. Open a new Terminal window and run `tk`.

The installer detects Apple silicon versus Intel and downloads the matching
bundle. macOS uses a readable shell bootstrap because unsigned downloaded apps
are blocked by Gatekeeper; every downloaded component is hash-checked before it
runs.

To install only one client, add one of these after `sh`:

```sh
-s -- --client claude
-s -- --client codex
-s -- --client copilot
-s -- --client zed
```

## Install on Windows

These steps work on Windows 11 without administrator access.

1. Install [Visual Studio Code](https://code.visualstudio.com/) and the
   [Claude Code extension](https://marketplace.visualstudio.com/items?itemName=anthropic.claude-code).
   Sign in to Claude Code when it opens. GitHub Copilot is optional; install
   its CLI or VS Code extension only if you plan to use Copilot too.
2. Download [TeamKit Setup for Windows](bootstrap/TeamKit-Setup-Windows.zip?raw=1).
3. Right-click the ZIP, choose **Extract All**, then double-click
   `TeamKit-Setup.exe` in the extracted folder.
4. At the gateway prompt, enter `https://cx-ai-apim.azure-api.net/ai`.
   At the next prompt, enter the APIM key supplied to you. The key is hidden.
5. Wait for the `TeamKit 0.1.76 is ready` message, then open the prepared
   workspace in VS Code from a new Command Prompt:

```text
code %LOCALAPPDATA%\TeamKit\workspace
```

6. Trust the workspace when VS Code asks. Open the Claude Code panel from the
   Spark icon in the Activity Bar and start a chat. TeamKit has already placed
   `CLAUDE.md` and `.mcp.json` in this workspace. Review and approve its local
   MCP servers when Claude Code offers them.

### Route Claude Code chat through the TeamKit APIM gateway

The `tk` terminal launcher already reads the APIM URL and key entered during
installation. The VS Code Claude Code extension has its own bundled CLI, so
configure its gateway once in VS Code as well:

1. Press `Ctrl+Shift+P`, choose **Preferences: Open User Settings (JSON)**.
2. Add the following setting, replacing `<your-APIM-key>` with the same key
   used by the installer. If the file already has settings, add this property
   inside its existing outer `{ ... }` object and keep the comma separators.

   ```json
   "claudeCode.environmentVariables": [
     { "name": "ANTHROPIC_BASE_URL", "value": "https://cx-ai-apim.azure-api.net/ai" },
     { "name": "ANTHROPIC_API_KEY", "value": "<your-APIM-key>" }
   ]
   ```

3. Run **Developer: Reload Window**, then start a new Claude Code chat.

This uses APIM's `x-api-key` route. Do not put the APIM key in the TeamKit
workspace or commit it to a repository.

For GitHub Copilot terminal use, confirm that `copilot --version` works in
Command Prompt, then run `tk --default copilot` and `tk`.

If Windows SmartScreen displays a warning for this new unsigned executable,
choose **More info**, then **Run anyway**. The installer verifies the catalog
checksums before extracting its components.

To install only one client, run one of these commands instead:

```text
TeamKit-Setup.exe --client claude
TeamKit-Setup.exe --client codex
TeamKit-Setup.exe --client copilot
TeamKit-Setup.exe --client zed
```

## Use GitHub Copilot

The normal Copilot launcher uses the user's GitHub Copilot subscription and is
the default route. Sign in with `copilot login` if the CLI has not already been
authenticated, then start TeamKit with `tk`.

TeamKit also includes an explicit BYOK fallback for when the normal Copilot
subscription reaches its usage limit. It uses the same APIM gateway configured
during installation and never replaces the normal Copilot route.

| Platform | Start the gateway fallback | Choose Claude instead of Luna |
| --- | --- | --- |
| Windows | Open `Copilot TeamKit (Gateway).cmd` | Set `TEAMKIT_COPILOT_MODEL=claude` before launching. |
| macOS | `teamkit gateway copilot-launch --model luna --` | Replace `luna` with `claude`. |

The gateway launcher defaults to Luna. It passes the selected model family to
Copilot with the matching provider request format and protects the gateway
credential from shell and MCP child-process environments.

## Direct Copilot installer ZIPs

Use these if you want a self-contained, Copilot-preselected installer rather
than the normal bootstrap. They are optional; the normal installers above are
the right choice when you use more than one client.

- [Windows](pilots/TeamKit-Windows-Copilot-Gateway-0.1.76.zip?raw=1)
- [macOS Apple silicon](pilots/TeamKit-macOS-AppleSilicon-Copilot-Gateway-0.1.76.zip?raw=1)
- [macOS Intel](pilots/TeamKit-macOS-Intel-Copilot-Gateway-0.1.76.zip?raw=1)

On Windows, run `Install-TeamKit.exe` after extracting the ZIP. On macOS, open
the extracted `install.command` file. Both variants still ask for the gateway
URL and APIM key locally.

## Release contents

`stable/latest.json` is the release catalog used by the bootstrap installers.
It references platform-specific TeamKit core ZIPs and their matching immutable
Go CI360 KB bundles. The files under `stable/` are components, not standalone
downloads; use the bootstrap installer or one of the direct Copilot ZIPs above.
