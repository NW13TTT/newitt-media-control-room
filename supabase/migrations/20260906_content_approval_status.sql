-- Additive enum preparation. Do not modify or rerun prior migrations.
-- PostgreSQL requires this enum value to commit before a later migration uses it.

alter type public.content_status add value if not exists 'PENDING_APPROVAL';