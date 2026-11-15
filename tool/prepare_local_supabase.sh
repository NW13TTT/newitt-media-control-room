#!/usr/bin/env bash
set -euo pipefail

source_root="$(cd "$(dirname "$0")/.." && pwd)"
local_root="$(mktemp -d "${TMPDIR:-/tmp}/newitt-supabase.XXXXXXXX")"
mkdir -p "$local_root/supabase"
cp -R "$source_root/supabase/migrations" "$local_root/supabase/"
cp -R "$source_root/supabase/functions" "$local_root/supabase/"
cp "$source_root/supabase/local_seed.sql" "$local_root/supabase/seed.sql"

# Preserve the migration version in the disposable local copy. Its production
# account bootstrap is replaced by the synthetic fixture after migrations.
printf '%s\n' 'select 1; -- Local-only placeholder for the production account bootstrap.' \
  > "$local_root/supabase/migrations/20260925_initial_control_room_accounts.sql"

cat > "$local_root/supabase/config.toml" <<'TOML'
project_id = "newitt-control-room-fixtures"

[api]
port = 56321

[db]
port = 56322
shadow_port = 56320
major_version = 17

[db.seed]
enabled = true
sql_paths = ["./seed.sql"]

[studio]
port = 56323

[local_smtp]
port = 56324

[storage]
file_size_limit = "50MiB"

[auth]
site_url = "http://127.0.0.1:3000"

[analytics]
enabled = false

[edge_runtime]
inspector_port = 56883
TOML

printf '%s\n' "$local_root"
