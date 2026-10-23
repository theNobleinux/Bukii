-- =============================================================================
-- Phase 5: No-code website generator + public read APIs
-- =============================================================================

-- ---------------------------------------------------------------------------
-- templates: preset designs
-- ---------------------------------------------------------------------------
create table public.templates (
  id                 smallint generated always as identity primary key,
  slug               text not null unique check (slug ~ '^[a-z0-9-]{2,40}$'),
  name               text not null,
  description        text,
  preview_image_url  text,
  palette            jsonb not null,     -- {primary,on_primary,background,surface,text,muted,accent}
  fonts              jsonb not null,     -- {heading, body}  (Google Fonts family names)
  layout             text  not null check (layout in ('classic', 'centered', 'split', 'minimal')),
  sections           jsonb not null default '["hero","about","services","staff","hours","reviews","contact"]'::jsonb,
  is_premium         boolean not null default false,
  is_active          boolean not null default true,
  sort_order         smallint not null default 0,
  created_at         timestamptz not null default now()
);

insert into public.templates (slug, name, description, palette, fonts, layout, sort_order) values
  ('classic', 'Classic', 'Warm and friendly. Bukii orange on soft paper.',
   '{"primary":"#EF4E12","on_primary":"#FFFFFF","background":"#FBF9F6","surface":"#FFFFFF","text":"#25231F","muted":"#77716A","accent":"#F7C9B5"}',
   '{"heading":"Rethink Sans","body":"Rethink Sans"}', 'classic', 1),
  ('noir', 'Noir', 'Dark and premium. Great for barbers and lounges.',
   '{"primary":"#D4AF37","on_primary":"#111111","background":"#111111","surface":"#1C1C1C","text":"#F5F2EA","muted":"#A39E93","accent":"#3A3A3A"}',
   '{"heading":"Playfair Display","body":"Inter"}', 'split', 2),
  ('bloom', 'Bloom', 'Soft and elegant. Made for salons and nail studios.',
   '{"primary":"#C2577A","on_primary":"#FFFFFF","background":"#FFF7F9","surface":"#FFFFFF","text":"#3B2430","muted":"#8C6F7B","accent":"#F6D5DF"}',
   '{"heading":"DM Serif Display","body":"DM Sans"}', 'centered', 3),
  ('fresh', 'Fresh', 'Calm and clean. Suits spas and wellness.',
   '{"primary":"#2F7D6D","on_primary":"#FFFFFF","background":"#F4F8F6","surface":"#FFFFFF","text":"#1E2B28","muted":"#6C7C78","accent":"#CDE6DF"}',
   '{"heading":"Outfit","body":"Outfit"}', 'minimal', 4);

-- ---------------------------------------------------------------------------
-- business_websites: one site per business
-- ---------------------------------------------------------------------------
create or replace function public.is_reserved_slug(p_slug text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select lower(p_slug) = any (array[
    'www','api','app','admin','dashboard','auth','login','signup','book','booking','bookings',
    'bukii','support','help','about','terms','privacy','static','assets','cdn','mail','blog','docs'
  ]);
$$;

create table public.business_websites (
  id                   uuid primary key default gen_random_uuid(),
  business_id          uuid not null unique references public.businesses (id) on delete cascade,
  template_id          smallint not null references public.templates (id),
  slug                 text not null unique
                         check (slug ~ '^[a-z0-9](?:[a-z0-9-]{1,38}[a-z0-9])$' and not public.is_reserved_slug(slug)),
  custom_domain        text unique check (custom_domain is null or custom_domain ~ '^([a-z0-9-]+\.)+[a-z]{2,}$'),
  headline             text check (headline is null or char_length(headline) <= 120),
  tagline              text check (tagline  is null or char_length(tagline)  <= 200),
  about                text check (about    is null or char_length(about)    <= 3000),
  banner_images        text[] not null default '{}' check (cardinality(banner_images) <= 8),
  announcement         text check (announcement is null or char_length(announcement) <= 280),
  announcement_active  boolean not null default false,
  theme_overrides      jsonb not null default '{}'::jsonb,   -- e.g. {"primary":"#123456"}
  social_links         jsonb not null default '{}'::jsonb,   -- {"instagram":"...","tiktok":"...","whatsapp":"..."}
  section_order        jsonb,                                -- overrides template.sections when set
  show_prices          boolean not null default true,
  show_reviews         boolean not null default true,
  show_staff           boolean not null default true,
  is_published         boolean not null default false,
  published_at         timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

comment on column public.business_websites.slug is 'Public address, e.g. bukii.app/fade-lab or fade-lab.bukii.app. Lowercase letters, numbers, dashes.';

create trigger business_websites_set_updated_at
  before update on public.business_websites
  for each row execute function public.set_updated_at();

create or replace function public.business_websites_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.slug := lower(trim(new.slug));
  new.custom_domain := nullif(lower(trim(new.custom_domain)), '');
  if new.is_published and (tg_op = 'INSERT' or not old.is_published) then
    new.published_at := now();
  end if;
  return new;
end;
$$;

create trigger business_websites_before_write
  before insert or update on public.business_websites
  for each row execute function public.business_websites_before_write();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.templates         enable row level security;
alter table public.business_websites enable row level security;

create policy "templates: public read" on public.templates
  for select to anon, authenticated using (is_active);

create policy "websites: public read published" on public.business_websites
  for select to anon, authenticated
  using ((is_published and public.is_business_public(business_id)) or public.is_business_owner(business_id));

create policy "websites: owner insert" on public.business_websites
  for insert to authenticated with check (public.is_business_owner(business_id));

create policy "websites: owner update" on public.business_websites
  for update to authenticated
  using (public.is_business_owner(business_id))
  with check (public.is_business_owner(business_id));

create policy "websites: owner delete" on public.business_websites
  for delete to authenticated using (public.is_business_owner(business_id));

-- ---------------------------------------------------------------------------
-- Slug availability check (for the owner's "choose your link" field)
-- ---------------------------------------------------------------------------
create or replace function public.check_slug_available(p_slug text, p_business_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_slug text := lower(trim(p_slug));
begin
  if v_slug !~ '^[a-z0-9](?:[a-z0-9-]{1,38}[a-z0-9])$' then
    return jsonb_build_object('available', false, 'reason', 'Use 3-40 lowercase letters, numbers or dashes.');
  end if;
  if public.is_reserved_slug(v_slug) then
    return jsonb_build_object('available', false, 'reason', 'This name is reserved.');
  end if;
  if exists (select 1 from public.business_websites w
              where w.slug = v_slug and w.business_id is distinct from p_business_id) then
    return jsonb_build_object('available', false, 'reason', 'This link is already taken.');
  end if;
  return jsonb_build_object('available', true);
end;
$$;

-- ---------------------------------------------------------------------------
-- PUBLIC VIEW: Explore listing (respects RLS of the caller)
-- ---------------------------------------------------------------------------
create view public.business_listings
with (security_invoker = true)
as
select b.id,
       b.name,
       c.slug  as category_slug,
       c.name  as category_name,
       b.description,
       b.logo_url,
       b.cover_url,
       b.area,
       b.city,
       b.address,
       b.latitude,
       b.longitude,
       b.rating_avg,
       b.rating_count,
       b.currency,
       (select min(s.price) from public.services s where s.business_id = b.id and s.is_active) as starting_price,
       (select count(*)     from public.services s where s.business_id = b.id and s.is_active) as service_count,
       w.slug as website_slug,
       b.created_at
  from public.businesses b
  join public.categories c on c.id = b.category_id
  left join public.business_websites w on w.business_id = b.id and w.is_published
 where b.is_published;

-- ---------------------------------------------------------------------------
-- PUBLIC VIEW: website config joined with template (respects RLS)
-- ---------------------------------------------------------------------------
create view public.public_business_pages
with (security_invoker = true)
as
select w.slug,
       w.custom_domain,
       w.business_id,
       b.name          as business_name,
       c.name          as category_name,
       b.description,
       b.logo_url,
       b.cover_url,
       b.phone,
       b.email,
       b.whatsapp,
       b.address,
       b.area,
       b.city,
       b.latitude,
       b.longitude,
       b.timezone,
       b.currency,
       b.rating_avg,
       b.rating_count,
       t.slug          as template_slug,
       t.layout,
       t.palette || w.theme_overrides as palette,
       t.fonts,
       coalesce(w.section_order, t.sections) as sections,
       w.headline,
       w.tagline,
       w.about,
       w.banner_images,
       case when w.announcement_active then w.announcement end as announcement,
       w.social_links,
       w.show_prices,
       w.show_reviews,
       w.show_staff,
       w.published_at
  from public.business_websites w
  join public.businesses b on b.id = w.business_id
  join public.categories c on c.id = b.category_id
  join public.templates  t on t.id = w.template_id
 where w.is_published and b.is_published;

grant select on public.business_listings     to anon, authenticated;
grant select on public.public_business_pages to anon, authenticated;

-- ---------------------------------------------------------------------------
-- PUBLIC RPC: everything a generated website needs, in one call
--   select get_public_site('fade-lab');   or by custom domain
-- ---------------------------------------------------------------------------
create or replace function public.get_public_site(p_slug_or_domain text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_key  text := lower(trim(p_slug_or_domain));
  p      record;
  v_out  jsonb;
begin
  select * into p
    from public.public_business_pages pg
   where pg.slug = v_key or pg.custom_domain = v_key
   limit 1;

  if not found then
    return null;
  end if;

  v_out := to_jsonb(p);

  v_out := v_out || jsonb_build_object(
    'services', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', s.id, 'name', s.name, 'description', s.description,
               'duration_minutes', s.duration_minutes,
               'price', case when p.show_prices then s.price end,
               'max_capacity', s.max_capacity, 'image_url', s.image_url)
             order by s.sort_order, s.name)
        from public.services s
       where s.business_id = p.business_id and s.is_active), '[]'::jsonb),
    'staff', case when p.show_staff then coalesce((
      select jsonb_agg(jsonb_build_object('id', st.id, 'full_name', st.full_name, 'title', st.title, 'avatar_url', st.avatar_url)
             order by st.sort_order, st.full_name)
        from public.staff_members st
       where st.business_id = p.business_id and st.is_active), '[]'::jsonb) else '[]'::jsonb end,
    'hours', coalesce((
      select jsonb_agg(jsonb_build_object(
               'day_of_week', h.day_of_week, 'is_closed', h.is_closed,
               'open_time', h.open_time, 'close_time', h.close_time,
               'break_start', h.break_start, 'break_end', h.break_end)
             order by h.day_of_week)
        from public.business_hours h
       where h.business_id = p.business_id), '[]'::jsonb),
    'reviews', case when p.show_reviews then coalesce((
      select jsonb_agg(r) from (
        select jsonb_build_object('rating', rv.rating, 'comment', rv.comment, 'reviewer_name', rv.reviewer_name,
                                  'owner_reply', rv.owner_reply, 'created_at', rv.created_at) as r
          from public.reviews rv
         where rv.business_id = p.business_id
         order by rv.created_at desc
         limit 10) x), '[]'::jsonb) else '[]'::jsonb end
  );

  return v_out;
end;
$$;

revoke all on function public.get_public_site(text)               from public;
grant execute on function public.get_public_site(text)            to anon, authenticated;
revoke all on function public.check_slug_available(text, uuid)    from public, anon;
grant execute on function public.check_slug_available(text, uuid) to authenticated;
revoke all on function public.business_websites_before_write()    from public, anon, authenticated;
