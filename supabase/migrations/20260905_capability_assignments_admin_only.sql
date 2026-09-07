-- Additive security correction. Do not modify or rerun prior migrations.
--
-- Capability assignments are an administrative entitlement boundary. Customer
-- users retain tenant-scoped read access through website_capabilities_select_scope,
-- but must not create, update, or delete assignments for any website.

drop policy if exists website_capabilities_customer_manage_own
  on public.website_capabilities;

-- The existing website_capabilities_master_manage policy remains unchanged:
-- it grants ALL operations only where public.is_master_admin() is true.
-- The existing website_capabilities_select_scope policy remains unchanged:
-- it grants tenant-scoped SELECT access to customers and operational SELECT
-- access to Master Admin. No customer write policy is created here.