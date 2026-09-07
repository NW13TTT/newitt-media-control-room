create table if not exists public.contact_submission_rate_limits (
  tenant_id uuid not null references public.customer_accounts(id) on delete cascade,
  website_id uuid not null references public.websites(id) on delete cascade,
  client_key_hash text not null,
  window_started_at timestamptz not null default timezone('utc', now()),
  request_count integer not null default 0 check (request_count >= 0),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (website_id, client_key_hash)
);

create index if not exists contact_submission_rate_limits_scope_idx
  on public.contact_submission_rate_limits (tenant_id, website_id, updated_at desc);

create or replace function public.validate_contact_submission_rate_limit_tenant()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  website_tenant_id uuid;
begin
  select tenant_id into website_tenant_id from public.websites where id = new.website_id;
  if website_tenant_id is null or website_tenant_id <> new.tenant_id then
    raise exception 'Contact rate limit must match its website tenant';
  end if;
  return new;
end;
$$;

drop trigger if exists contact_submission_rate_limits_validate_tenant on public.contact_submission_rate_limits;
create trigger contact_submission_rate_limits_validate_tenant
before insert or update on public.contact_submission_rate_limits
for each row execute function public.validate_contact_submission_rate_limit_tenant();

drop trigger if exists contact_submission_rate_limits_set_updated_at on public.contact_submission_rate_limits;
create trigger contact_submission_rate_limits_set_updated_at
before update on public.contact_submission_rate_limits
for each row execute function public.set_updated_at();

alter table public.contact_submission_rate_limits enable row level security;

create or replace function public.consume_contact_submission_rate_limit(
  p_tenant_id uuid,
  p_website_id uuid,
  p_client_key_hash text,
  p_limit integer,
  p_window_seconds integer
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  accepted boolean;
begin
  if p_limit < 1 or p_limit > 20 or p_window_seconds < 60 or p_window_seconds > 86400 then
    raise exception 'Rate limit configuration is invalid';
  end if;
  if not exists (
    select 1 from public.websites
     where id = p_website_id and tenant_id = p_tenant_id
  ) then
    raise exception 'Website scope is invalid';
  end if;

  insert into public.contact_submission_rate_limits (
    tenant_id, website_id, client_key_hash, request_count
  ) values (
    p_tenant_id, p_website_id, p_client_key_hash, 1
  )
  on conflict (website_id, client_key_hash) do update
     set window_started_at = case
           when public.contact_submission_rate_limits.window_started_at
             <= timezone('utc', now()) - make_interval(secs => p_window_seconds)
           then timezone('utc', now())
           else public.contact_submission_rate_limits.window_started_at
         end,
         request_count = case
           when public.contact_submission_rate_limits.window_started_at
             <= timezone('utc', now()) - make_interval(secs => p_window_seconds)
           then 1
           else public.contact_submission_rate_limits.request_count + 1
         end
   where public.contact_submission_rate_limits.window_started_at
       <= timezone('utc', now()) - make_interval(secs => p_window_seconds)
      or public.contact_submission_rate_limits.request_count < p_limit
  returning true into accepted;

  return coalesce(accepted, false);
end;
$$;

revoke all on table public.contact_submission_rate_limits from public, anon, authenticated;
revoke all on function public.consume_contact_submission_rate_limit(uuid, uuid, text, integer, integer) from public, anon, authenticated;
grant execute on function public.consume_contact_submission_rate_limit(uuid, uuid, text, integer, integer) to service_role;