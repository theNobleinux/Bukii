-- Website generator + public API test. Rolls back.
begin;
create temp table t (n serial, msg text);
grant all on t to anon, authenticated; grant all on sequence t_n_seq to anon, authenticated;

create or replace function pg_temp.act(p_uid uuid) returns void language plpgsql as $$
begin
  execute 'reset role';
  if p_uid is null then
    perform set_config('request.jwt.claims', '{"role":"anon"}', true); execute 'set local role anon';
  else
    perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
  end if;
end $$;
create or replace function pg_temp.log(m text) returns void language sql as $$ insert into t(msg) values (m) $$;

insert into auth.users (id, instance_id, aud, role, phone, raw_user_meta_data, created_at, updated_at) values
 ('00000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-000000000000','authenticated','authenticated','2348090000001','{"role":"business_owner"}',now(),now()),
 ('00000000-0000-0000-0000-00000000000b','00000000-0000-0000-0000-000000000000','authenticated','authenticated','2348090000002','{"role":"business_owner"}',now(),now());

do $$
declare
  O uuid := '00000000-0000-0000-0000-00000000000a';
  O2 uuid := '00000000-0000-0000-0000-00000000000b';
  biz uuid; biz2 uuid; j jsonb; n int;
begin
  perform pg_temp.act(O);
  insert into public.businesses (owner_id, name, category_id, area, is_published) values (O, 'Fade Lab', 1, 'Ikoyi', true) returning id into biz;
  insert into public.services (business_id, name, duration_minutes, price) values (biz, 'Haircut', 30, 12000), (biz, 'Beard trim', 30, 6000);
  insert into public.staff_members (business_id, full_name) values (biz, 'Tunde');

  j := public.check_slug_available('Fade-Lab');
  perform pg_temp.log('ok  slug fade-lab available: ' || (j ->> 'available'));
  j := public.check_slug_available('admin');
  perform pg_temp.log('ok  reserved slug: ' || (j ->> 'reason'));

  insert into public.business_websites (business_id, template_id, slug, headline, announcement, announcement_active, theme_overrides)
  values (biz, (select id from public.templates where slug = 'noir'), 'Fade-Lab', 'Sharp cuts in Ikoyi', '10% off this week', true, '{"primary":"#FF0000"}');

  perform pg_temp.act(null);
  select count(*) into n from public.public_business_pages;
  perform pg_temp.log(case when n = 0 then 'ok  unpublished site hidden from public' else 'FAIL unpublished site visible' end);

  perform pg_temp.act(O2);
  insert into public.businesses (owner_id, name, category_id) values (O2, 'Other', 2) returning id into biz2;
  begin
    insert into public.business_websites (business_id, template_id, slug) values (biz2, 1, 'fade-lab');
    perform pg_temp.log('FAIL duplicate slug accepted');
  exception when unique_violation then perform pg_temp.log('ok  duplicate slug rejected');
  end;
  begin
    insert into public.business_websites (business_id, template_id, slug) values (biz, 1, 'hijack');
    perform pg_temp.log('FAIL other owner created site for my business');
  exception when others then perform pg_temp.log('ok  other owner cannot create site for my business');
  end;
  update public.business_websites set headline = 'hacked' where business_id = biz;
  get diagnostics n = row_count;
  perform pg_temp.log(case when n = 0 then 'ok  other owner cannot edit my site' else 'FAIL other owner edited site' end);

  perform pg_temp.act(O);
  update public.business_websites set is_published = true where business_id = biz;

  perform pg_temp.act(null);
  j := public.get_public_site('fade-lab');
  perform pg_temp.log('ok  public site: ' || (j ->> 'business_name') || ' | template ' || (j ->> 'template_slug')
      || ' | primary ' || (j -> 'palette' ->> 'primary') || ' | services ' || jsonb_array_length(j -> 'services')
      || ' | staff ' || jsonb_array_length(j -> 'staff') || ' | hours ' || jsonb_array_length(j -> 'hours')
      || ' | announcement ' || coalesce(j ->> 'announcement', '-'));
  perform pg_temp.log('ok  public site keys (no owner_id): ' || case when j ? 'owner_id' then 'FAIL leaked owner_id' else 'clean' end);
  select count(*) into n from public.business_listings;
  perform pg_temp.log('ok  explore listing rows for anon: ' || n || ' (expect 1, unpublished Other hidden)');
  perform pg_temp.log('ok  listing starting price + slug: ' || (select starting_price || ' / ' || website_slug from public.business_listings limit 1));
  begin
    perform public.check_slug_available('x-y-z');
    perform pg_temp.log('FAIL anon used slug check');
  exception when others then perform pg_temp.log('ok  slug check needs login');
  end;
  execute 'reset role';
end $$;

select n, msg from t order by n;
rollback;
