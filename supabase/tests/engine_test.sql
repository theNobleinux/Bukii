-- Booking engine + security test. Runs inside a transaction and ROLLS BACK (leaves no data).
-- Run: paste into Supabase SQL editor, or via Management API.
begin;

create temp table t (n serial, msg text);
grant all on t to anon, authenticated;
grant all on sequence t_n_seq to anon, authenticated;

create or replace function pg_temp.act(p_uid uuid) returns void language plpgsql as $$
begin
  execute 'reset role';
  if p_uid is null then
    perform set_config('request.jwt.claims', '{"role":"anon"}', true);
    execute 'set local role anon';
  else
    perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
  end if;
end $$;

create or replace function pg_temp.log(m text) returns void language sql as $$ insert into t(msg) values (m) $$;

-- users
insert into auth.users (id, instance_id, aud, role, phone, raw_user_meta_data, created_at, updated_at) values
 ('00000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-000000000000','authenticated','authenticated','2348090000001','{"role":"business_owner","full_name":"Owner One"}',now(),now()),
 ('00000000-0000-0000-0000-00000000000b','00000000-0000-0000-0000-000000000000','authenticated','authenticated','2348090000002','{"role":"business_owner","full_name":"Owner Two"}',now(),now()),
 ('00000000-0000-0000-0000-0000000000c1','00000000-0000-0000-0000-000000000000','authenticated','authenticated','2348090000003','{"role":"customer","full_name":"Cust One"}',now(),now()),
 ('00000000-0000-0000-0000-0000000000c2','00000000-0000-0000-0000-000000000000','authenticated','authenticated','2348090000004','{"role":"customer","full_name":"Cust Two"}',now(),now()),
 ('00000000-0000-0000-0000-0000000000c3','00000000-0000-0000-0000-000000000000','authenticated','authenticated','2348090000005','{"role":"customer","full_name":"Cust Three"}',now(),now());

do $$
declare
  O  uuid := '00000000-0000-0000-0000-00000000000a';
  O2 uuid := '00000000-0000-0000-0000-00000000000b';
  C1 uuid := '00000000-0000-0000-0000-0000000000c1';
  C2 uuid := '00000000-0000-0000-0000-0000000000c2';
  C3 uuid := '00000000-0000-0000-0000-0000000000c3';
  biz uuid; hair uuid; beard uuid; yoga uuid; tunde uuid; nneka uuid;
  mon date := (now() at time zone 'Africa/Lagos')::date + ((8 - extract(isodow from (now() at time zone 'Africa/Lagos')::date)::int) % 7 + 7);
  sun date;
  j jsonb; n int; x text; bk1 uuid;
  t10 timestamptz;
begin
  sun := mon - 1;
  t10 := (mon + time '10:00') at time zone 'Africa/Lagos';

  -- ===== owner sets up business =====
  perform pg_temp.act(C1);
  begin
    insert into public.businesses (owner_id, name, category_id) values (C1, 'Hack', 1);
    perform pg_temp.log('FAIL customer created business');
  exception when others then perform pg_temp.log('ok  customer cannot create business');
  end;

  perform pg_temp.act(O);
  insert into public.businesses (owner_id, name, category_id, area, is_published)
    values (O, 'Fade Lab', 1, 'Ikoyi', true) returning id into biz;
  update public.business_hours set break_start = '13:00', break_end = '14:00' where business_id = biz and day_of_week = 1;
  insert into public.services (business_id, name, duration_minutes, price) values (biz, 'Haircut', 30, 12000) returning id into hair;
  insert into public.services (business_id, name, duration_minutes, price) values (biz, 'Beard trim', 30, 6000) returning id into beard;
  insert into public.services (business_id, name, duration_minutes, price, max_capacity) values (biz, 'Group class', 60, 5000, 2) returning id into yoga;
  insert into public.staff_members (business_id, full_name, sort_order) values (biz, 'Tunde', 1) returning id into tunde;
  insert into public.staff_members (business_id, full_name, sort_order) values (biz, 'Nneka', 2) returning id into nneka;
  insert into public.staff_services values (nneka, hair);
  select count(*) into n from public.business_hours where business_id = biz;
  perform pg_temp.log('ok  default hours rows: ' || n);

  -- other owner cannot touch it
  perform pg_temp.act(O2);
  update public.services set price = 1 where id = hair;
  get diagnostics n = row_count;
  perform pg_temp.log(case when n = 0 then 'ok  other owner cannot edit services' else 'FAIL other owner edited services' end);

  -- ===== availability =====
  perform pg_temp.act(null);  -- anon can browse slots
  select count(*), min(local_time), string_agg(local_time, ',') filter (where local_time between '12:30' and '14:00')
    into n, x, x
    from public.get_available_slots(biz, mon, array[hair]);
  perform pg_temp.log('ok  anon slots Monday haircut: ' || n || ' | around break: ' || coalesce(x, '-'));
  select count(*) into n from public.get_available_slots(biz, sun, array[hair]);
  perform pg_temp.log(case when n = 0 then 'ok  Sunday closed: 0 slots' else 'FAIL Sunday slots ' || n end);

  begin
    perform public.create_booking(biz, array[hair], t10);
    perform pg_temp.log('FAIL anon booked');
  exception when others then perform pg_temp.log('ok  anon cannot book');
  end;

  -- ===== bookings =====
  perform pg_temp.act(C1);
  j := public.create_booking(biz, array[hair, beard], t10);
  bk1 := (j ->> 'id')::uuid;
  perform pg_temp.log('ok  C1 haircut+beard 10:00 -> staff ' || (j ->> 'staff_name') || ', ' || (j ->> 'status') || ', N' || (j ->> 'total_price') || ', ref ' || (j ->> 'reference'));

  perform pg_temp.act(C2);
  begin
    perform public.create_booking(biz, array[hair, beard], t10);
    perform pg_temp.log('FAIL C2 got haircut+beard at 10:00 (Nneka not qualified, Tunde busy)');
  exception when others then perform pg_temp.log('ok  C2 haircut+beard 10:00 refused: ' || sqlerrm);
  end;

  j := public.create_booking(biz, array[hair], t10);
  perform pg_temp.log('ok  C2 haircut 10:00 -> staff ' || (j ->> 'staff_name'));

  perform pg_temp.act(C3);
  begin
    perform public.create_booking(biz, array[hair], t10 + interval '15 minutes');
    perform pg_temp.log('FAIL C3 got 10:15 though both staff busy');
  exception when others then perform pg_temp.log('ok  C3 10:15 refused (both staff busy)');
  end;
  begin
    perform public.create_booking(biz, array[hair], (mon + time '13:15') at time zone 'Africa/Lagos');
    perform pg_temp.log('FAIL booked during break');
  exception when others then perform pg_temp.log('ok  break time refused: ' || sqlerrm);
  end;

  -- group class: capacity 2 (Tunde only, Nneka restricted to haircut)
  perform pg_temp.act(C1);
  perform public.create_booking(biz, array[yoga], (mon + time '15:00') at time zone 'Africa/Lagos');
  perform pg_temp.act(C2);
  j := public.create_booking(biz, array[yoga], (mon + time '15:00') at time zone 'Africa/Lagos');
  perform pg_temp.log('ok  group class 2 seats filled, 2nd with ' || (j ->> 'staff_name'));
  perform pg_temp.act(C3);
  begin
    perform public.create_booking(biz, array[yoga], (mon + time '15:00') at time zone 'Africa/Lagos');
    perform pg_temp.log('FAIL group over capacity');
  exception when others then perform pg_temp.log('ok  group class full refused');
  end;
  begin
    perform public.create_booking(biz, array[yoga, hair], (mon + time '16:00') at time zone 'Africa/Lagos');
    perform pg_temp.log('FAIL mixed group + normal');
  exception when others then perform pg_temp.log('ok  group + other service refused');
  end;

  -- ===== visibility =====
  perform pg_temp.act(C2);
  select count(*) into n from public.bookings;
  perform pg_temp.log('ok  C2 sees own bookings only: ' || n || ' (expect 2)');
  begin
    perform public.update_booking_status(bk1, 'completed');
    perform pg_temp.log('FAIL customer changed status');
  exception when others then perform pg_temp.log('ok  customer cannot change status');
  end;
  begin
    perform public.cancel_booking(bk1);
    perform pg_temp.log('FAIL C2 cancelled C1 booking');
  exception when others then perform pg_temp.log('ok  C2 cannot cancel C1 booking');
  end;
  begin
    perform public.get_business_stats(biz);
    perform pg_temp.log('FAIL customer read revenue');
  exception when others then perform pg_temp.log('ok  customer cannot read revenue');
  end;
  update public.bookings set total_price = 0 where id = bk1;
  get diagnostics n = row_count;
  perform pg_temp.log(case when n = 0 then 'ok  direct booking update blocked' else 'FAIL direct update' end);

  perform pg_temp.act(O);
  select count(*) into n from public.bookings;
  perform pg_temp.log('ok  owner sees business bookings: ' || n || ' (expect 4)');
  select count(*) into n from public.profiles;
  perform pg_temp.log('ok  owner sees own + customer profiles: ' || n || ' (expect 3)');
  j := public.get_business_stats(biz, mon - 1, mon + 1);
  perform pg_temp.log('ok  owner stats: expected revenue N' || (j ->> 'revenue_expected') || ', bookings ' || (j ->> 'bookings_total'));

  perform pg_temp.act(O2);
  select count(*) into n from public.bookings;
  perform pg_temp.log(case when n = 0 then 'ok  other owner sees 0 bookings' else 'FAIL other owner sees bookings' end);

  -- ===== reschedule + cancel =====
  perform pg_temp.act(C1);
  j := public.reschedule_booking(bk1, (mon + time '11:00') at time zone 'Africa/Lagos');
  perform pg_temp.log('ok  C1 rescheduled to ' || to_char((j ->> 'appointment_time')::timestamptz at time zone 'Africa/Lagos', 'HH24:MI') || ' with ' || (j ->> 'staff_name'));
  perform pg_temp.act(C3);
  j := public.create_booking(biz, array[hair], t10);
  perform pg_temp.log('ok  freed 10:00 slot now bookable by C3 -> ' || (j ->> 'staff_name'));
  perform pg_temp.act(C1);
  j := public.cancel_booking(bk1, 'changed plans');
  perform pg_temp.log('ok  C1 cancelled: ' || (j ->> 'status') || ', late=' || (j ->> 'is_late_cancellation'));

  -- ===== database-level guard (bypassing functions) =====
  execute 'reset role';
  begin
    insert into public.bookings (reference, customer_id, business_id, staff_id, resource_id, appointment_time, end_time, blocked_until, status)
    values ('TEST-DUP', C3, biz, nneka, nneka, t10, t10 + interval '30 minutes', t10 + interval '30 minutes', 'confirmed');
    perform pg_temp.log('FAIL exclusion constraint allowed overlap');
  exception when exclusion_violation then perform pg_temp.log('ok  database exclusion constraint blocks overlap');
  end;

  -- ===== reviews =====
  update public.bookings set status = 'completed' where customer_id = C2 and business_id = biz and not is_group;
  perform pg_temp.act(C2);
  insert into public.reviews (booking_id, rating, comment)
    select id, 5, 'Great cut' from public.bookings where customer_id = C2 and status = 'completed' limit 1;
  perform pg_temp.act(null);
  select rating_avg || ' (' || rating_count || ')' into x from public.businesses where id = biz;
  perform pg_temp.log('ok  rating after review: ' || x);
  select count(*) into n from public.bookings;
  perform pg_temp.log(case when n = 0 then 'ok  anon sees 0 bookings' else 'FAIL anon sees bookings' end);
  select count(*) into n from public.profiles;
  perform pg_temp.log(case when n = 0 then 'ok  anon sees 0 profiles' else 'FAIL anon sees profiles' end);
  execute 'reset role';
end $$;

select n, msg from t order by n;
rollback;
