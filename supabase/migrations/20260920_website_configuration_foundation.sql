alter table public.websites
  add column if not exists website_settings jsonb not null default '{}'::jsonb;

comment on column public.websites.website_settings is
  'Tenant-owned website presentation and content configuration. Values remain subject to websites RLS.';
