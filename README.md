# TeamKit-M installers

No coding experience needed — just copy, paste, and answer two questions.
Pick your computer below.

## Mac (Apple silicon or Intel)

1. Open **Terminal**. (Press `Cmd + Space`, type `Terminal`, press `Enter`.)
2. Copy this line, paste it into the Terminal window, and press `Enter`:
   ```
   curl -fsSL https://raw.githubusercontent.com/lablelee/cx-artifact-teamkit-m/main/bootstrap/install-teamkit.sh | sh
   ```
3. It will ask for two things, one at a time:
   - **Your TeamKit gateway URL** — paste it and press `Enter`. (Ask whoever
     gave you access to TeamKit if you don't have this.)
   - **Your TeamKit key** — paste it and press `Enter`. Nothing will appear
     on screen as you type or paste — that's normal, it's hiding it on
     purpose, like a password field.
4. Wait for `TeamKit 0.1.75 is ready` (or similar). That's it — installed.
5. Open a **new** Terminal window and type `tk` to start using it.

You will *not* see a download link or a program icon to double-click for
Mac — that's intentional. Apple's security check (Gatekeeper) blocks
downloaded programs it doesn't recognize, even safe ones, so we install
through this one-line command instead, which Gatekeeper doesn't block. Full
technical reason: see "Why the Mac install works this way" below.

## Windows 64-bit

1. Download [TeamKit for Windows](bootstrap/TeamKit-Setup-Windows.zip?raw=1).
2. Unzip the downloaded file (right-click it → "Extract All").
3. Open the unzipped folder and double-click `TeamKit-Setup.exe`.
4. If Windows shows a blue "Windows protected your PC" screen, click
   **More info**, then **Run anyway**. This can happen for new, less-common
   programs; TeamKit is still verifying its own files against a checksum
   during setup either way.
5. Answer the same two questions as above (gateway URL, then key).
6. After it finishes, open a new terminal/command prompt and type `tk`.

## Advanced options (optional, skip if unsure)

The installer prepares Claude, Codex, Copilot, and Zed by default (all of
them). To set up only one, add `-s -- --client codex` after `sh` on Mac, or
run `TeamKit-Setup.exe --client codex` on Windows (swap `codex` for `claude`,
`copilot`, or `zed`).

Do not download files under `stable/` manually. The installer selects the
correct platform components and verifies their SHA-256 hashes using
`stable/latest.json`.

### Why the Mac install works this way

macOS Gatekeeper blocks an unsigned program that arrives through a browser
download, but not a script run in Terminal — so the Mac installer is a
plain, readable shell script rather than a downloadable program. Every
component it fetches is verified (SHA-256 checked) before anything runs, and
nothing it downloads carries the "quarantine" flag that would normally
trigger a Gatekeeper warning.
