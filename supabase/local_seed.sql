-- Synthetic fixtures for the isolated local CLI stack only.
begin;
set local search_path = public, extensions;

insert into public.customer_accounts (id, name, slug)
values
  ('a1000000-0000-4000-8000-000000000001', 'Local Tenant A', 'local-tenant-a'),
  ('a1000000-0000-4000-8000-000000000002', 'Local Tenant B', 'local-tenant-b')
on conflict (id) do nothing;

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change, email_change_token_new
)
select '00000000-0000-0000-0000-000000000000', fixture.id, 'authenticated',
  'authenticated', fixture.email, crypt('newitt-local-fixture-only', gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(),
  '', '', '', ''
from (values
  ('a2000000-0000-4000-8000-000000000001'::uuid, 'tenant-a@example.test'),
  ('a2000000-0000-4000-8000-000000000002'::uuid, 'tenant-b@example.test'),
  ('a2000000-0000-4000-8000-000000000003'::uuid, 'admin@example.test')
) as fixture(id, email)
on conflict (id) do nothing;

insert into public.profiles (id, tenant_id, display_name, email, role)
values
  ('a2000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001',
    'Local Customer A', 'tenant-a@example.test', 'OWNER'),
  ('a2000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000002',
    'Local Customer B', 'tenant-b@example.test', 'OWNER'),
  ('a2000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-000000000001',
    'Local Administrator', 'admin@example.test', 'MASTER_ADMIN')
on conflict (id) do nothing;

select set_config(
  'request.jwt.claims',
  '{"sub":"a2000000-0000-4000-8000-000000000003","role":"authenticated"}',
  true
);

-- These domains are local fixture values for the publishing RPC allowlist.
insert into public.websites (id, tenant_id, name, domain, website_type, site_lifecycle)
values
  ('a3000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001',
    'Local Website A', 'newittmedia.co.uk', 'CUSTOMER', 'PUBLISHED'),
  ('a3000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000002',
    'Local Website B', 'essexparanormal.com', 'CUSTOMER', 'PUBLISHED')
on conflict (id) do nothing;

commit;
