-- Fix: businesses_guard was resetting rating_avg / rating_count even when the
-- system trigger (refresh_business_rating) updated them. Internal updates now
-- set a transaction-local flag that the guard respects.

create or replace function public.businesses_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.jwt() ->> 'role', '') in ('authenticated', 'anon')
     and coalesce(current_setting('bukii.internal', true), '') <> 'on' then
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

create or replace function public.refresh_business_rating()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_business uuid := coalesce(new.business_id, old.business_id);
begin
  perform set_config('bukii.internal', 'on', true);
  update public.businesses b
     set rating_avg   = coalesce((select round(avg(r.rating)::numeric, 1) from public.reviews r where r.business_id = v_business), 0),
         rating_count = (select count(*) from public.reviews r where r.business_id = v_business)
   where b.id = v_business;
  perform set_config('bukii.internal', 'off', true);
  return null;
end;
$$;
