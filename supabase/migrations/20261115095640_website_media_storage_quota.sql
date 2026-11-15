create schema if not exists newitt_media_private;

create table newitt_media_private.storage_budget (
  singleton boolean primary key default true check (singleton),
  total_bytes bigint not null check (total_bytes > 0),
  default_customer_bytes bigint not null check (default_customer_bytes > 0),
  max_file_bytes bigint not null check (max_file_bytes > 0)
);
insert into newitt_media_private.storage_budget
  (total_bytes, default_customer_bytes, max_file_bytes)
values (800000000, 400000000, 52428800);

create table newitt_media_private.customer_quota (
  tenant_id uuid primary key references public.customer_accounts(id) on delete cascade,
  quota_bytes bigint not null check (quota_bytes > 0)
);

create function newitt_media_private.enforce_storage_budget()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  budget newitt_media_private.storage_budget;
  tenant_key text := split_part(new.name, '/', 1);
  customer_limit bigint;
  bytes_all numeric;
  bytes_customer numeric;
begin
  if tg_op = 'UPDATE' and old.name = new.name and old.bucket_id = new.bucket_id
      and old.metadata ->> 'size' is not distinct from new.metadata ->> 'size' then
    return new;
  end if;
  -- Serialize competing uploads. The row write also forces a serialization
  -- failure rather than stale accounting at higher isolation levels.
  update newitt_media_private.storage_budget
    set total_bytes = total_bytes
    where singleton returning * into strict budget;
  if coalesce(new.metadata ->> 'size', '') !~ '^[0-9]+$'
      or (new.metadata ->> 'size')::numeric > budget.max_file_bytes then
    raise exception 'This file exceeds the 50 MiB upload limit or has no valid size'
      using errcode = '23514';
  end if;
  select coalesce((select quota_bytes from newitt_media_private.customer_quota
    where tenant_id::text = tenant_key), budget.default_customer_bytes)
    into customer_limit;
  select coalesce(sum(size_bytes), 0),
    coalesce(sum(size_bytes) filter (where split_part(name, '/', 1) = tenant_key), 0)
  into bytes_all, bytes_customer
  from (
    select name, case when metadata ->> 'size' ~ '^[0-9]+$'
      then (metadata ->> 'size')::numeric else 0 end as size_bytes
    from storage.objects where bucket_id = 'website-media'
  ) as objects;
  if bytes_all > budget.total_bytes then
    raise exception 'Control Room storage is full. Remove unused media before uploading'
      using errcode = '23514';
  end if;
  if bytes_customer > customer_limit then
    raise exception 'Your storage limit has been reached. Remove unused media before uploading'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

revoke execute on function newitt_media_private.enforce_storage_budget() from public;

create trigger website_media_storage_budget
after insert or update of bucket_id, name, metadata on storage.objects
for each row when (new.bucket_id = 'website-media')
execute function newitt_media_private.enforce_storage_budget();

create function public.website_media_storage_usage()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'used_bytes', (
      select coalesce(sum(case when metadata ->> 'size' ~ '^[0-9]+$'
        then (metadata ->> 'size')::numeric else 0 end), 0)
      from storage.objects
      where bucket_id = 'website-media'
        and split_part(name, '/', 1) = caller.tenant_id::text
    ),
    'quota_bytes', coalesce(quota.quota_bytes, budget.default_customer_bytes)
  )
  from newitt_media_private.storage_budget as budget
  cross join (select public.current_tenant_id() as tenant_id) as caller
  left join newitt_media_private.customer_quota as quota on quota.tenant_id = caller.tenant_id
  where budget.singleton and caller.tenant_id is not null;
$$;

revoke execute on function public.website_media_storage_usage() from public;
grant execute on function public.website_media_storage_usage() to authenticated;
