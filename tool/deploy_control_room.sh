#!/usr/bin/env bash
# Builds and deploys the Control Room web app to Cloudflare.
#
# The two dart-defines below are part of the production build contract:
#   SUPABASE_AUTH_STORAGE_SCOPE          omitting it changes the session
#                                        storage key and signs every user out
#   SUPABASE_PASSWORD_RESET_REDIRECT_URL omitting it breaks password recovery
# They are not secrets. Supabase URL and publishable key come from
# config/local.json, which is gitignored and never committed.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG_FILE="config/local.json"
AUTH_STORAGE_SCOPE="newitt-control-room"
PASSWORD_RESET_REDIRECT_URL="https://newitt-media-control-room.ian-newitt.workers.dev/auth-callback"
WRANGLER_CONFIG="wrangler.control-room.jsonc"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Missing $CONFIG_FILE. It supplies SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY and is not in source control." >&2
  exit 1
fi

for key in SUPABASE_URL SUPABASE_PUBLISHABLE_KEY; do
  if ! grep -q "\"$key\"" "$CONFIG_FILE"; then
    echo "$CONFIG_FILE is missing $key." >&2
    exit 1
  fi
done

echo "==> flutter analyze"
flutter analyze

echo "==> flutter test"
flutter test

echo "==> flutter build web --release"
flutter build web --release \
  --dart-define-from-file="$CONFIG_FILE" \
  --dart-define=SUPABASE_AUTH_STORAGE_SCOPE="$AUTH_STORAGE_SCOPE" \
  --dart-define=SUPABASE_PASSWORD_RESET_REDIRECT_URL="$PASSWORD_RESET_REDIRECT_URL"

echo "==> verifying production configuration is present in the bundle"
for expected in "$AUTH_STORAGE_SCOPE" "$PASSWORD_RESET_REDIRECT_URL"; do
  if ! grep -qF -- "$expected" build/web/main.dart.js; then
    echo "Build is missing $expected. Refusing to deploy." >&2
    exit 1
  fi
done
echo "    auth storage scope and password reset callback present"

if [[ "${1:-}" == "--build-only" ]]; then
  echo "==> build only, not deploying"
  exit 0
fi

echo "==> wrangler deploy --config $WRANGLER_CONFIG"
wrangler deploy --config "$WRANGLER_CONFIG"
