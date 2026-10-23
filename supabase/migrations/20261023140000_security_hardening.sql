-- =============================================================================
-- Phase 6: Security + performance hardening (from Supabase advisors)
--  1. Move internal RLS helper functions into a non-exposed "private" schema
--     so they can't be called through /rest/v1/rpc.
--  2. Replace overlapping "FOR ALL" policies with one SELECT policy + explicit
--     INSERT / UPDATE / DELETE policies (faster, clearer).
--  3. Index foreign keys.
-- =============================================================================

create schema if not exists private;
grant usage on schema private to anon, authenticated;

-- 1. move helpers (RLS policies reference them by OID, so they keep working)
alter function public.is_business_owner(uuid)   set schema private;
alter function public.is_business_public(uuid)  set schema private;
alter function public.has_booked_business(uuid) set schema private;
alter function public.is_my_customer(uuid)      set schema private;
alter function public.current_user_role()       set schema private;

grant execute on function private.is_business_owner(uuid)   to anon, authenticated;
grant execute on function private.is_business_public(uuid)  to anon, authenticated;
grant execute on function private.has_booked_business(uuid) to authenticated;
grant execute on function private.is_my_customer(uuid)      to authenticated;
grant execute on function private.current_user_role()       to authenticated;

-- Function bodies that call the helpers by name: repoint them to private.*
do $$
declare
  f   record;
  def text;
begin
  for f in
    select p.oid
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.prokind = 'f'
       and pg_get_functiondef(p.oid) ~ 'public\.(is_business_owner|is_business_public|has_booked_business|is_my_customer|current_user_role)\('
  loop
    def := pg_get_functiondef(f.oid);
    def := regexp_replace(def, 'public\.(is_business_owner|is_business_public|has_booked_business|is_my_customer|current_user_role)\(',
                          'private.\1(', 'g');
    execute def;
  end loop;
end $$;

-- Trigger-only functions: nobody needs EXECUTE through the API
revoke all on function public.set_updated_at()                 from public, anon, authenticated;
revoke all on function public.protect_profile_columns()        from public, anon, authenticated;
revoke all on function public.staff_services_same_business()   from public, anon, authenticated;

-- 2. policies --------------------------------------------------------------

-- profiles: one SELECT policy
drop policy "profiles: read own"                on public.profiles;
drop policy "profiles: owners read their customers" on public.profiles;
create policy "profiles: read own or my customers" on public.profiles
  for select to authenticated
  using (id = (select auth.uid()) or private.is_my_customer(id));

-- businesses: one SELECT policy
drop policy "businesses: public read published"                 on public.businesses;
drop policy "businesses: customers read businesses they booked" on public.businesses;
create policy "businesses: read published, own, or booked" on public.businesses
  for select to anon, authenticated
  using (
    is_published
    or owner_id = (select auth.uid())
    or ((select auth.uid()) is not null and private.has_booked_business(id))
  );

-- bookings: one SELECT policy
drop policy "bookings: customer reads own"            on public.bookings;
drop policy "bookings: owner reads business bookings" on public.bookings;
create policy "bookings: customer or business owner reads" on public.bookings
  for select to authenticated
  using (customer_id = (select auth.uid()) or private.is_business_owner(business_id));

-- staff_members
drop policy "staff: owner write" on public.staff_members;
create policy "staff: owner insert" on public.staff_members for insert to authenticated
  with check (private.is_business_owner(business_id));
create policy "staff: owner update" on public.staff_members for update to authenticated
  using (private.is_business_owner(business_id)) with check (private.is_business_owner(business_id));
create policy "staff: owner delete" on public.staff_members for delete to authenticated
  using (private.is_business_owner(business_id));

-- services
drop policy "services: owner write" on public.services;
create policy "services: owner insert" on public.services for insert to authenticated
  with check (private.is_business_owner(business_id));
create policy "services: owner update" on public.services for update to authenticated
  using (private.is_business_owner(business_id)) with check (private.is_business_owner(business_id));
create policy "services: owner delete" on public.services for delete to authenticated
  using (private.is_business_owner(business_id));

-- staff_services
drop policy "staff_services: owner write" on public.staff_services;
create policy "staff_services: owner insert" on public.staff_services for insert to authenticated
  with check (exists (select 1 from public.services s where s.id = service_id and private.is_business_owner(s.business_id)));
create policy "staff_services: owner delete" on public.staff_services for delete to authenticated
  using (exists (select 1 from public.services s where s.id = service_id and private.is_business_owner(s.business_id)));

-- business_hours
drop policy "hours: owner write" on public.business_hours;
create policy "hours: owner insert" on public.business_hours for insert to authenticated
  with check (private.is_business_owner(business_id));
create policy "hours: owner update" on public.business_hours for update to authenticated
  using (private.is_business_owner(business_id)) with check (private.is_business_owner(business_id));
create policy "hours: owner delete" on public.business_hours for delete to authenticated
  using (private.is_business_owner(business_id));

-- 3. indexes ---------------------------------------------------------------
create index if not exists bookings_cancelled_by_idx        on public.bookings (cancelled_by);
create index if not exists bookings_group_service_idx       on public.bookings (group_service_id);
create index if not exists bookings_staff_idx               on public.bookings (staff_id);
create index if not exists business_closures_staff_idx      on public.business_closures (staff_id);
create index if not exists business_websites_template_idx   on public.business_websites (template_id);
create index if not exists reviews_customer_idx             on public.reviews (customer_id);

-- anon evaluates the businesses SELECT policy too; helper returns false without a login
grant execute on function private.has_booked_business(uuid) to anon;
