# Supabase backend foundation

The migration in `migrations/20260903_initial_schema.sql` defines the tenant-aware schema and Row Level Security policies for the Control Room.

## Flutter configuration

The app only initializes Supabase when both values are supplied at build time:

```sh
flutter run -d macos \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

Use only the public publishable key in Flutter. Never provide a service-role key, database password, API credential, or other privileged secret to the app.

Password recovery uses Supabase Auth PKCE and the native macOS callback
`newittcontrolroom://auth-callback/`. Register that exact URL in Supabase Auth
redirect URLs before requesting a reset. The app supplies this callback by
default and registers the `newittcontrolroom` URL scheme in its macOS bundle.
`SUPABASE_PASSWORD_RESET_REDIRECT_URL` may override it only with a separately
approved HTTPS callback; no recovery URL is guessed or stored in source control.

Without these values the app remains in its clearly labelled development preview mode.

## Manual Supabase setup

1. Create a Supabase project and apply the migration with the Supabase CLI or SQL editor.
2. Enable email/password authentication in the Supabase dashboard.
3. Configure the allowed redirect URLs for the eventual password-reset flow.
4. Provision each tenant and profile through a trusted server-side function or the Supabase dashboard. The migration intentionally does not auto-assign a tenant or elevated role from client input.
5. Assign `MASTER_ADMIN`, `OWNER`, or `CUSTOMER` only from a trusted backend path. Client profile updates cannot change role or tenant scope.
6. Run database/RLS tests in the Supabase project before enabling real accounts.

The Flutter adapter is ready for real email/password sessions, session restoration, password changes, reset requests, and auth-state events. The UI still defaults to the unconfigured service until the build-time values and database provisioning are present.

## Customer invitation provisioning

`functions/provision-customer/index.ts` is the only Control Room onboarding path. It is an Edge Function and must be deployed using the authenticated Supabase CLI; it is not deployed by Flutter.

The function uses the Supabase-managed `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` runtime secrets. Do not add those values to Flutter, source control, Dart defines, or local `.env` files. It verifies the caller's JWT, resolves the caller's `profiles.role` server-side, and permits provisioning only for `MASTER_ADMIN`.

It validates organisation, account slug, contact name, and email; creates the customer account, sends Supabase Auth's invitation email, creates the tenant-scoped `CUSTOMER` profile, and writes an audit log. It accepts no tenant ID or role from the Flutter client. A failed provision attempts to remove the newly created account and Auth user before returning a generic error.

## Privacy boundary

Master Admin can read operational website metadata and manage platform records, but private `website_content`, `media`, and social records require an active, temporary `support_access_grants` row. Grant creation is audited by the `audit_logs` foundation and should be performed by a trusted backend workflow.
