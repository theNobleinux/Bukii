-- =============================================================================
-- Phase 3: Business registry, staff, services catalog, hours, closures, storage
-- =============================================================================

-- ---------------------------------------------------------------------------
-- categories (Barber, Salon, Nailtech, Spa, ...)
-- ---------------------------------------------------------------------------
create table public.categories (
  id          smallint generated always as identity primary key,
  slug        text not null unique check (slug ~ '^[a-z0-9-]{2,40}$'),
  name        text not null,
  icon        text,
  sort_order  smallint not null default 0,
  is_active   boolean not null default true
);

insert into public.categories (slug, name, icon, sort_order) values
  ('barber',   'Barber',   'content_cut',  1),
  ('salon',    'Salon',    'face_retouching_natural', 2),
  ('nailtech', 'Nailtech', 'back_hand',    3),
  ('spa',      'Spa',      'spa',          4),
  ('makeup',   'Makeup',   'brush',        5),
  ('other',    'Other',    'storefront',   99);

-- ---------------------------------------------------------------------------
-- businesses
-- ---------------------------------------------------------------------------
create or replace function public.is_valid_timezone(p_tz text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (select 1 from pg_catalog.pg_timezone_names where name = p_tz);
$$;

create table public.businesses (
  id                          uuid primary key default gen_random_uuid(),
  owner_id                    uuid not null references public.profiles (id) on delete cascade,
  name                        text not null check (char_length(name) between 2 and 80),
  category_id                 smallint not null references public.categories (id),
  description                 text check (description is null or char_length(description) <= 2000),
  logo_url                    text,
  cover_url                   text,
  phone                       text,
  email                       text,
  whatsapp                    text,
  address                     text,
  area                        text,                 -- e.g. Ikoyi, Lekki
  city                        text not null default 'Lagos',
  state                       text not null default 'Lagos',
  country                     text not null default 'NG',
  latitude                    double precision check (latitude  between -90  and 90),
  longitude                   double precision check (longitude between -180 and 180),
  timezone                    text not null default 'Africa/Lagos',
  currency                    text not null default 'NGN',
  -- booking rules
  auto_confirm_bookings       boolean not null default true,
  slot_interval_minutes       smallint not null default 15  check (slot_interval_minutes in (5, 10, 15, 20, 30, 45, 60)),
  min_notice_minutes          integer  not null default 60  check (min_notice_minutes between 0 and 10080),
  max_advance_days            smallint not null default 60  check (max_advance_days between 1 and 365),
  cancellation_window_minutes integer  not null default 120 check (cancellation_window_minutes between 0 and 10080),
  -- listing
  is_published                boolean not null default false,
  rating_avg                  numeric(2,1) not null default 0,
  rating_count                integer not null default 0,
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now(),
  constraint businesses_timezone_valid check (public.is_valid_timezone(timezone))
);

comment on column public.businesses.is_published is 'When true the business appears in Explore and its booking page is public.';
comment on column public.businesses.rating_avg   is 'Maintained by trigger from reviews. Read-only for clients.';

create index businesses_owner_idx     on public.businesses (owner_id);
create index businesses_category_idx  on public.businesses (category_id) where is_published;
create index businesses_area_idx      on public.businesses (lower(area)) where is_published;
create index businesses_name_trgm_idx on public.businesses using gin (name extensions.gin_trgm_ops);

create trigger businesses_set_updated_at
  before update on public.businesses
  for each row execute function public.set_updated_at();

-- Only business owners can own businesses; protect system columns
create or replace function public.businesses_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.jwt() ->> 'role', '') in ('authenticated', 'anon') then
    if tg_op = 'INSERT' then
      if not exists (select 1 from public.profiles p where p.id = new.owner_id and p.role = 'business_owner') then
        raise exception 'Only business owner accounts can create a business. Call become_business_owner() first.'
          using errcode = '42501';
      end if;
      new.rating_avg   := 0;
      new.rating_count := 0;
    else
      new.owner_id     := old.owner_id;
      new.rating_avg   := old.rating_avg;
      new.rating_count := old.rating_count;
    end if;
  end if;
  return new;
end;
$$;

create trigger businesses_guard
  before insert or update on public.businesses
  for each row execute function public.businesses_guard();

-- Helper used by RLS on child tables (security definer avoids RLS recursion)
create or replace function public.is_business_owner(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.businesses b
     where b.id = p_business_id and b.owner_id = auth.uid()
  );
$$;

create or replace function public.is_business_public(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.businesses b
     where b.id = p_business_id and b.is_published
  );
$$;

-- ---------------------------------------------------------------------------
-- staff_members (the people who serve customers; not app users)
-- ---------------------------------------------------------------------------
create table public.staff_members (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid not null references public.businesses (id) on delete cascade,
  full_name    text not null check (char_length(full_name) between 1 and 80),
  title        text,
  avatar_url   text,
  is_active    boolean not null default true,
  sort_order   smallint not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index staff_members_business_idx on public.staff_members (business_id);

create trigger staff_members_set_updated_at
  before update on public.staff_members
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- services
-- ---------------------------------------------------------------------------
create table public.services (
  id                uuid primary key default gen_random_uuid(),
  business_id       uuid not null references public.businesses (id) on delete cascade,
  name              text not null check (char_length(name) between 1 and 80),
  description       text check (description is null or char_length(description) <= 1000),
  duration_minutes  integer not null check (duration_minutes between 5 and 720),
  buffer_minutes    integer not null default 0 check (buffer_minutes between 0 and 240),
  price             numeric(12,2) not null check (price >= 0),
  max_capacity      integer not null default 1 check (max_capacity between 1 and 500),
  image_url         text,
  is_active         boolean not null default true,
  sort_order        smallint not null default 0,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

comment on column public.services.max_capacity   is '1 = one customer at a time. >1 = group session (that many customers can book the same start time).';
comment on column public.services.buffer_minutes is 'Clean-up time blocked after the service ends.';

create index services_business_idx on public.services (business_id) where is_active;

create trigger services_set_updated_at
  before update on public.services
  for each row execute function public.set_updated_at();

-- Which staff can perform which service. A staff member with NO rows here can perform every service.
create table public.staff_services (
  staff_id    uuid not null references public.staff_members (id) on delete cascade,
  service_id  uuid not null references public.services (id) on delete cascade,
  primary key (staff_id, service_id)
);

create index staff_services_service_idx on public.staff_services (service_id);

create or replace function public.staff_services_same_business()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (select business_id from public.staff_members where id = new.staff_id)
     is distinct from (select business_id from public.services where id = new.service_id) then
    raise exception 'Staff member and service must belong to the same business';
  end if;
  return new;
end;
$$;

create trigger staff_services_same_business
  before insert or update on public.staff_services
  for each row execute function public.staff_services_same_business();

-- ---------------------------------------------------------------------------
-- business_hours: one row per weekday (0 = Sunday ... 6 = Saturday)
-- ---------------------------------------------------------------------------
create table public.business_hours (
  business_id  uuid not null references public.businesses (id) on delete cascade,
  day_of_week  smallint not null check (day_of_week between 0 and 6),
  is_closed    boolean not null default false,
  open_time    time,
  close_time   time,
  break_start  time,
  break_end    time,
  primary key (business_id, day_of_week),
  constraint business_hours_open_valid check (
    is_closed or (open_time is not null and close_time is not null and open_time < close_time)
  ),
  constraint business_hours_break_valid check (
    (break_start is null and break_end is null)
    or (break_start is not null and break_end is not null and break_start < break_end
        and (is_closed or (break_start >= open_time and break_end <= close_time)))
  )
);

comment on table public.business_hours is 'Weekly opening hours. day_of_week: 0=Sunday .. 6=Saturday. Missing row = closed.';

-- Give every new business a sensible default week (Mon-Sat 09:00-18:00, Sunday closed)
create or replace function public.seed_default_business_hours()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.business_hours (business_id, day_of_week, is_closed, open_time, close_time)
  select new.id, d,
         d = 0,
         case when d = 0 then null else time '09:00' end,
         case when d = 0 then null else time '18:00' end
    from generate_series(0, 6) as d
  on conflict do nothing;
  return new;
end;
$$;

create trigger businesses_seed_hours
  after insert on public.businesses
  for each row execute function public.seed_default_business_hours();

-- ---------------------------------------------------------------------------
-- business_closures: holidays, one-off closures, staff time off
-- ---------------------------------------------------------------------------
create table public.business_closures (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid not null references public.businesses (id) on delete cascade,
  staff_id     uuid references public.staff_members (id) on delete cascade,
  starts_at    timestamptz not null,
  ends_at      timestamptz not null,
  reason       text,
  created_at   timestamptz not null default now(),
  constraint business_closures_range_valid check (starts_at < ends_at)
);

comment on column public.business_closures.staff_id is 'NULL = whole business closed. Set = only that staff member is off.';

create index business_closures_lookup_idx on public.business_closures (business_id, starts_at, ends_at);

-- ---------------------------------------------------------------------------
-- saved_businesses (customer favourites)
-- ---------------------------------------------------------------------------
create table public.saved_businesses (
  customer_id  uuid not null references public.profiles (id) on delete cascade,
  business_id  uuid not null references public.businesses (id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (customer_id, business_id)
);

create index saved_businesses_business_idx on public.saved_businesses (business_id);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.categories        enable row level security;
alter table public.businesses        enable row level security;
alter table public.staff_members     enable row level security;
alter table public.services          enable row level security;
alter table public.staff_services    enable row level security;
alter table public.business_hours    enable row level security;
alter table public.business_closures enable row level security;
alter table public.saved_businesses  enable row level security;

-- categories: read-only for everyone
create policy "categories: public read" on public.categories
  for select to anon, authenticated using (is_active);

-- businesses
create policy "businesses: public read published" on public.businesses
  for select to anon, authenticated
  using (is_published or owner_id = (select auth.uid()));

create policy "businesses: owner insert" on public.businesses
  for insert to authenticated
  with check (owner_id = (select auth.uid()));

create policy "businesses: owner update" on public.businesses
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy "businesses: owner delete" on public.businesses
  for delete to authenticated
  using (owner_id = (select auth.uid()));

-- staff_members
create policy "staff: public read active of published" on public.staff_members
  for select to anon, authenticated
  using ((is_active and public.is_business_public(business_id)) or public.is_business_owner(business_id));

create policy "staff: owner write" on public.staff_members
  for all to authenticated
  using (public.is_business_owner(business_id))
  with check (public.is_business_owner(business_id));

-- services
create policy "services: public read active of published" on public.services
  for select to anon, authenticated
  using ((is_active and public.is_business_public(business_id)) or public.is_business_owner(business_id));

create policy "services: owner write" on public.services
  for all to authenticated
  using (public.is_business_owner(business_id))
  with check (public.is_business_owner(business_id));

-- staff_services
create policy "staff_services: public read" on public.staff_services
  for select to anon, authenticated
  using (exists (select 1 from public.services s
                  where s.id = service_id
                    and (public.is_business_public(s.business_id) or public.is_business_owner(s.business_id))));

create policy "staff_services: owner write" on public.staff_services
  for all to authenticated
  using (exists (select 1 from public.services s where s.id = service_id and public.is_business_owner(s.business_id)))
  with check (exists (select 1 from public.services s where s.id = service_id and public.is_business_owner(s.business_id)));

-- business_hours
create policy "hours: public read" on public.business_hours
  for select to anon, authenticated
  using (public.is_business_public(business_id) or public.is_business_owner(business_id));

create policy "hours: owner write" on public.business_hours
  for all to authenticated
  using (public.is_business_owner(business_id))
  with check (public.is_business_owner(business_id));

-- business_closures: only owners see reasons; customers get availability via get_available_slots()
create policy "closures: owner all" on public.business_closures
  for all to authenticated
  using (public.is_business_owner(business_id))
  with check (public.is_business_owner(business_id));

-- saved_businesses
create policy "saved: own read" on public.saved_businesses
  for select to authenticated using (customer_id = (select auth.uid()));

create policy "saved: own insert" on public.saved_businesses
  for insert to authenticated
  with check (customer_id = (select auth.uid()) and public.is_business_public(business_id));

create policy "saved: own delete" on public.saved_businesses
  for delete to authenticated using (customer_id = (select auth.uid()));

revoke all on function public.is_business_owner(uuid)  from public;
revoke all on function public.is_business_public(uuid) from public;
grant execute on function public.is_business_owner(uuid)  to anon, authenticated;
grant execute on function public.is_business_public(uuid) to anon, authenticated;
revoke all on function public.seed_default_business_hours()   from public, anon, authenticated;
revoke all on function public.businesses_guard()              from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Storage buckets
--   avatars/<user_id>/...          user profile photos
--   business-media/<business_id>/... logos, covers, banners, service + staff photos
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars',        'avatars',        true, 2097152, array['image/jpeg','image/png','image/webp']),
  ('business-media', 'business-media', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

-- Public buckets serve files by URL without a SELECT policy, so no broad read policy (prevents listing).
create policy "avatars: owner manage own folder" on storage.objects
  for all to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "business-media: owner manage business folder" on storage.objects
  for all to authenticated
  using (
    bucket_id = 'business-media'
    and (storage.foldername(name))[1] ~ '^[0-9a-f-]{36}$'
    and public.is_business_owner(((storage.foldername(name))[1])::uuid)
  )
  with check (
    bucket_id = 'business-media'
    and (storage.foldername(name))[1] ~ '^[0-9a-f-]{36}$'
    and public.is_business_owner(((storage.foldername(name))[1])::uuid)
  );
