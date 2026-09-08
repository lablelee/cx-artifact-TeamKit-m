#!/bin/sh
# TeamKit macOS installer. release/build_bootstrap_installers.py fills in the
# placeholder below and publishes the result as install-teamkit.sh.
#
#   curl -fsSL <url>/install-teamkit.sh | sh
#   curl -fsSL <url>/install-teamkit.sh | sh -s -- --client codex
#   sh install-teamkit.sh --catalog /path/to/latest.json      (offline copy)
#
# This is the whole macOS bootstrap, in POSIX shell, end to end. It reads
# stable/latest.json, downloads the TeamKit core and CI360 KB ZIPs for this
# Mac, verifies each one's size and SHA-256 before touching the archive,
# audits every ZIP entry before extracting anything, and then hands both
# bundle directories to install_macos.sh -- itself fetched from the catalog
# and verified the same way. No compiled program is downloaded and run on its
# own: a browser download stamps com.apple.quarantine on a file, Archive
# Utility copies it onto whatever it extracts, and Gatekeeper then refuses an
# unsigned Mach-O; a shell script runs regardless, and files written by curl
# and /usr/bin/unzip carry no quarantine, so the verified binaries inside the
# bundles run without an Apple signature. Nothing read from the catalog or the
# archives is ever eval'd or placed unquoted on a command line. Everything
# runs from main, invoked on the last line, so a truncated download does
# nothing.
set -eu

CATALOG_URL_DEFAULT="https://raw.githubusercontent.com/lablelee/cx-artifact-teamkit-m/main/stable/latest.json"
CATALOG_SCHEMA="teamkit.release-catalog/v1"
MAX_CATALOG_BYTES=1048576
MAX_ARTIFACT_BYTES=2147483648
MAX_EXPANDED_BYTES=4294967296

fail() {
  printf 'TeamKit setup failed: %s\n' "$1" >&2
  exit 1
}

usage() {
  printf 'usage: install-teamkit.sh [--catalog <https-url-or-path>] [--client claude|codex|copilot|zed|all] [--install-root <dir>]\n' >&2
  exit 2
}

cleanup() {
  if [ -n "${TEAMKIT_BOOTSTRAP_KEEP:-}" ]; then
    printf 'TeamKit bootstrap stage kept: %s\n' "$STAGE" >&2
  else
    rm -rf "$STAGE"
  fi
}

# json_object KEY < file: print the balanced {...} object that follows "KEY":
# in the input, ignoring braces inside strings. Fails when KEY is absent.
json_object() {
  awk -v key="$1" '
    BEGIN { RS = "\001" }
    {
      s = $0; n = length(s); needle = "\"" key "\""
      i = index(s, needle); if (i == 0) exit 1
      i += length(needle)
      while (i <= n && substr(s, i, 1) ~ /[ \t\r\n]/) i++
      if (substr(s, i, 1) != ":") exit 1
      i++
      while (i <= n && substr(s, i, 1) ~ /[ \t\r\n]/) i++
      if (substr(s, i, 1) != "{") exit 1
      start = i; depth = 0; instr = 0; esc = 0
      for (; i <= n; i++) {
        c = substr(s, i, 1)
        if (instr) { if (esc) esc = 0; else if (c == "\\") esc = 1; else if (c == "\"") instr = 0; continue }
        if (c == "\"") instr = 1
        else if (c == "{") depth++
        else if (c == "}") { depth--; if (depth == 0) { print substr(s, start, i - start + 1); exit 0 } }
      }
      exit 1
    }'
}

# json_string KEY < object: first "KEY": "value" in the input.
json_string() {
  sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n 1
}

# json_number KEY < object: first "KEY": 123 in the input.
json_number() {
  sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p" | head -n 1
}

# artifact OBJECT LABEL: validate one catalog entry and set ART_PATH, ART_SIZE, ART_SHA.
artifact() {
  ART_PATH=$(printf '%s\n' "$1" | json_string path)
  ART_SIZE=$(printf '%s\n' "$1" | json_number size)
  ART_SHA=$(printf '%s\n' "$1" | json_string sha256)
  printf '%s' "$ART_PATH" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._/-]*$' || fail "$2 has an unsafe catalog path"
  case "$ART_PATH" in
    *..*|*//*|*/) fail "$2 has an unsafe catalog path" ;;
  esac
  printf '%s' "$ART_SIZE" | grep -Eq '^[1-9][0-9]{0,9}$' || fail "$2 has no valid size"
  [ "$ART_SIZE" -le "$MAX_ARTIFACT_BYTES" ] || fail "$2 is larger than the safety limit"
  printf '%s' "$ART_SHA" | grep -Eq '^[0-9a-f]{64}$' || fail "$2 has no valid SHA-256"
}

# fetch RELATIVE_PATH DESTINATION MAX_BYTES: HTTPS only, no redirects
# followed, hard size cap; a token travels in a 0600 header file, never argv.
fetch() {
  if [ "$REMOTE" = 1 ]; then
    curl -fsS --proto '=https' --max-filesize "$3" -H "@$HEADERS" -o "$2" "$BASE/$1" || fail "could not download $1"
  else
    [ -f "$BASE/$1" ] || fail "catalog artifact is missing: $1"
    [ "$(wc -c < "$BASE/$1" | tr -d ' ')" -le "$3" ] || fail "$1 is larger than the safety limit"
    cp "$BASE/$1" "$2"
  fi
}

# verify FILE SIZE SHA256 LABEL: exact byte count and digest, before any use.
verify() {
  actual=$(wc -c < "$1" | tr -d ' ')
  [ "$actual" = "$2" ] || fail "$4 size mismatch ($actual bytes, expected $2)"
  actual=$(/usr/bin/shasum -a 256 "$1" | cut -d ' ' -f 1)
  [ "$actual" = "$3" ] || fail "$4 checksum mismatch"
}

# audit_zip ZIP LABEL: every entry must sit under exactly one top-level
# directory with no absolute, "..", or "." component and no symbolic links,
# and the expanded size must stay under the limit. Prints that directory.
audit_zip() {
  listing="$STAGE/entries"
  /usr/bin/unzip -Z1 "$1" > "$listing" || fail "$2 is not a valid ZIP"
  [ -s "$listing" ] || fail "$2 ZIP is empty"
  if /usr/bin/unzip -Z "$1" | grep -q '^l'; then fail "$2 ZIP contains a symbolic link"; fi
  expanded=$(/usr/bin/unzip -Z -t "$1" | sed -n 's/.* \([0-9][0-9]*\) bytes uncompressed.*/\1/p' | head -n 1)
  [ -n "$expanded" ] && [ "$expanded" -le "$MAX_EXPANDED_BYTES" ] || fail "$2 ZIP expands beyond the safety limit"
  top=
  while IFS= read -r entry; do
    case "$entry" in
      ""|.|..|/*|./*|../*|*/./*|*/../*|*/.|*/..|*\\*) fail "$2 ZIP contains an unsafe path" ;;
    esac
    dir=${entry%%/*}
    [ "$dir" != "$entry" ] || fail "$2 ZIP must contain exactly one bundle directory"
    if [ -z "$top" ]; then
      top=$dir
    elif [ "$top" != "$dir" ]; then
      fail "$2 ZIP must contain exactly one bundle directory"
    fi
  done < "$listing"
  printf '%s\n' "$top"
}

# stage_bundle OBJECT NAME LABEL: fetch, verify, audit, then extract one
# catalog artifact; prints the extracted bundle directory.
stage_bundle() {
  artifact "$1" "$3"
  archive="$STAGE/$2.zip"
  fetch "$ART_PATH" "$archive" "$ART_SIZE"
  verify "$archive" "$ART_SIZE" "$ART_SHA" "$3"
  top=$(audit_zip "$archive" "$3")
  mkdir "$STAGE/$2"
  /usr/bin/unzip -q -n "$archive" -d "$STAGE/$2" || fail "$3 ZIP could not be extracted"
  [ -f "$STAGE/$2/$top/RELEASE_MANIFEST.json" ] || fail "$3 bundle has no RELEASE_MANIFEST.json"
  printf '%s\n' "$STAGE/$2/$top"
}

main() {
  CATALOG=${TEAMKIT_CATALOG_URL:-}
  CLIENT=all
  INSTALL_ROOT=
  while [ $# -gt 0 ]; do
    case "$1" in
      --catalog) [ $# -ge 2 ] || usage; CATALOG=$2; shift 2 ;;
      --client) [ $# -ge 2 ] || usage; CLIENT=$2; shift 2 ;;
      --install-root) [ $# -ge 2 ] || usage; INSTALL_ROOT=$2; shift 2 ;;
      *) usage ;;
    esac
  done
  [ -n "$CATALOG" ] || CATALOG=$CATALOG_URL_DEFAULT
  [ -n "$CATALOG" ] || fail "no release catalog configured; pass --catalog or set TEAMKIT_CATALOG_URL"
  case "$CLIENT" in
    claude|codex|copilot|zed|all) ;;
    *) fail "client must be claude, codex, copilot, zed, or all" ;;
  esac
  [ "$(uname -s)" = Darwin ] || fail "this installer is for macOS; Windows uses TeamKit-Setup-Windows.zip"
  case "$(uname -m)" in
    arm64) PLATFORM=darwin-arm64 ;;
    x86_64) PLATFORM=darwin-amd64 ;;
    *) fail "unsupported macOS architecture: $(uname -m)" ;;
  esac
  case "$CATALOG" in
    https://*) REMOTE=1; BASE=${CATALOG%/*}; command -v curl >/dev/null 2>&1 || fail "curl is required" ;;
    *://*) fail "the catalog must be an HTTPS URL or a local path" ;;
    *) REMOTE=0; [ -f "$CATALOG" ] || fail "catalog file not found: $CATALOG"
       BASE=$(cd "$(dirname "$CATALOG")" && pwd) ;;
  esac

  tmp=${TMPDIR:-/tmp}
  STAGE=$(mktemp -d "${tmp%/}/teamkit-bootstrap.XXXXXX")
  chmod 700 "$STAGE"
  trap cleanup EXIT
  trap 'exit 130' INT TERM
  HEADERS="$STAGE/headers"
  : > "$HEADERS"
  chmod 600 "$HEADERS"
  if [ -n "${TEAMKIT_GITHUB_TOKEN:-}" ]; then
    case "$BASE" in
      https://raw.githubusercontent.com/*|https://github.com/*|https://api.github.com/*|https://objects.githubusercontent.com/*)
        printf 'Authorization: Bearer %s\n' "$TEAMKIT_GITHUB_TOKEN" > "$HEADERS" ;;
    esac
  elif [ -n "${TEAMKIT_CATALOG_TOKEN:-}" ]; then
    printf 'Authorization: Bearer %s\n' "$TEAMKIT_CATALOG_TOKEN" > "$HEADERS"
  fi

  printf 'Reading the TeamKit release catalog...\n' >&2
  fetch "${CATALOG##*/}" "$STAGE/latest.json" "$MAX_CATALOG_BYTES"
  [ "$(json_string schema_version < "$STAGE/latest.json")" = "$CATALOG_SCHEMA" ] || fail "unsupported or incomplete TeamKit release catalog"
  VERSION=$(json_string teamkit_version < "$STAGE/latest.json")
  [ -n "$VERSION" ] || fail "unsupported or incomplete TeamKit release catalog"
  platform_obj=$(json_object "$PLATFORM" < "$STAGE/latest.json") || fail "catalog has no TeamKit package for $PLATFORM"
  core_obj=$(printf '%s\n' "$platform_obj" | json_object core) || fail "catalog has no TeamKit core for $PLATFORM"
  kb_obj=$(printf '%s\n' "$platform_obj" | json_object kb) || fail "catalog has no CI360 KB for $PLATFORM"
  installer_obj=$(printf '%s\n' "$platform_obj" | json_object installer) || fail "catalog has no macOS installer script"

  artifact "$installer_obj" "macOS installer"
  installer="$STAGE/install_macos.sh"
  fetch "$ART_PATH" "$installer" "$ART_SIZE"
  verify "$installer" "$ART_SIZE" "$ART_SHA" "macOS installer"

  printf 'Downloading TeamKit %s for %s...\n' "$VERSION" "$PLATFORM" >&2
  core_bundle=$(stage_bundle "$core_obj" core "TeamKit core")
  kb_bundle=$(stage_bundle "$kb_obj" kb "CI360 KB")

  # Under `curl ... | sh` stdin is the pipe carrying this script. Hand the
  # installer's gateway URL and APIM key prompts the real terminal instead.
  if [ ! -t 0 ] && ( : </dev/tty ) 2>/dev/null; then
    exec </dev/tty
  fi
  if [ -n "$INSTALL_ROOT" ]; then
    TEAMKIT_INSTALL_CLIENT="$CLIENT" sh "$installer" "$core_bundle" "$kb_bundle" "$INSTALL_ROOT"
  else
    TEAMKIT_INSTALL_CLIENT="$CLIENT" sh "$installer" "$core_bundle" "$kb_bundle"
  fi
  # Under `curl ... | sh` this shell reads its commands from the pipe, and
  # stdin was re-pointed at the terminal above. Returning from main would make
  # sh wait for more commands from the terminal -- an install that has
  # finished but never hands the prompt back. Leave explicitly instead.
  exit 0
}

main "$@"
