-- Enforce temporary website lifecycle and expiry at both existing publication decisions.
create or replace function public.publish_website_content(requested_website_id uuid, requested_content_key text)
returns void language plpgsql security definer set search_path = '' as $$
declare authenticated_tenant_id uuid := public.current_tenant_id(); content_record public.website_content%rowtype;
begin
 if auth.uid() is null or authenticated_tenant_id is null then raise exception 'An authenticated tenant profile is required'; end if;
 if not public.website_can_publish(requested_website_id) then raise exception 'Website lifecycle or expiry does not permit publishing'; end if;
 select * into content_record from public.website_content where website_id=requested_website_id and content_key=requested_content_key and tenant_id=authenticated_tenant_id;
 if content_record.id is null then raise exception 'Website content is not available to the authenticated tenant'; end if;
 if public.content_safety_blocks_publication(content_record.id) then raise exception 'Content safety review must be resolved before publishing'; end if;
 insert into public.published_website_content (website_content_id,tenant_id,website_id,content_key,content,published_at) values (content_record.id,content_record.tenant_id,content_record.website_id,content_record.content_key,content_record.content,pg_catalog.timezone('utc',pg_catalog.now())) on conflict (website_content_id) do update set content=excluded.content,published_at=excluded.published_at,tenant_id=excluded.tenant_id,website_id=excluded.website_id,content_key=excluded.content_key;
 update public.website_content set content_status='PUBLISHED' where id=content_record.id;
end; $$;
create or replace function public.approve_website_content(requested_website_id uuid, requested_content_key text)
returns void language plpgsql security definer set search_path = '' as $$
declare caller_id uuid:=auth.uid(); caller_tenant_id uuid:=public.current_tenant_id(); content_record public.website_content%rowtype;
begin
 if caller_id is null or caller_tenant_id is null or not exists(select 1 from public.content_approval_grants where profile_id=caller_id and tenant_id=caller_tenant_id and website_id=requested_website_id and revoked_at is null) then raise exception 'Approval is not available to this account'; end if;
 if not public.website_can_publish(requested_website_id) then raise exception 'Website lifecycle or expiry does not permit publishing'; end if;
 select * into content_record from public.website_content where website_id=requested_website_id and content_key=requested_content_key and tenant_id=caller_tenant_id and content_status='PENDING_APPROVAL';
 if content_record.id is null then raise exception 'Pending content is not available for approval'; end if;
 if content_record.approval_requested_by=caller_id then raise exception 'A requester cannot approve their own content'; end if;
 if not exists(select 1 from public.website_capabilities where website_id=requested_website_id and capability='contentApproval') then raise exception 'Content approval is not enabled for this website'; end if;
 if public.content_safety_blocks_publication(content_record.id) then raise exception 'Content safety review must be resolved before publishing'; end if;
 insert into public.published_website_content (website_content_id,tenant_id,website_id,content_key,content,published_at) values (content_record.id,content_record.tenant_id,content_record.website_id,content_record.content_key,content_record.content,pg_catalog.timezone('utc',pg_catalog.now())) on conflict (website_content_id) do update set content=excluded.content,published_at=excluded.published_at;
 update public.website_content set content_status='PUBLISHED',approved_at=pg_catalog.timezone('utc',pg_catalog.now()),approved_by=caller_id where id=content_record.id;
 insert into public.audit_logs(actor_id,tenant_id,website_id,action,resource_type,resource_id,metadata) values(caller_id,caller_tenant_id,requested_website_id,'CONTENT_APPROVED_AND_PUBLISHED','website_content',content_record.id,jsonb_build_object('content_key',requested_content_key));
end; $$;
revoke execute on function public.publish_website_content(uuid,text) from public,anon,authenticated; grant execute on function public.publish_website_content(uuid,text) to authenticated;
revoke execute on function public.approve_website_content(uuid,text) from public; grant execute on function public.approve_website_content(uuid,text) to authenticated;
