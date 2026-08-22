-- Minimal stand-in for the Supabase-managed pieces the migrations depend on,
-- so the schema can be exercised against a plain PostgreSQL instance.
create schema if not exists auth;
create schema if not exists extensions;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
end $$;

-- Supabase grants the API roles blanket table privileges on `public` and lets
-- RLS do the actual gating. Without that here, a probe running as
-- `authenticated` is stopped by a missing GRANT long before any policy is
-- consulted -- so the policies look correct while never having been exercised.
-- Default privileges cover the tables the schema is about to create.
grant usage on schema public to anon, authenticated;
alter default privileges in schema public grant all on tables    to anon, authenticated;
alter default privileges in schema public grant all on sequences to anon, authenticated;

create table if not exists auth.users (
  id                 uuid primary key default gen_random_uuid(),
  email              text,
  raw_user_meta_data jsonb default '{}'::jsonb
);

-- Impersonation hook: tests set `request.jwt.claim.sub` to act as a user.
create or replace function auth.uid() returns uuid
language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;
