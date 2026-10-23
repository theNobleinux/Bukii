-- =============================================================================
-- Phase 1: Profiles, roles and auth sync
-- =============================================================================

create extension if not exists btree_gist with schema extensions;
create extension if not exists pgcrypto  with schema extensions;
create extension if not exists pg_trgm   with schema extensions;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type public.user_role as enum ('customer', 'business_owner');

-- ---------------------------------------------------------------------------
-- Shared trigger: keep updated_at fresh
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- profiles: one row per auth user
-- ---------------------------------------------------------------------------
create table public.profiles (
  id                 uuid primary key references auth.users (id) on delete cascade,
  role               public.user_role not null default 'customer',
  full_name          text check (full_name is null or char_length(full_name) between 1 and 120),
  avatar_url         text,
  phone              text,
  email              text,
  reminders_enabled  boolean not null default true,
  whatsapp_updates   boolean not null default false,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

comment on table  public.profiles is 'Public profile for every auth user. Created automatically by on_auth_user_created.';
comment on column public.profiles.role is 'customer or business_owner. Set at signup from user metadata; upgrade via become_business_owner().';

create index profiles_phone_idx on public.profiles (phone);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Create profile when an auth user is created.
-- Role comes from signup metadata: { "role": "business_owner" | "customer" }
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role public.user_role := 'customer';
  v_meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  if lower(coalesce(v_meta ->> 'role', '')) in ('business_owner', 'business owner', 'business') then
    v_role := 'business_owner';
  end if;

  insert into public.profiles (id, role, full_name, avatar_url, phone, email)
  values (
    new.id,
    v_role,
    nullif(trim(coalesce(v_meta ->> 'full_name', v_meta ->> 'name', '')), ''),
    nullif(v_meta ->> 'avatar_url', ''),
    case when new.phone is null or new.phone = '' then null
         when left(new.phone, 1) = '+' then new.phone
         else '+' || new.phone end,
    nullif(new.email, '')
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Keep phone / email in sync when they change on the auth side
create or replace function public.handle_user_contact_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles
     set phone = case when new.phone is null or new.phone = '' then null
                      when left(new.phone, 1) = '+' then new.phone
                      else '+' || new.phone end,
         email = nullif(new.email, '')
   where id = new.id;
  return new;
end;
$$;

create trigger on_auth_user_contact_changed
  after update of phone, email on auth.users
  for each row
  when (old.phone is distinct from new.phone or old.email is distinct from new.email)
  execute function public.handle_user_contact_change();

-- ---------------------------------------------------------------------------
-- Users cannot change their own role / id / phone directly.
-- Role upgrades go through become_business_owner().
-- ---------------------------------------------------------------------------
create or replace function public.protect_profile_columns()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- Only enforce for API callers (authenticated / anon). Server-side code is trusted.
  if coalesce(auth.jwt() ->> 'role', '') in ('authenticated', 'anon')
     and coalesce(current_setting('bukii.allow_role_change', true), '') <> 'on' then
    if new.role is distinct from old.role then
      raise exception 'Role cannot be changed directly. Use become_business_owner().' using errcode = '42501';
    end if;
    if new.phone is distinct from old.phone or new.email is distinct from old.email then
      raise exception 'Phone and email are managed by authentication.' using errcode = '42501';
    end if;
  end if;
  new.id := old.id;
  return new;
end;
$$;

create trigger profiles_protect_columns
  before update on public.profiles
  for each row execute function public.protect_profile_columns();

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function public.current_user_role()
returns public.user_role
language sql
stable
security definer
set search_path = ''
as $$
  select role from public.profiles where id = auth.uid();
$$;

-- A customer can upgrade to business owner (e.g. picked "Customer" first, later wants to list a business).
create or replace function public.become_business_owner()
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '42501';
  end if;

  perform set_config('bukii.allow_role_change', 'on', true);
  update public.profiles
     set role = 'business_owner'
   where id = auth.uid()
  returning * into v_profile;
  perform set_config('bukii.allow_role_change', 'off', true);

  return v_profile;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS (base policies; cross-table policies added in later migrations)
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;

create policy "profiles: read own"
  on public.profiles for select
  to authenticated
  using (id = (select auth.uid()));

create policy "profiles: update own"
  on public.profiles for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- No insert / delete policies: rows are created by trigger and removed with the auth user.

revoke all on function public.handle_new_user()            from public, anon, authenticated;
revoke all on function public.handle_user_contact_change() from public, anon, authenticated;
revoke all on function public.become_business_owner()      from public, anon;
grant execute on function public.become_business_owner()   to authenticated;
revoke all on function public.current_user_role()          from public, anon;
grant execute on function public.current_user_role()       to authenticated;
