# Bukii backend (Supabase)

Project ref: `xzyhartphvcmrrjvball` (region eu-west-1)
App config: `lib/config/supabase_config.dart` (URL + publishable key, safe to ship).
Never put the secret / service_role key in the app.

## Folder

| Path | What |
|---|---|
| `migrations/` | All schema changes, in order. Already applied to the live project. |
| `tests/engine_test.sql` | 30 booking + security checks. Runs in a transaction and rolls back. |
| `tests/website_test.sql` | 11 website generator checks. Rolls back. |

Run a test: paste the file into **Supabase Dashboard → SQL Editor → Run**. Every line should start with `ok`.

## Test logins (no SMS sent, code is always `123456`)

| Phone (type in app) | Role | Notes |
|---|---|---|
| 800 000 0001 | business owner | Owns **Bukii Demo Barbers** (demo data, safe to delete) |
| 800 000 0002 | customer | |
| 800 000 0003 | (new) | Signs up with whichever audience you pick |

Valid until 30 Apr 2027 (Auth → Phone → Test OTPs). Real SMS needs a provider (see bottom).

## Roles

- `profiles.role` is `customer` or `business_owner`, set from the audience picked at sign up
  (`signInWithOtp(data: {'role': 'business_owner'})`).
- Users cannot change their own role. A customer who wants to list a business calls
  `rpc('become_business_owner')`.

## Tables

| Table | Who reads | Who writes |
|---|---|---|
| `profiles` | self; owners see customers who booked them | self (name, avatar, toggles) |
| `categories` | everyone | admin only |
| `businesses` | everyone if `is_published`; owner always; customers who booked it | owner |
| `staff_members` | everyone (active, published business) | owner |
| `services` | everyone (active, published business) | owner |
| `staff_services` | everyone | owner. No rows for a staff member = can do every service |
| `business_hours` | everyone | owner. One row per weekday, 0 = Sunday. Auto-created Mon–Sat 09:00–18:00 |
| `business_closures` | owner | owner. `staff_id` null = whole business closed (holiday) |
| `bookings` + `booking_services` | customer (own), owner (their business) | **RPC only** (below) |
| `reviews` | everyone | customer (own completed booking), owner can set `owner_reply` |
| `saved_businesses` | self | self |
| `templates` | everyone | admin only |
| `business_websites` | everyone if published; owner | owner |

Views (respect RLS): `business_listings` (Explore cards, includes `starting_price`),
`public_business_pages` (website config + template).

## RPCs (call with `supabase.rpc(name, params: {...})`)

| Function | Who | Purpose |
|---|---|---|
| `get_available_slots(p_business_id, p_date 'YYYY-MM-DD', p_service_ids[], p_staff_id?)` | anyone | Free start times. Returns `slot_start`, `slot_end`, `local_time` ("10:30"), `available_staff`, `spots_left` |
| `create_booking(p_business_id, p_service_ids[], p_start, p_staff_id?, p_payment_method?, p_notes?)` | signed in | Books. Locks the business so two people can't take the same slot |
| `reschedule_booking(p_booking_id, p_new_start, p_staff_id?)` | customer / owner | Moves a booking. Customers can't move it inside the cancellation window |
| `cancel_booking(p_booking_id, p_reason?)` | customer / owner | Cancels. Flags `is_late_cancellation` inside the window |
| `update_booking_status(p_booking_id, p_status)` | owner | pending→confirmed, confirmed→completed / no_show, or cancelled |
| `get_business_stats(p_business_id, p_from?, p_to?)` | owner | Revenue (completed + expected), counts by status, today's upcoming |
| `check_slug_available(p_slug, p_business_id?)` | signed in | For the "choose your website link" field |
| `get_public_site(p_slug_or_domain)` | anyone | Everything a generated website needs in one call |
| `become_business_owner()` | signed in | Customer → business owner |

Errors from these functions come back as `PostgrestException` with a readable `message`
and a short `hint` code: `slot_unavailable`, `too_soon`, `too_far`, `outside_hours`,
`customer_overlap`, `group_must_be_alone`, `too_late`, `not_active`, `invalid_transition`.

## Booking rules (per business, editable by owner)

`auto_confirm_bookings` (default true), `slot_interval_minutes` (15),
`min_notice_minutes` (60), `max_advance_days` (60), `cancellation_window_minutes` (120),
`timezone` (Africa/Lagos).

Services: `duration_minutes`, `buffer_minutes` (clean-up time), `price`,
`max_capacity` (>1 = group session, booked on its own).

## Storage

| Bucket | Path | Who uploads |
|---|---|---|
| `avatars` (public, 2 MB, jpg/png/webp) | `<user_id>/<file>` | the user |
| `business-media` (public, 5 MB) | `<business_id>/<file>` | that business's owner |

## Owner screens still to build (frontend)

Everything they need already exists in the backend:
business setup (`businesses` insert), services and staff CRUD, hours and closures,
bookings list (`bookings` select with `booking_services`, `profiles`),
status buttons (`update_booking_status`), dashboard (`get_business_stats`),
website builder (`templates`, `business_websites`, `check_slug_available`).

## Before going live

1. **SMS provider:** Dashboard → Authentication → Sign In / Providers → Phone. Add Termii or Twilio
   credentials. Until then only the test numbers above work.
2. Remove the demo business (owner 800 000 0001) if you don't want it public.
3. Revoke the Claude access token in Supabase Account → Access Tokens when the build is done.
