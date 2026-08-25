-- ==========================================================================
-- 0008_profile_update_least_privilege.sql
--
-- Customers may edit storefront profile fields, but must never be able to
-- modify the role that the authorization helpers consume.
-- Role changes remain an owner/service-role/admin operation.
-- ============================================================================

revoke update on table public.profiles from anon, authenticated;
grant update (email, full_name, phone) on table public.profiles
  to authenticated;

drop policy if exists profiles_self_update on public.profiles;
create policy profiles_self_update on public.profiles
  for update
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));
