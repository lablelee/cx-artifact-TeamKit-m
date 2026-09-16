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

To install only Copilot, add `-s -- --client copilot` after `sh`.

## Install on Windows

1. Download [TeamKit Setup for Windows](bootstrap/TeamKit-Setup-Windows.zip?raw=1).
2. Extract the ZIP, then double-click `TeamKit-Setup.exe`.
3. Enter the TeamKit gateway URL and APIM key when prompted.
4. Open a new Command Prompt and run `tk`.

If Windows SmartScreen displays a warning for this new unsigned executable,
choose **More info**, then **Run anyway**. The installer verifies the catalog
checksums before extracting its components.

To install only Copilot, run `TeamKit-Setup.exe --client copilot`.

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
than the normal bootstrap:

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
