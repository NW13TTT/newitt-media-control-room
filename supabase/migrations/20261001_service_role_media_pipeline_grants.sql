-- Additive migration only. Do not modify or rerun earlier migrations.
--
-- The deployed public-website-content and delete-media Edge Functions run with
-- the service role and read media, profiles and websites, delete media and
-- write audit logs. The service role holds no data privileges on those tables,
-- so signedPublishedMedia returns nothing and the public website receives no
-- signed URLs for published media, and media deletion reports a reconciliation
-- failure.
--
-- These grants restore only what those two reviewed functions require. The
-- service role key is held in Edge Function secrets and is never shipped to a
-- client. No customer-facing policy, storage policy, bucket setting or RLS rule
-- is changed by this migration.

grant select, delete on table public.media to service_role;
grant select on table public.profiles to service_role;
grant select on table public.websites to service_role;
grant insert on table public.audit_logs to service_role;
