-- Derive support message tenancy from the referenced request on every write.
-- This preserves customer tenant/RLS checks while allowing authorised Master Admin actions.

create or replace function public.validate_support_message_scope()
returns trigger language plpgsql set search_path = '' as $$
declare
  request_tenant_id uuid;
  author_tenant_id uuid;
  author_role public.app_role;
begin
  if auth.uid() is null then
    raise exception 'An authenticated profile is required';
  end if;

  new.author_id := auth.uid();

  select tenant_id
    into request_tenant_id
    from public.support_requests
   where id = new.support_request_id;

  select tenant_id, role
    into author_tenant_id, author_role
    from public.profiles
   where id = auth.uid();

  if request_tenant_id is null or author_tenant_id is null then
    raise exception 'Support request or author profile is not available';
  end if;

  new.tenant_id := request_tenant_id;

  if author_role <> 'MASTER_ADMIN' and request_tenant_id <> author_tenant_id then
    raise exception 'Support request is not available to this account';
  end if;

  if author_role <> 'MASTER_ADMIN' and new.is_internal then
    raise exception 'Internal support notes require Master Admin';
  end if;

  return new;
end;
$$;

revoke execute on function public.validate_support_message_scope() from public, authenticated;
