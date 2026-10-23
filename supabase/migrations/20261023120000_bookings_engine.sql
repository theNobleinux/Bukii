-- =============================================================================
-- Phase 4: Bookings, availability engine, double-booking protection, reviews
-- =============================================================================

create type public.booking_status as enum ('pending', 'confirmed', 'cancelled', 'completed', 'no_show');
create type public.payment_method as enum ('pay_on_arrival', 'cash', 'card', 'transfer');

-- ---------------------------------------------------------------------------
-- bookings
-- ---------------------------------------------------------------------------
create table public.bookings (
  id                    uuid primary key default gen_random_uuid(),
  reference             text not null unique,
  customer_id           uuid not null references public.profiles (id) on delete cascade,
  business_id           uuid not null references public.businesses (id) on delete cascade,
  staff_id              uuid references public.staff_members (id) on delete set null,
  staff_name            text,                      -- snapshot for history screens
  resource_id           uuid not null,             -- staff_id, or business_id when the business has no staff
  appointment_time      timestamptz not null,
  end_time              timestamptz not null,
  blocked_until         timestamptz not null,      -- end_time + buffer
  status                public.booking_status not null default 'pending',
  total_price           numeric(12,2) not null default 0 check (total_price >= 0),
  currency              text not null default 'NGN',
  payment_method        public.payment_method not null default 'pay_on_arrival',
  notes                 text check (notes is null or char_length(notes) <= 500),
  is_group              boolean not null default false,
  group_service_id      uuid references public.services (id) on delete set null,
  is_late_cancellation  boolean not null default false,
  cancelled_at          timestamptz,
  cancelled_by          uuid references public.profiles (id) on delete set null,
  cancellation_reason   text,
  completed_at          timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint bookings_time_valid check (appointment_time < end_time and end_time <= blocked_until),
  -- The database itself refuses two active one-to-one bookings on the same staff/resource at overlapping times.
  constraint bookings_no_double_booking exclude using gist (
    resource_id with =,
    tstzrange(appointment_time, blocked_until, '[)') with &&
  ) where (status in ('pending', 'confirmed') and not is_group)
);

comment on table  public.bookings is 'Create / change only through create_booking, reschedule_booking, cancel_booking, update_booking_status.';
comment on column public.bookings.resource_id is 'Who is occupied: staff_id, or business_id for businesses with no staff list.';

create index bookings_customer_idx   on public.bookings (customer_id, appointment_time desc);
create index bookings_business_idx   on public.bookings (business_id, appointment_time);
create index bookings_resource_idx   on public.bookings (resource_id, appointment_time) where status in ('pending', 'confirmed');

create trigger bookings_set_updated_at
  before update on public.bookings
  for each row execute function public.set_updated_at();

-- Services inside a booking (a booking can hold several, e.g. Haircut + Beard trim)
create table public.booking_services (
  id                uuid primary key default gen_random_uuid(),
  booking_id        uuid not null references public.bookings (id) on delete cascade,
  service_id        uuid references public.services (id) on delete set null,
  service_name      text not null,
  duration_minutes  integer not null,
  price             numeric(12,2) not null,
  position          smallint not null default 0
);

create index booking_services_booking_idx on public.booking_services (booking_id);
create index booking_services_service_idx on public.booking_services (service_id);

-- ---------------------------------------------------------------------------
-- reviews (one per completed booking)
-- ---------------------------------------------------------------------------
create table public.reviews (
  id             uuid primary key default gen_random_uuid(),
  booking_id     uuid not null unique references public.bookings (id) on delete cascade,
  business_id    uuid not null references public.businesses (id) on delete cascade,
  customer_id    uuid not null references public.profiles (id) on delete cascade,
  reviewer_name  text,
  rating         smallint not null check (rating between 1 and 5),
  comment        text check (comment is null or char_length(comment) <= 1000),
  owner_reply    text check (owner_reply is null or char_length(owner_reply) <= 1000),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create index reviews_business_idx on public.reviews (business_id, created_at desc);

create trigger reviews_set_updated_at
  before update on public.reviews
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------
create or replace function public.generate_booking_reference()
returns text
language plpgsql
set search_path = ''
as $$
declare
  v_chars constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_ref   text;
  i       int;
begin
  loop
    v_ref := 'BK-';
    for i in 1..6 loop
      v_ref := v_ref || substr(v_chars, 1 + floor(random() * length(v_chars))::int, 1);
    end loop;
    exit when not exists (select 1 from public.bookings where reference = v_ref);
  end loop;
  return v_ref;
end;
$$;

-- Is [p_start, p_end) inside the business opening hours, outside breaks and whole-business closures?
create or replace function public._within_opening_hours(p_business_id uuid, p_start timestamptz, p_end timestamptz)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tz         text;
  v_local_s    timestamp;
  v_local_e    timestamp;
  v_day        date;
  h            public.business_hours;
begin
  select timezone into v_tz from public.businesses where id = p_business_id;
  if v_tz is null then return false; end if;

  v_local_s := p_start at time zone v_tz;
  v_local_e := p_end   at time zone v_tz;
  v_day     := v_local_s::date;

  -- must finish on the same local day
  if v_local_e > v_day + interval '1 day' then return false; end if;

  select * into h from public.business_hours
   where business_id = p_business_id and day_of_week = extract(dow from v_day)::smallint;

  if not found or h.is_closed then return false; end if;
  if v_local_s < v_day + h.open_time or v_local_e > v_day + h.close_time then return false; end if;

  if h.break_start is not null
     and v_local_s < v_day + h.break_end
     and v_local_e > v_day + h.break_start then
    return false;
  end if;

  if exists (select 1 from public.business_closures c
              where c.business_id = p_business_id and c.staff_id is null
                and c.starts_at < p_end and c.ends_at > p_start) then
    return false;
  end if;

  return true;
end;
$$;

-- Returns the resources (staff ids, or the business id) free for the given block, best candidate first.
create or replace function public._free_resources(
  p_business_id       uuid,
  p_start             timestamptz,
  p_block_until       timestamptz,
  p_service_ids       uuid[],
  p_staff_id          uuid default null,
  p_group_service_id  uuid default null,
  p_capacity          integer default 1,
  p_exclude_booking   uuid default null
)
returns uuid[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_has_staff  boolean;
  v_result     uuid[];
begin
  select exists (select 1 from public.staff_members s where s.business_id = p_business_id and s.is_active)
    into v_has_staff;

  with candidates as (
    select s.id as resource_id, s.sort_order
      from public.staff_members s
     where v_has_staff
       and s.business_id = p_business_id
       and s.is_active
       and (p_staff_id is null or s.id = p_staff_id)
       -- qualified: no restriction rows, or covers every requested service
       and (
         not exists (select 1 from public.staff_services ss where ss.staff_id = s.id)
         or (select count(*) from public.staff_services ss
              where ss.staff_id = s.id and ss.service_id = any (p_service_ids))
            = cardinality(p_service_ids)
       )
       -- not on time off
       and not exists (select 1 from public.business_closures c
                        where c.staff_id = s.id and c.starts_at < p_block_until and c.ends_at > p_start)
    union all
    select p_business_id, 0
     where not v_has_staff and p_staff_id is null
  ),
  scored as (
    select c.resource_id,
           c.sort_order,
           -- bookings in the same group session on this resource
           (select count(*) from public.bookings b
             where b.resource_id = c.resource_id
               and b.status in ('pending', 'confirmed')
               and b.id is distinct from p_exclude_booking
               and p_group_service_id is not null
               and b.is_group and b.group_service_id = p_group_service_id
               and b.appointment_time = p_start) as session_count,
           -- anything else overlapping on this resource
           (select count(*) from public.bookings b
             where b.resource_id = c.resource_id
               and b.status in ('pending', 'confirmed')
               and b.id is distinct from p_exclude_booking
               and b.appointment_time < p_block_until
               and b.blocked_until > p_start
               and not (p_group_service_id is not null
                        and b.is_group and b.group_service_id = p_group_service_id
                        and b.appointment_time = p_start)) as conflicts,
           -- load that day, used to spread bookings across staff
           (select count(*) from public.bookings b
             where b.resource_id = c.resource_id
               and b.status in ('pending', 'confirmed')
               and b.appointment_time >= date_trunc('day', p_start)
               and b.appointment_time <  date_trunc('day', p_start) + interval '1 day') as day_load
      from candidates c
  )
  select array_agg(resource_id order by (session_count > 0) desc, day_load, sort_order, resource_id)
    into v_result
    from scored
   where conflicts = 0
     and session_count < greatest(p_capacity, 1);

  return coalesce(v_result, '{}');
end;
$$;

-- Resolve + validate requested services. Returns total duration, buffer, price, group info.
create or replace function public._resolve_services(p_business_id uuid, p_service_ids uuid[])
returns table (total_minutes integer, buffer_minutes integer, total_price numeric, group_service_id uuid, capacity integer)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_count       int;
  v_group_count int;
begin
  if p_service_ids is null or cardinality(p_service_ids) = 0 then
    raise exception 'Choose at least one service.' using errcode = 'P0001', hint = 'no_services';
  end if;
  if cardinality(p_service_ids) <> (select count(distinct x) from unnest(p_service_ids) x) then
    raise exception 'A service was selected twice.' using errcode = 'P0001', hint = 'duplicate_service';
  end if;

  select count(*), count(*) filter (where s.max_capacity > 1)
    into v_count, v_group_count
    from public.services s
   where s.id = any (p_service_ids) and s.business_id = p_business_id and s.is_active;

  if v_count <> cardinality(p_service_ids) then
    raise exception 'One or more services are not available at this business.' using errcode = 'P0001', hint = 'invalid_service';
  end if;
  if v_group_count > 0 and cardinality(p_service_ids) > 1 then
    raise exception 'Group sessions must be booked on their own.' using errcode = 'P0001', hint = 'group_must_be_alone';
  end if;

  return query
  select sum(s.duration_minutes)::int,
         max(s.buffer_minutes)::int,
         sum(s.price),
         (array_agg(s.id) filter (where s.max_capacity > 1))[1],
         max(s.max_capacity)::int
    from public.services s
   where s.id = any (p_service_ids);
end;
$$;

-- ---------------------------------------------------------------------------
-- PUBLIC: available time slots for a date
-- ---------------------------------------------------------------------------
create or replace function public.get_available_slots(
  p_business_id  uuid,
  p_date         date,
  p_service_ids  uuid[],
  p_staff_id     uuid default null
)
returns table (
  slot_start       timestamptz,
  slot_end         timestamptz,
  local_time       text,         -- "10:30" in the business timezone, ready to display
  available_staff  uuid[],       -- empty when the business has no staff list
  spots_left       integer       -- group sessions: seats left; otherwise number of free staff
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  b          public.businesses;
  h          public.business_hours;
  svc        record;
  v_now_loc  timestamp;
  v_t        timestamp;
  v_close    timestamp;
  v_start    timestamptz;
  v_end      timestamptz;
  v_block    timestamptz;
  v_free     uuid[];
  v_has_staff boolean;
begin
  select * into b from public.businesses where id = p_business_id;
  if not found or not (b.is_published or b.owner_id = auth.uid()) then
    raise exception 'Business not found.' using errcode = 'P0001', hint = 'business_not_found';
  end if;

  select * into svc from public._resolve_services(p_business_id, p_service_ids);

  v_now_loc := now() at time zone b.timezone;
  if p_date < v_now_loc::date or p_date > v_now_loc::date + b.max_advance_days then
    return;
  end if;

  select * into h from public.business_hours
   where business_id = p_business_id and day_of_week = extract(dow from p_date)::smallint;
  if not found or h.is_closed then
    return;
  end if;

  select exists (select 1 from public.staff_members s where s.business_id = p_business_id and s.is_active)
    into v_has_staff;

  v_t     := p_date + h.open_time;
  v_close := p_date + h.close_time;

  while v_t + make_interval(mins => svc.total_minutes) <= v_close loop
    v_start := v_t at time zone b.timezone;
    v_end   := v_start + make_interval(mins => svc.total_minutes);
    v_block := v_end   + make_interval(mins => svc.buffer_minutes);

    if v_start >= now() + make_interval(mins => b.min_notice_minutes)
       and public._within_opening_hours(p_business_id, v_start, v_end) then

      v_free := public._free_resources(p_business_id, v_start, v_block, p_service_ids, p_staff_id,
                                       svc.group_service_id, svc.capacity, null);

      if cardinality(v_free) > 0 then
        slot_start      := v_start;
        slot_end        := v_end;
        local_time      := to_char(v_t, 'HH24:MI');
        available_staff := case when v_has_staff then v_free else '{}'::uuid[] end;
        if svc.group_service_id is not null then
          select svc.capacity - count(*)::int into spots_left
            from public.bookings bk
           where bk.resource_id = v_free[1]
             and bk.status in ('pending', 'confirmed')
             and bk.is_group and bk.group_service_id = svc.group_service_id
             and bk.appointment_time = v_start;
        else
          spots_left := cardinality(v_free);
        end if;
        return next;
      end if;
    end if;

    v_t := v_t + make_interval(mins => b.slot_interval_minutes);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Shape a booking as JSON for the app
-- ---------------------------------------------------------------------------
create or replace function public._booking_json(p_booking_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select to_jsonb(bk) || jsonb_build_object(
    'business', jsonb_build_object(
        'id', b.id, 'name', b.name, 'logo_url', b.logo_url, 'area', b.area,
        'address', b.address, 'phone', b.phone, 'timezone', b.timezone),
    'services', coalesce((select jsonb_agg(to_jsonb(bs) order by bs.position)
                            from public.booking_services bs where bs.booking_id = bk.id), '[]'::jsonb)
  )
  from public.bookings bk
  join public.businesses b on b.id = bk.business_id
  where bk.id = p_booking_id;
$$;

-- ---------------------------------------------------------------------------
-- PUBLIC: create a booking (customer)
-- ---------------------------------------------------------------------------
create or replace function public.create_booking(
  p_business_id     uuid,
  p_service_ids     uuid[],
  p_start           timestamptz,
  p_staff_id        uuid default null,
  p_payment_method  public.payment_method default 'pay_on_arrival',
  p_notes           text default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := auth.uid();
  b          public.businesses;
  svc        record;
  v_end      timestamptz;
  v_block    timestamptz;
  v_free     uuid[];
  v_resource uuid;
  v_staff    public.staff_members;
  v_id       uuid;
begin
  if v_uid is null then
    raise exception 'Please sign in to book.' using errcode = '42501';
  end if;

  select * into b from public.businesses where id = p_business_id;
  if not found or not (b.is_published or b.owner_id = v_uid) then
    raise exception 'Business not found.' using errcode = 'P0001', hint = 'business_not_found';
  end if;

  -- serialise bookings per business so two people can never grab the same slot
  perform pg_advisory_xact_lock(hashtextextended('booking:' || p_business_id::text, 0));

  select * into svc from public._resolve_services(p_business_id, p_service_ids);

  v_end   := p_start + make_interval(mins => svc.total_minutes);
  v_block := v_end   + make_interval(mins => svc.buffer_minutes);

  if p_start < now() + make_interval(mins => b.min_notice_minutes) then
    raise exception 'Please choose a later time.' using errcode = 'P0001', hint = 'too_soon';
  end if;
  if p_start > now() + make_interval(days => b.max_advance_days) then
    raise exception 'That date is too far ahead.' using errcode = 'P0001', hint = 'too_far';
  end if;
  if not public._within_opening_hours(p_business_id, p_start, v_end) then
    raise exception 'The business is closed at that time.' using errcode = 'P0001', hint = 'outside_hours';
  end if;

  if exists (select 1 from public.bookings x
              where x.customer_id = v_uid and x.business_id = p_business_id
                and x.status in ('pending', 'confirmed')
                and x.appointment_time < v_end and x.end_time > p_start) then
    raise exception 'You already have a booking here at that time.' using errcode = 'P0001', hint = 'customer_overlap';
  end if;

  v_free := public._free_resources(p_business_id, p_start, v_block, p_service_ids, p_staff_id,
                                   svc.group_service_id, svc.capacity, null);
  if cardinality(v_free) = 0 then
    raise exception 'Sorry, that time was just taken. Please pick another slot.' using errcode = 'P0001', hint = 'slot_unavailable';
  end if;

  v_resource := v_free[1];
  select * into v_staff from public.staff_members where id = v_resource;

  insert into public.bookings (
    reference, customer_id, business_id, staff_id, staff_name, resource_id,
    appointment_time, end_time, blocked_until, status, total_price, currency,
    payment_method, notes, is_group, group_service_id
  ) values (
    public.generate_booking_reference(), v_uid, p_business_id, v_staff.id, v_staff.full_name, v_resource,
    p_start, v_end, v_block,
    case when b.auto_confirm_bookings then 'confirmed' else 'pending' end::public.booking_status,
    svc.total_price, b.currency, coalesce(p_payment_method, 'pay_on_arrival'),
    nullif(trim(p_notes), ''), svc.group_service_id is not null, svc.group_service_id
  )
  returning id into v_id;

  insert into public.booking_services (booking_id, service_id, service_name, duration_minutes, price, position)
  select v_id, s.id, s.name, s.duration_minutes, s.price, (o.ord - 1)::smallint
    from unnest(p_service_ids) with ordinality as o(sid, ord)
    join public.services s on s.id = o.sid;

  return public._booking_json(v_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- PUBLIC: reschedule (customer or owner)
-- ---------------------------------------------------------------------------
create or replace function public.reschedule_booking(
  p_booking_id  uuid,
  p_new_start   timestamptz,
  p_staff_id    uuid default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := auth.uid();
  bk         public.bookings;
  b          public.businesses;
  v_is_owner boolean;
  v_ids      uuid[];
  svc        record;
  v_end      timestamptz;
  v_block    timestamptz;
  v_free     uuid[];
  v_resource uuid;
  v_staff    public.staff_members;
begin
  select * into bk from public.bookings where id = p_booking_id;
  if not found then
    raise exception 'Booking not found.' using errcode = 'P0001', hint = 'booking_not_found';
  end if;
  select * into b from public.businesses where id = bk.business_id;
  v_is_owner := b.owner_id = v_uid;

  if v_uid is null or not (bk.customer_id = v_uid or v_is_owner) then
    raise exception 'Booking not found.' using errcode = 'P0001', hint = 'booking_not_found';
  end if;
  if bk.status not in ('pending', 'confirmed') then
    raise exception 'Only upcoming bookings can be rescheduled.' using errcode = 'P0001', hint = 'not_active';
  end if;
  if not v_is_owner and now() > bk.appointment_time - make_interval(mins => b.cancellation_window_minutes) then
    raise exception 'It is too late to reschedule this booking.' using errcode = 'P0001', hint = 'too_late';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('booking:' || bk.business_id::text, 0));

  select coalesce(array_agg(service_id order by position), '{}') into v_ids
    from public.booking_services where booking_id = bk.id and service_id is not null;

  select * into svc from public._resolve_services(bk.business_id, v_ids);
  v_end   := p_new_start + make_interval(mins => svc.total_minutes);
  v_block := v_end + make_interval(mins => svc.buffer_minutes);

  if not v_is_owner and p_new_start < now() + make_interval(mins => b.min_notice_minutes) then
    raise exception 'Please choose a later time.' using errcode = 'P0001', hint = 'too_soon';
  end if;
  if p_new_start > now() + make_interval(days => b.max_advance_days) then
    raise exception 'That date is too far ahead.' using errcode = 'P0001', hint = 'too_far';
  end if;
  if not public._within_opening_hours(bk.business_id, p_new_start, v_end) then
    raise exception 'The business is closed at that time.' using errcode = 'P0001', hint = 'outside_hours';
  end if;

  -- prefer keeping the same staff member
  v_free := public._free_resources(bk.business_id, p_new_start, v_block, v_ids,
                                   coalesce(p_staff_id, bk.staff_id), svc.group_service_id, svc.capacity, bk.id);
  if cardinality(v_free) = 0 and p_staff_id is null then
    v_free := public._free_resources(bk.business_id, p_new_start, v_block, v_ids,
                                     null, svc.group_service_id, svc.capacity, bk.id);
  end if;
  if cardinality(v_free) = 0 then
    raise exception 'Sorry, that time is not available.' using errcode = 'P0001', hint = 'slot_unavailable';
  end if;

  v_resource := v_free[1];
  select * into v_staff from public.staff_members where id = v_resource;

  update public.bookings
     set appointment_time = p_new_start,
         end_time         = v_end,
         blocked_until    = v_block,
         resource_id      = v_resource,
         staff_id         = v_staff.id,
         staff_name       = v_staff.full_name
   where id = bk.id;

  return public._booking_json(bk.id);
end;
$$;

-- ---------------------------------------------------------------------------
-- PUBLIC: cancel (customer or owner)
-- ---------------------------------------------------------------------------
create or replace function public.cancel_booking(p_booking_id uuid, p_reason text default null)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := auth.uid();
  bk         public.bookings;
  b          public.businesses;
  v_is_owner boolean;
begin
  select * into bk from public.bookings where id = p_booking_id for update;
  if not found then
    raise exception 'Booking not found.' using errcode = 'P0001', hint = 'booking_not_found';
  end if;
  select * into b from public.businesses where id = bk.business_id;
  v_is_owner := b.owner_id = v_uid;

  if v_uid is null or not (bk.customer_id = v_uid or v_is_owner) then
    raise exception 'Booking not found.' using errcode = 'P0001', hint = 'booking_not_found';
  end if;
  if bk.status not in ('pending', 'confirmed') then
    raise exception 'This booking can no longer be cancelled.' using errcode = 'P0001', hint = 'not_active';
  end if;
  if not v_is_owner and bk.appointment_time <= now() then
    raise exception 'This appointment has already started.' using errcode = 'P0001', hint = 'already_started';
  end if;

  update public.bookings
     set status               = 'cancelled',
         cancelled_at         = now(),
         cancelled_by         = v_uid,
         cancellation_reason  = nullif(trim(p_reason), ''),
         is_late_cancellation = (not v_is_owner)
                                and now() > bk.appointment_time - make_interval(mins => b.cancellation_window_minutes)
   where id = bk.id;

  return public._booking_json(bk.id);
end;
$$;

-- ---------------------------------------------------------------------------
-- PUBLIC: owner moves a booking through its lifecycle
--   pending   -> confirmed | cancelled
--   confirmed -> completed | no_show | cancelled
-- ---------------------------------------------------------------------------
create or replace function public.update_booking_status(p_booking_id uuid, p_status public.booking_status)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  bk public.bookings;
begin
  select * into bk from public.bookings where id = p_booking_id for update;
  if not found or not public.is_business_owner(bk.business_id) then
    raise exception 'Booking not found.' using errcode = 'P0001', hint = 'booking_not_found';
  end if;

  if p_status = 'cancelled' then
    return public.cancel_booking(p_booking_id, 'Cancelled by business');
  end if;

  if not (
       (bk.status = 'pending'   and p_status = 'confirmed')
    or (bk.status = 'confirmed' and p_status in ('completed', 'no_show'))
  ) then
    raise exception 'Cannot change a % booking to %.', bk.status, p_status using errcode = 'P0001', hint = 'invalid_transition';
  end if;

  if p_status in ('completed', 'no_show') and bk.appointment_time > now() then
    raise exception 'This appointment has not started yet.' using errcode = 'P0001', hint = 'not_started';
  end if;

  update public.bookings
     set status       = p_status,
         completed_at = case when p_status = 'completed' then now() else completed_at end
   where id = bk.id;

  return public._booking_json(bk.id);
end;
$$;

-- ---------------------------------------------------------------------------
-- PUBLIC: owner dashboard numbers (revenue is owner-only)
-- ---------------------------------------------------------------------------
create or replace function public.get_business_stats(
  p_business_id uuid,
  p_from        date default (now() at time zone 'Africa/Lagos')::date - 30,
  p_to          date default (now() at time zone 'Africa/Lagos')::date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tz     text;
  v_from   timestamptz;
  v_to     timestamptz;
  v_result jsonb;
begin
  if not public.is_business_owner(p_business_id) then
    raise exception 'Not allowed.' using errcode = '42501';
  end if;

  select timezone into v_tz from public.businesses where id = p_business_id;
  v_from := p_from::timestamp at time zone v_tz;
  v_to   := (p_to + 1)::timestamp at time zone v_tz;

  select jsonb_build_object(
    'from', p_from, 'to', p_to,
    'revenue_completed',  coalesce(sum(total_price) filter (where status = 'completed'), 0),
    'revenue_expected',   coalesce(sum(total_price) filter (where status in ('pending', 'confirmed')), 0),
    'bookings_total',     count(*),
    'bookings_pending',   count(*) filter (where status = 'pending'),
    'bookings_confirmed', count(*) filter (where status = 'confirmed'),
    'bookings_completed', count(*) filter (where status = 'completed'),
    'bookings_cancelled', count(*) filter (where status = 'cancelled'),
    'bookings_no_show',   count(*) filter (where status = 'no_show'),
    'unique_customers',   count(distinct customer_id),
    'today_upcoming', (select count(*) from public.bookings t
                        where t.business_id = p_business_id
                          and t.status in ('pending', 'confirmed')
                          and t.appointment_time >= now()
                          and t.appointment_time < ((now() at time zone v_tz)::date + 1)::timestamp at time zone v_tz)
  ) into v_result
  from public.bookings
  where business_id = p_business_id
    and appointment_time >= v_from and appointment_time < v_to;

  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Reviews: validation + rating aggregate
-- ---------------------------------------------------------------------------
create or replace function public.reviews_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  bk public.bookings;
  v_name text;
begin
  if tg_op = 'INSERT' then
    select * into bk from public.bookings where id = new.booking_id;
    if not found or bk.customer_id <> auth.uid() or bk.status <> 'completed' then
      raise exception 'You can only review your own completed bookings.' using errcode = '42501';
    end if;
    new.business_id := bk.business_id;
    new.customer_id := bk.customer_id;
    new.owner_reply := null;
    select split_part(coalesce(full_name, 'Customer'), ' ', 1) into v_name from public.profiles where id = bk.customer_id;
    new.reviewer_name := coalesce(v_name, 'Customer');
  else
    new.booking_id  := old.booking_id;
    new.business_id := old.business_id;
    new.customer_id := old.customer_id;
    if coalesce(auth.jwt() ->> 'role', '') in ('authenticated', 'anon') then
      if public.is_business_owner(old.business_id) and old.customer_id <> auth.uid() then
        -- owner can only reply
        new.rating  := old.rating;
        new.comment := old.comment;
        new.reviewer_name := old.reviewer_name;
      else
        new.owner_reply := old.owner_reply;
        new.reviewer_name := old.reviewer_name;
      end if;
    end if;
  end if;
  return new;
end;
$$;

create trigger reviews_guard
  before insert or update on public.reviews
  for each row execute function public.reviews_guard();

create or replace function public.refresh_business_rating()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_business uuid := coalesce(new.business_id, old.business_id);
begin
  update public.businesses b
     set rating_avg   = coalesce((select round(avg(r.rating)::numeric, 1) from public.reviews r where r.business_id = v_business), 0),
         rating_count = (select count(*) from public.reviews r where r.business_id = v_business)
   where b.id = v_business;
  return null;
end;
$$;

create trigger reviews_refresh_rating
  after insert or update of rating or delete on public.reviews
  for each row execute function public.refresh_business_rating();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.bookings         enable row level security;
alter table public.booking_services enable row level security;
alter table public.reviews          enable row level security;

-- bookings: read own (customer) or own business (owner). All writes go through the functions above.
create policy "bookings: customer reads own" on public.bookings
  for select to authenticated
  using (customer_id = (select auth.uid()));

create policy "bookings: owner reads business bookings" on public.bookings
  for select to authenticated
  using (public.is_business_owner(business_id));

create policy "booking_services: read with booking" on public.booking_services
  for select to authenticated
  using (exists (select 1 from public.bookings bk where bk.id = booking_id));  -- inherits bookings RLS

-- reviews: public for published businesses; customers write their own; owners reply
create policy "reviews: public read" on public.reviews
  for select to anon, authenticated
  using (public.is_business_public(business_id) or customer_id = (select auth.uid()) or public.is_business_owner(business_id));

create policy "reviews: customer insert" on public.reviews
  for insert to authenticated
  with check (customer_id = (select auth.uid()));

create policy "reviews: customer edit own" on public.reviews
  for update to authenticated
  using (customer_id = (select auth.uid()) or public.is_business_owner(business_id))
  with check (customer_id = (select auth.uid()) or public.is_business_owner(business_id));

create policy "reviews: customer delete own" on public.reviews
  for delete to authenticated
  using (customer_id = (select auth.uid()));

-- Customers can still see a business they booked even if it is later unpublished
create or replace function public.has_booked_business(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.bookings b where b.business_id = p_business_id and b.customer_id = auth.uid());
$$;

create policy "businesses: customers read businesses they booked" on public.businesses
  for select to authenticated
  using (public.has_booked_business(id));

-- Owners can see the profile (name, phone, avatar) of customers who booked them
create or replace function public.is_my_customer(p_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.bookings bk
      join public.businesses b on b.id = bk.business_id
     where bk.customer_id = p_profile_id and b.owner_id = auth.uid()
  );
$$;

create policy "profiles: owners read their customers" on public.profiles
  for select to authenticated
  using (public.is_my_customer(id));

-- ---------------------------------------------------------------------------
-- Grants: internal helpers hidden from the API, public RPCs exposed
-- ---------------------------------------------------------------------------
revoke all on function public.generate_booking_reference()                  from public, anon, authenticated;
revoke all on function public._within_opening_hours(uuid, timestamptz, timestamptz) from public, anon, authenticated;
revoke all on function public._free_resources(uuid, timestamptz, timestamptz, uuid[], uuid, uuid, integer, uuid) from public, anon, authenticated;
revoke all on function public._resolve_services(uuid, uuid[])                from public, anon, authenticated;
revoke all on function public._booking_json(uuid)                            from public, anon, authenticated;
revoke all on function public.reviews_guard()                                from public, anon, authenticated;
revoke all on function public.refresh_business_rating()                      from public, anon, authenticated;

revoke all on function public.get_available_slots(uuid, date, uuid[], uuid) from public;
grant execute on function public.get_available_slots(uuid, date, uuid[], uuid) to anon, authenticated;

revoke all on function public.create_booking(uuid, uuid[], timestamptz, uuid, public.payment_method, text) from public, anon;
revoke all on function public.reschedule_booking(uuid, timestamptz, uuid)    from public, anon;
revoke all on function public.cancel_booking(uuid, text)                     from public, anon;
revoke all on function public.update_booking_status(uuid, public.booking_status) from public, anon;
revoke all on function public.get_business_stats(uuid, date, date)           from public, anon;
revoke all on function public.has_booked_business(uuid)                      from public, anon;
revoke all on function public.is_my_customer(uuid)                           from public, anon;

grant execute on function public.create_booking(uuid, uuid[], timestamptz, uuid, public.payment_method, text) to authenticated;
grant execute on function public.reschedule_booking(uuid, timestamptz, uuid)    to authenticated;
grant execute on function public.cancel_booking(uuid, text)                     to authenticated;
grant execute on function public.update_booking_status(uuid, public.booking_status) to authenticated;
grant execute on function public.get_business_stats(uuid, date, date)           to authenticated;
grant execute on function public.has_booked_business(uuid)                      to authenticated;
grant execute on function public.is_my_customer(uuid)                           to authenticated;
