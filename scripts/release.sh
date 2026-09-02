#!/usr/bin/env bash
#
# Build a shipping app bundle that cannot carry a developer's machine address.
#
# Two things go wrong when a release is built by hand, and both have happened:
#
#   1. `.env` is gitignored and bundled as an asset, so whatever a developer
#      happened to have on disk at build time is what ships. Release 1.0.1 went
#      to the closed track pointing at a laptop on someone's home network and
#      every install failed at the first request.
#   2. The check for (1) was a thing to remember. Remembering is not a control.
#
# So this script owns the whole ritual: it swaps the developer's `.env` for an
# inert one for the duration of the build, restores it on any exit path, and
# then reads the artifact back and refuses to hand over a bundle that contains
# a private address or that is missing the production host.
#
# Nothing here touches signing or Gradle config. Upload stays a separate step
# (scripts/play-upload.ts) so a verified artifact is a deliberate hand-off.
#
# Usage: scripts/release.sh

set -euo pipefail
cd "$(dirname "$0")/.."

# Play Billing 8 + target API 36 need the pinned SDK, not whatever `flutter` is
# on PATH.
FLUTTER="${FLUTTER_SDK:-$HOME/Development/flutter-sdks/flutter-3.44.9}/bin/flutter"
[ -x "$FLUTTER" ] || { echo "✗ pinned Flutter SDK not found at $FLUTTER" >&2; exit 1; }

API_BASE_URL="${API_BASE_URL:-https://api.everloreapp.com}"
WS_BASE_URL="${WS_BASE_URL:-wss://api.everloreapp.com}"
AAB="build/app/outputs/bundle/release/app-release.aab"

# --- 1. neutralise the bundled asset -----------------------------------------
# Release code reads none of this (AppConfig returns compiled values before it
# consults dotenv), but the file ships as readable data either way, so it
# should not have a home address written in it.
BACKUP=""
if [ -f .env ]; then
  BACKUP="$(mktemp)"
  cp .env "$BACKUP"
  restore() { [ -n "$BACKUP" ] && cp "$BACKUP" .env && rm -f "$BACKUP" && echo "• restored your .env"; }
  trap restore EXIT INT TERM
  cat > .env <<'ENV'
# Intentionally inert. A release build resolves every endpoint and identifier
# from compiled-in constants (see lib/core/config/env.dart); this file exists
# only because Flutter cannot exclude an asset per build mode. Your working
# .env is restored automatically when scripts/release.sh exits.
GUIDE_REHEARSAL=false
ENV
  echo "• .env swapped for the inert build copy"
fi

# --- 2. build ----------------------------------------------------------------
echo "• building app bundle → $API_BASE_URL"
"$FLUTTER" build appbundle --release \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=WS_BASE_URL="$WS_BASE_URL"

[ -f "$AAB" ] || { echo "✗ no bundle produced at $AAB" >&2; exit 1; }

# --- 3. read the artifact back -----------------------------------------------
# Verifying the thing that ships, not the thing we meant to ship.
echo "• verifying $AAB"
WORK="$(mktemp -d)"
trap '[ -n "$BACKUP" ] && cp "$BACKUP" .env && rm -f "$BACKUP" && echo "• restored your .env"; rm -rf "$WORK"' EXIT INT TERM
unzip -q -o "$AAB" -d "$WORK"

PRIVATE_RE='192\.168\.|10\.0\.2\.2|172\.(1[6-9]|2[0-9]|3[01])\.|(^|[^0-9])10\.[0-9]+\.[0-9]+\.[0-9]+'
if HITS="$(grep -rlE "$PRIVATE_RE" "$WORK" 2>/dev/null)"; then
  echo "✗ private address found inside the bundle:" >&2
  echo "$HITS" | sed "s|$WORK|<aab>|" >&2
  echo "  Do not upload this artifact." >&2
  exit 1
fi

HOST="${API_BASE_URL#https://}"
# NOTE: `strings … | grep -q` is wrong under `set -o pipefail`. grep -q exits the
# moment it matches, strings then dies of SIGPIPE (141), and pipefail reports the
# PIPELINE as failed — so a bundle that DOES contain the host is rejected for
# containing it. This gate passed when it was written only because the binaries
# were small enough that strings finished before grep could exit; they have since
# grown, and it began refusing every artifact. Materialise the strings first so
# there is no pipe to break.
SYMS="$WORK/.strings"
for so in $(find "$WORK" -name libapp.so); do
  ABI="$(basename "$(dirname "$so")")"
  strings -a "$so" > "$SYMS"
  grep -qF "$HOST" "$SYMS" \
    || { echo "✗ $ABI/libapp.so does not contain $HOST" >&2; exit 1; }
done
rm -f "$SYMS"

echo
echo "✓ $(grep -m1 '^version:' pubspec.yaml)"
echo "✓ no private addresses in the bundle"
echo "✓ $API_BASE_URL compiled into every ABI"
echo
echo "  $AAB"
echo "  Upload with: bun scripts/play-upload.ts"
