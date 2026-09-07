insert into public.customer_accounts (name, slug)
values ('Essex Paranormal', 'essex-paranormal')
on conflict (slug) do nothing;

insert into public.profiles (id, tenant_id, display_name, email, role)
select
  'b66639c7-83f0-4618-b594-46d8c864fcf9',
  id,
  'Ian Newitt',
  'ian.newitt@gmail.com',
  'MASTER_ADMIN'
from public.customer_accounts
where slug = 'newitt-media'
on conflict (id) do nothing;

insert into public.profiles (id, tenant_id, display_name, email, role)
select
  'bbe2f559-3717-421e-99a3-bb61a97ac892',
  id,
  'NEWITT Media',
  'nw13ttt@gmail.com',
  'OWNER'
from public.customer_accounts
where slug = 'newitt-media'
on conflict (id) do nothing;

insert into public.profiles (id, tenant_id, display_name, email, role)
select
  '6048b649-7dba-49d9-90cf-2747c1d57379',
  id,
  'Essex Paranormal',
  'essexparanormal@outlook.com',
  'OWNER'
from public.customer_accounts
where slug = 'essex-paranormal'
on conflict (id) do nothing;

select set_config(
  'request.jwt.claims',
  '{"sub":"b66639c7-83f0-4618-b594-46d8c864fcf9","role":"authenticated"}',
  true
);

insert into public.websites (tenant_id, name, domain, website_type)
select id, 'NEWITT Media', 'newittmedia.co.uk', 'OWNER'
from public.customer_accounts
where slug = 'newitt-media'
on conflict (domain) do nothing;

insert into public.websites (tenant_id, name, domain, website_type)
select id, 'Essex Paranormal', 'essexparanormal.com', 'CUSTOMER'
from public.customer_accounts
where slug = 'essex-paranormal'
on conflict (domain) do nothing;