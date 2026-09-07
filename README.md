# TeamKit-M installers

| Computer | Install |
| --- | --- |
| Mac (Apple silicon or Intel) | Open Terminal and paste: `curl -fsSL https://raw.githubusercontent.com/lablelee/cx-artifact-teamkit-m/main/bootstrap/install-teamkit.sh \| sh` |
| Windows 64-bit | Download [TeamKit for Windows](bootstrap/TeamKit-Setup-Windows.zip?raw=1), unzip it, and open `TeamKit-Setup.exe` |

The Mac installer is a plain shell script rather than a downloadable program
because macOS Gatekeeper blocks an unsigned program that arrives through a
browser but not a script run in Terminal; the components it downloads are
verified and carry no quarantine flag.

The installer prompts for the TeamKit APIM gateway URL and key, then prepares
Claude, Codex, Copilot, Zed, or all supported clients (default: all). To
preselect one, add `-s -- --client codex` after `sh` on Mac, or run
`TeamKit-Setup.exe --client codex` on Windows. After setup, open a new
terminal and run `tk`.

Do not download files under `stable/` manually. The installer selects the
correct platform components and verifies their SHA-256 hashes using
`stable/latest.json`.
