# Bukii Backend Documentation

The complete reference for the Bukii backend: what exists, how it works, and how
the app talks to it. Read this before building new screens or changing the database.

**Contents**

1. [Overview](#1-overview)
2. [Project setup and access](#2-project-setup-and-access)
3. [How the app connects](#3-how-the-app-connects)
4. [Authentication and roles](#4-authentication-and-roles)
5. [Database tables](#5-database-tables)
6. [Booking engine](#6-booking-engine)
7. [Website generator](#7-website-generator)
8. [API reference (RPC functions)](#8-api-reference-rpc-functions)
9. [Views](#9-views)
10. [Security (Row Level Security)](#10-security-row-level-security)
11. [Storage (images)](#11-storage-images)
12. [Error handling](#12-error-handling)
13. [Testing](#13-testing)
14. [Making database changes](#14-making-database-changes)
15. [Web preview deployment](#15-web-preview-deployment)
16. [Before going live](#16-before-going-live)
17. [What the frontend still needs](#17-what-the-frontend-still-needs)

---

## 1. Overview

| Part | Technology |
|---|---|
| App | Flutter (Android, iOS, Web) |
| Backend | Supabase: PostgreSQL, Auth, Storage, auto REST API |
| Login | Phone number + 6-digit SMS code (OTP) |
| Business logic | PostgreSQL functions (RPCs), so rules can't be bypassed by the app |
| Security | Row Level Security (RLS) on every table |

There is **no separate server**. The app calls Supabase directly. Every rule
(who can see what, double-booking prevention, booking windows) is enforced inside
the database, so a modified or malicious app still cannot break the rules.

### Two user types

| Role | Can do |
|---|---|
| **Customer** | Browse businesses, see free times, book, reschedule, cancel, save businesses, review completed visits |
| **Business owner** | Create businesses, manage services, staff, hours, closures, see their bookings and revenue, confirm / complete bookings, build a website |

### Repo layout (backend-related)

```
supabase/
  migrations/      Database changes, applied in filename order
  tests/           SQL test suites (run in a transaction, leave no data)
  README.md        Short quick reference
docs/
  BACKEND.md       This document
lib/
  config/supabase_config.dart       Project URL + publishable key
  data/backend/bukii_backend.dart   Interface the screens use
  data/backend/supabase_backend.dart Real implementation
  data/backend/demo_backend.dart    In-memory version for widget tests
  data/models/                      ServiceProvider, ServiceOffering, Appointment,
                                    TimeSlot, UserProfile
```

---

## 2. Project setup and access

| Item | Value |
|---|---|
| Supabase project | **Bukii** |
| Project ref | `xzyhartphvcmrrjvball` |
| Region | `eu-west-1` (Ireland) |
| API URL | `https://xzyhartphvcmrrjvball.supabase.co` |
| Publishable key | in `lib/config/supabase_config.dart` |
| Postgres | 17 |

**Keys**

- The **publishable key** (`sb_publishable_...`) is safe inside the app. It only
  allows what RLS allows.
- The **secret key / service_role key** bypasses all security. It must **never**
  go in the app, the repo, or a chat.

---

## 3. How the app connects

`main.dart` starts Supabase and plugs the real backend in:

```dart
await Supabase.initialize(
  url: SupabaseConfig.url,
  publishableKey: SupabaseConfig.publishableKey,
);
BukiiBackend.instance = SupabaseBackend(Supabase.instance.client);
```

Screens never call Supabase directly. They call `BukiiBackend.instance`:

```dart
final providers = await BukiiBackend.instance.fetchProviders();
final slots = await BukiiBackend.instance.availableSlots(
  provider: provider, services: [haircut], date: DateTime(2026, 10, 24),
);
final appointment = await BukiiBackend.instance.createBooking(
  provider: provider, services: [haircut], slot: slots.first,
);
```

### `BukiiBackend` methods

| Method | What it does |
|---|---|
| `isSignedIn` | True if a session is saved on the device |
| `sendOtp(phone, role)` | Sends the SMS code |
| `verifyOtp(phone, code)` | Checks the code, signs in, returns `UserProfile` |
| `currentProfile()` | Signed-in user's profile, or null |
| `updateProfile(fullName, remindersEnabled, whatsappUpdates)` | Saves profile changes |
| `signOut()` | Logs out |
| `fetchProviders()` | Published businesses with their services (Explore) |
| `savedProviders()` / `setSaved(provider, saved:)` | Saved businesses |
| `availableSlots(provider, services, date)` | Free times for a day |
| `createBooking(provider, services, slot, paymentMethod, notes)` | Books |
| `myAppointments()` | Customer's bookings, newest first |
| `cancelBooking(appointment)` | Cancels |
| `rescheduleBooking(appointment, slot)` | Moves to a new time |

All methods throw `BackendException` with a message that is safe to show to the user
(see [Error handling](#12-error-handling)).

### Why there is a `DemoBackend`

Widget tests in `test/` run without internet. They use `DemoBackend`, which keeps
sample data in memory:

```dart
setUp(() => BukiiBackend.instance = DemoBackend());          // signed in
BukiiBackend.instance = DemoBackend(signedIn: false);        // start at welcome flow
```

---

## 4. Authentication and roles

### Sign-in flow

```
Audience screen ("Customer" / "For Business Owners")
   -> Phone screen: sendOtp('+2348012345678', role)
   -> Code screen:  verifyOtp(phone, '123456')
   -> Explore
```

Phone numbers must be in E.164 format: `+234` followed by 10 digits
(the app removes a leading `0` automatically).

### What happens on first sign-up

1. Supabase Auth creates a row in `auth.users`.
2. The trigger `on_auth_user_created` runs `handle_new_user()`, which creates the
   matching `profiles` row.
3. The role comes from the sign-up metadata sent by the app:
   `signInWithOtp(phone: ..., data: {'role': 'business_owner'})`.
   Anything else becomes `customer`.

The metadata is only read the **first** time a phone number signs up. Signing in
again later does not change the role.

### Changing role

- Users **cannot** edit `profiles.role` directly. The database blocks it.
- A customer who wants to list a business calls `become_business_owner()`.

### Phone / email sync

If the phone or email changes in Auth, the trigger `on_auth_user_contact_changed`
copies it to `profiles`. Users cannot edit `profiles.phone` or `profiles.email`
themselves.

### Test numbers (no SMS is sent)

| Type in app | Full number | Code | Role |
|---|---|---|---|
| 800 000 0001 | +2348000000001 | 123456 | business owner (owns **Bukii Demo Barbers**) |
| 800 000 0002 | +2348000000002 | 123456 | customer |
| 800 000 0003 | +2348000000003 | 123456 | new, takes whichever audience you pick |

These are configured in Supabase → Authentication → Phone → Test OTPs and expire on
**30 April 2027**.

### Auth settings

| Setting | Value |
|---|---|
| Phone sign-in | Enabled |
| OTP length | 6 digits |
| OTP expiry | 5 minutes |
| SMS template | `Your Bukii code is {{ .Code }}` |
| SMS provider | **Not configured yet** (see [Before going live](#16-before-going-live)) |

---

## 5. Database tables

All tables live in the `public` schema. `uuid` ids are generated automatically.
`created_at` / `updated_at` are filled automatically.

### Relationship map

```
auth.users 1─1 profiles
profiles   1─* businesses (owner_id)
categories 1─* businesses
businesses 1─* services, staff_members, business_closures, reviews
businesses 1─7 business_hours (one per weekday)
businesses 1─1 business_websites ─* templates
staff_members *─* services  (through staff_services)
profiles   1─* bookings (customer_id)
businesses 1─* bookings
bookings   1─* booking_services
bookings   1─1 reviews
profiles   *─* businesses (through saved_businesses)
```

### `profiles`

One row per user. Created automatically.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | Same as `auth.users.id` |
| `role` | `user_role` | `customer` or `business_owner`. Read-only for users |
| `full_name` | text | 1–120 chars |
| `avatar_url` | text | |
| `phone` | text | E.164, synced from Auth. Read-only |
| `email` | text | Synced from Auth. Read-only |
| `reminders_enabled` | bool | Default true |
| `whatsapp_updates` | bool | Default false |

### `categories`

Fixed list, read-only for users.

| slug | name |
|---|---|
| `barber` | Barber |
| `salon` | Salon |
| `nailtech` | Nailtech |
| `spa` | Spa |
| `makeup` | Makeup |
| `other` | Other |

Columns: `id`, `slug`, `name`, `icon` (Material icon name), `sort_order`, `is_active`.

### `businesses`

| Column | Type | Default | Notes |
|---|---|---|---|
| `owner_id` | uuid | | Must be a `business_owner`. Cannot be changed later |
| `name` | text | | 2–80 chars |
| `category_id` | smallint | | → `categories.id` |
| `description` | text | | Max 2000 |
| `logo_url`, `cover_url` | text | | From the `business-media` bucket |
| `phone`, `email`, `whatsapp` | text | | Public contact info |
| `address`, `area` | text | | `area` = neighbourhood, e.g. Ikoyi, Lekki |
| `city`, `state`, `country` | text | Lagos, Lagos, NG | |
| `latitude`, `longitude` | float | | For future "near me" search |
| `timezone` | text | `Africa/Lagos` | Must be a valid timezone name |
| `currency` | text | `NGN` | |
| `auto_confirm_bookings` | bool | true | false = new bookings start as `pending` |
| `slot_interval_minutes` | smallint | 15 | Gap between offered start times: 5, 10, 15, 20, 30, 45, 60 |
| `min_notice_minutes` | int | 60 | Earliest a customer can book ahead |
| `max_advance_days` | smallint | 60 | Furthest ahead a customer can book |
| `cancellation_window_minutes` | int | 120 | Inside this window: no customer reschedule, cancel is flagged late |
| `is_published` | bool | false | true = visible in Explore and bookable |
| `rating_avg`, `rating_count` | | 0 | Updated automatically from reviews. Read-only |

When a business is created, **business hours are created automatically**:
Monday–Saturday 09:00–18:00, Sunday closed.

### `staff_members`

The people who serve customers. They are **not** app users.

| Column | Notes |
|---|---|
| `business_id` | |
| `full_name` | 1–80 chars |
| `title` | e.g. "Senior barber" |
| `avatar_url` | |
| `is_active` | Inactive staff are hidden and get no bookings |
| `sort_order` | |

If a business has **no active staff**, the business itself is treated as one
person (one booking at a time).

### `services`

| Column | Type | Default | Notes |
|---|---|---|---|
| `business_id` | uuid | | |
| `name` | text | | 1–80 chars |
| `description` | text | | Max 1000 |
| `duration_minutes` | int | | 5–720 |
| `buffer_minutes` | int | 0 | Clean-up time blocked after the service |
| `price` | numeric(12,2) | | Naira |
| `max_capacity` | int | 1 | **1** = one customer at a time. **More than 1** = group session (that many people can book the same start time) |
| `image_url` | text | | |
| `is_active` | bool | true | Inactive services are hidden and can't be booked |
| `sort_order` | smallint | 0 | |

### `staff_services`

Which staff can do which services: `staff_id`, `service_id`.

**Rule:** a staff member with **no rows** here can do **every** service. Add rows only
to restrict someone (e.g. Kemi only does Haircut).

### `business_hours`

One row per weekday.

| Column | Notes |
|---|---|
| `day_of_week` | **0 = Sunday**, 1 = Monday … 6 = Saturday |
| `is_closed` | true = closed all day |
| `open_time`, `close_time` | e.g. `09:00`, `18:00` |
| `break_start`, `break_end` | Optional lunch break, must be inside opening hours |

A missing row means closed.

### `business_closures`

Holidays, one-off closures and staff time off.

| Column | Notes |
|---|---|
| `staff_id` | **null** = whole business closed. **Set** = only that staff member is off |
| `starts_at`, `ends_at` | timestamptz range |
| `reason` | Owner-only note |

Customers never read this table directly. It simply removes times from
`get_available_slots`.

### `bookings`

Create and change **only through the RPC functions** (section 8). Direct
inserts and updates from the app are blocked.

| Column | Notes |
|---|---|
| `reference` | Human code like `BK-7Q2M9X`, unique |
| `customer_id`, `business_id` | |
| `staff_id`, `staff_name` | Assigned staff (name saved for history) |
| `resource_id` | Who is occupied: staff id, or business id if no staff |
| `appointment_time` | Start (timestamptz) |
| `end_time` | Start + total service duration |
| `blocked_until` | End + buffer |
| `status` | `pending`, `confirmed`, `cancelled`, `completed`, `no_show` |
| `total_price`, `currency` | Saved at booking time |
| `payment_method` | `pay_on_arrival`, `cash`, `card`, `transfer` |
| `notes` | Max 500 |
| `is_group`, `group_service_id` | Set for group sessions |
| `is_late_cancellation` | Customer cancelled inside the cancellation window |
| `cancelled_at`, `cancelled_by`, `cancellation_reason` | |
| `completed_at` | |

### `booking_services`

The services inside a booking (one booking can hold several, e.g. Haircut + Beard
trim). Name, duration and price are **copied** at booking time so history stays
correct even if the business later edits the service.

`booking_id`, `service_id`, `service_name`, `duration_minutes`, `price`, `position`.

### `reviews`

| Column | Notes |
|---|---|
| `booking_id` | Unique: one review per booking |
| `business_id`, `customer_id` | Filled automatically from the booking |
| `reviewer_name` | Customer's first name, filled automatically |
| `rating` | 1–5 |
| `comment` | Max 1000 |
| `owner_reply` | Only the business owner can set it |

Only the customer of a **completed** booking can review it. The business's
`rating_avg` and `rating_count` update automatically.

### `saved_businesses`

Customer favourites: `customer_id`, `business_id`.

### `templates`

Website designs. Read-only for users. See [Website generator](#7-website-generator).

### `business_websites`

See [Website generator](#7-website-generator).

---

## 6. Booking engine

### How free times are calculated (`get_available_slots`)

For the chosen date and services:

1. Add up the durations of the selected services. Take the largest buffer.
2. Read that weekday's `business_hours`. Closed → no slots.
3. Walk from opening time to closing time in steps of `slot_interval_minutes`.
4. Drop any start time that:
   - is sooner than `min_notice_minutes` from now,
   - is more than `max_advance_days` ahead,
   - would run past closing time,
   - overlaps the break,
   - overlaps a whole-business closure.
5. For each remaining time, find **staff who are free**:
   - active,
   - qualified for **all** selected services (see `staff_services`),
   - not on time off,
   - no overlapping `pending` / `confirmed` booking (including buffer).
6. Return the time if at least one staff member is free.

Times are calculated in the **business's timezone**, so `local_time` is what the
customer should see.

### How a booking is made (`create_booking`)

1. Checks the user is signed in and the business is published.
2. **Locks the business** for the rest of the transaction. Two people pressing
   "Confirm" at the same moment are handled one after the other.
3. Re-checks everything in step 4 and 5 above.
4. Refuses if the same customer already has an overlapping booking at that
   business.
5. Picks a staff member. If several are free, it picks the one with the fewest
   bookings that day (spreads work evenly).
6. Saves the booking (`confirmed`, or `pending` if the business turned off
   auto-confirm) and its services.

### Double-booking protection (two layers)

1. The business lock inside `create_booking` / `reschedule_booking`.
2. A **database constraint** (`bookings_no_double_booking`): PostgreSQL itself
   refuses two active one-to-one bookings for the same staff member at overlapping
   times, even if someone bypasses the functions.

### Group sessions

A service with `max_capacity > 1` (e.g. a class for 10 people):

- Must be booked **on its own** (not combined with other services).
- Several customers can book the **same start time** until it's full.
- `spots_left` tells you how many seats remain.
- All customers of one session go to the same staff member.

### Booking lifecycle

```
                 auto_confirm = false
create_booking ─────────────────────────> pending
      │                                      │ owner: update_booking_status('confirmed')
      │ auto_confirm = true (default)        v
      └──────────────────────────────────> confirmed ──> completed  (owner, after start time)
                                             │      └──> no_show    (owner, after start time)
           cancel_booking (customer/owner) ──┴──> cancelled
```

### Customer rules

| Action | Allowed when |
|---|---|
| Book | At least `min_notice_minutes` ahead, within `max_advance_days` |
| Reschedule | Before the cancellation window starts (default: more than 2 hours before) |
| Cancel | Any time before the appointment starts. Inside the window it's saved as a **late** cancellation |

Owners can reschedule and cancel their own business's bookings at any time.

---

## 7. Website generator

Every business can publish a simple website built from a template.

### `templates`

| slug | Name | Layout | Style |
|---|---|---|---|
| `classic` | Classic | classic | Bukii orange on soft paper, Rethink Sans |
| `noir` | Noir | split | Dark + gold, Playfair Display / Inter |
| `bloom` | Bloom | centered | Soft pink, DM Serif Display / DM Sans |
| `fresh` | Fresh | minimal | Calm green, Outfit |

Each template has:

- `palette` (JSON): `primary`, `on_primary`, `background`, `surface`, `text`, `muted`, `accent`
- `fonts` (JSON): `heading`, `body` (Google Fonts names)
- `layout`: `classic`, `centered`, `split`, `minimal`
- `sections` (JSON array): default order, e.g.
  `["hero","about","services","staff","hours","reviews","contact"]`

### `business_websites`

One per business.

| Column | Notes |
|---|---|
| `template_id` | Chosen template |
| `slug` | The link: 3–40 chars, lowercase letters, numbers, dashes. Unique. Saved lowercase. Reserved words (`admin`, `api`, `www`, `bukii`, …) are refused |
| `custom_domain` | Optional, e.g. `fadelab.com`. Unique |
| `headline`, `tagline`, `about` | Text |
| `banner_images` | Up to 8 image URLs |
| `announcement`, `announcement_active` | Banner like "10% off this week" |
| `theme_overrides` | JSON merged over the template palette, e.g. `{"primary":"#FF0000"}` |
| `social_links` | JSON, e.g. `{"instagram":"...","tiktok":"..."}` |
| `section_order` | JSON array; overrides the template's order |
| `show_prices`, `show_reviews`, `show_staff` | Toggles |
| `is_published` | Site is public only when this **and** the business are published |
| `published_at` | Set automatically the first time it's published |

### Building the public site

The public web page makes **one call** and gets everything:

```js
const { data } = await supabase.rpc('get_public_site', { p_slug_or_domain: 'fade-lab' })
// data.business_name, data.palette, data.fonts, data.layout, data.sections,
// data.services[], data.staff[], data.hours[], data.reviews[] (latest 10)
```

It returns `null` if the slug doesn't exist or isn't published. It never returns
private data (no owner id, no closure reasons, no customer info).

---

## 8. API reference (RPC functions)

Call from Flutter with `supabase.rpc('name', params: {...})`. Dates are `'YYYY-MM-DD'`.
Timestamps are ISO-8601 strings.

### `get_available_slots`

| Param | Type | Required |
|---|---|---|
| `p_business_id` | uuid | yes |
| `p_date` | date | yes |
| `p_service_ids` | uuid[] | yes |
| `p_staff_id` | uuid | no (only that staff) |

**Who:** anyone, including not signed in.

**Returns** a list of:

| Field | Example |
|---|---|
| `slot_start` | `2026-10-24T09:30:00+00:00` (send this back to book) |
| `slot_end` | `2026-10-24T10:00:00+00:00` |
| `local_time` | `"10:30"` (business timezone, for display) |
| `available_staff` | `[uuid, ...]` (empty if business has no staff list) |
| `spots_left` | group: seats left; otherwise number of free staff |

### `create_booking`

| Param | Type | Required |
|---|---|---|
| `p_business_id` | uuid | yes |
| `p_service_ids` | uuid[] | yes |
| `p_start` | timestamptz | yes (use `slot_start`) |
| `p_staff_id` | uuid | no |
| `p_payment_method` | `pay_on_arrival` / `cash` / `card` / `transfer` | no |
| `p_notes` | text | no |

**Who:** signed in. **Returns** the booking as JSON, including `business` and
`services`.

### `reschedule_booking`

`p_booking_id` (uuid), `p_new_start` (timestamptz), `p_staff_id` (optional).
**Who:** the customer, or the business owner. Tries to keep the same staff
member first. **Returns** the updated booking.

### `cancel_booking`

`p_booking_id` (uuid), `p_reason` (optional text).
**Who:** the customer, or the business owner. **Returns** the updated booking.

### `update_booking_status`

`p_booking_id` (uuid), `p_status` (`confirmed`, `completed`, `no_show`, `cancelled`).
**Who:** business owner only.

| From | To |
|---|---|
| pending | confirmed, cancelled |
| confirmed | completed, no_show (only after start time), cancelled |

### `get_business_stats`

`p_business_id` (uuid), `p_from` (date, default 30 days ago), `p_to` (date, default today).
**Who:** business owner only.

**Returns:**

```json
{
  "from": "2026-09-23", "to": "2026-10-23",
  "revenue_completed": 120000,
  "revenue_expected": 40000,
  "bookings_total": 18, "bookings_pending": 1, "bookings_confirmed": 4,
  "bookings_completed": 11, "bookings_cancelled": 2, "bookings_no_show": 0,
  "unique_customers": 9,
  "today_upcoming": 3
}
```

### `check_slug_available`

`p_slug` (text), `p_business_id` (optional, so a business can keep its own slug).
**Who:** signed in. **Returns** `{"available": true}` or
`{"available": false, "reason": "This link is already taken."}`.

### `get_public_site`

`p_slug_or_domain` (text). **Who:** anyone. See [section 7](#7-website-generator).

### `become_business_owner`

No params. **Who:** signed in. Changes the caller's role to `business_owner`.
**Returns** the updated profile.

---

## 9. Views

Both use the caller's permissions (`security_invoker`), so RLS still applies.

### `business_listings`

For the Explore screen. Only published businesses.

`id, name, category_slug, category_name, description, logo_url, cover_url, area, city,
address, latitude, longitude, rating_avg, rating_count, currency, starting_price,
service_count, website_slug, created_at`

```dart
final rows = await supabase.from('business_listings').select()
    .eq('category_slug', 'barber')
    .order('rating_avg', ascending: false);
```

### `public_business_pages`

Website settings joined with business and template, only when both are published.
Used by `get_public_site`.

---

## 10. Security (Row Level Security)

RLS is **on for every table**. What each user can do:

| Table | Anonymous | Customer | Business owner |
|---|---|---|---|
| `profiles` | – | read / edit own | read / edit own, **read customers who booked them** |
| `categories`, `templates` | read | read | read |
| `businesses` | read published | read published + ones they booked | full control of own |
| `services`, `staff_members`, `business_hours`, `staff_services` | read (published) | read (published) | full control of own |
| `business_closures` | – | – | full control of own |
| `bookings`, `booking_services` | – | read own (write via RPC) | read own business (write via RPC) |
| `reviews` | read (published) | add / edit / delete own | read, reply |
| `saved_businesses` | – | own | own |
| `business_websites` | read published | read published | full control of own |

### Other protections

- Users can't change their own role, phone or email.
- Owners can't move a business to another owner or edit its rating.
- Booking prices, staff and times are decided by the database, not the app.
- Internal helper functions live in a `private` schema that the API does not expose.
- Revenue (`get_business_stats`) is owner-only.

### Supabase Security Advisor

The remaining advisor warnings are intentional: they flag that the public RPCs in
section 8 can be called. Each one checks permissions itself.

---

## 11. Storage (images)

| Bucket | Public | Max size | Types | Upload path | Who can upload |
|---|---|---|---|---|---|
| `avatars` | yes | 2 MB | jpg, png, webp | `<user_id>/<file>` | the user |
| `business-media` | yes | 5 MB | jpg, png, webp | `<business_id>/<file>` | that business's owner |

```dart
final path = '${business.id}/logo.jpg';
await supabase.storage.from('business-media').uploadBinary(path, bytes,
    fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));
final url = supabase.storage.from('business-media').getPublicUrl(path);
await supabase.from('businesses').update({'logo_url': url}).eq('id', business.id);
```

Public buckets serve files by URL. Listing a bucket's contents is not allowed.

---

## 12. Error handling

Database functions raise errors with a **readable message** and a short **code**
(in `hint`). `SupabaseBackend` converts every error into a `BackendException`:

```dart
try {
  await BukiiBackend.instance.createBooking(...);
} on BackendException catch (e) {
  if (e.isSlotTaken) { /* refresh slots */ }
  showSnackBar(e.message);
}
```

| Code | Message (shown to user) |
|---|---|
| `slot_unavailable` | Sorry, that time was just taken. Please pick another slot. |
| `too_soon` | Please choose a later time. |
| `too_far` | That date is too far ahead. |
| `outside_hours` | The business is closed at that time. |
| `customer_overlap` | You already have a booking here at that time. |
| `group_must_be_alone` | Group sessions must be booked on their own. |
| `invalid_service` | One or more services are not available at this business. |
| `duplicate_service` | A service was selected twice. |
| `too_late` | It is too late to reschedule this booking. |
| `not_active` | Only upcoming bookings can be rescheduled. / This booking can no longer be cancelled. |
| `already_started` | This appointment has already started. |
| `invalid_transition` | Cannot change a X booking to Y. |
| `not_started` | This appointment has not started yet. |
| `booking_not_found` / `business_not_found` | Not found (also used when the user has no access) |
| `not_signed_in` | Please sign in to continue. |
| `offline` | No internet connection. |
| `auth` | Wrong / expired code, too many attempts, or SMS failure |

---

## 13. Testing

### SQL test suites

| File | Checks |
|---|---|
| `supabase/tests/engine_test.sql` | 30: roles, business setup, slots, breaks, staff skills, group capacity, race for the same slot, the database constraint, cancel / reschedule, reviews, every visibility rule |
| `supabase/tests/website_test.sql` | 11: slugs, reserved words, ownership, publish rules, public API, no private data leaks |

**How to run:** Supabase Dashboard → **SQL Editor** → paste the file → **Run**.
Every row in the result should start with `ok`. The tests run inside a transaction
and **roll back**, so they leave no data.

### Flutter

```bash
flutter analyze   # expected: No issues found
flutter test      # expected: All tests passed (6)
```

### Manual test with the demo data

1. Open the app, pick **Customer**, sign in with **800 000 0002**, code **123456**.
2. Explore shows **Bukii Demo Barbers**.
3. Pick a service → **Choose a time** → pick a slot → **Confirm booking**.
4. **Bookings** tab: the booking is under Upcoming. Try **Reschedule** and **Cancel**.
5. Sign out, sign in as **800 000 0001** (owner). The owner screens are not built
   yet, but the data is visible in Supabase → Table Editor → `bookings`.

---

## 14. Making database changes

**Never edit tables by hand in the dashboard for real changes.** Add a migration
so the repo always matches the database.

1. Create a new file in `supabase/migrations/` named
   `YYYYMMDDHHMMSS_short_description.sql` (later than the last one).
2. Write the SQL. Include RLS policies for any new table.
3. Apply it: Supabase Dashboard → SQL Editor → paste → Run
   (or `supabase db push` with the Supabase CLI linked to the project).
4. Run both SQL test suites.
5. Commit the file.

### Current migrations

| File | What |
|---|---|
| `20261023100000_profiles_and_roles.sql` | Extensions, `profiles`, roles, auth triggers |
| `20261023110000_businesses_services_hours.sql` | Categories, businesses, staff, services, hours, closures, saved, storage |
| `20261023120000_bookings_engine.sql` | Bookings, slots, booking RPCs, stats, reviews |
| `20261023121000_fix_rating_refresh.sql` | Fix: rating updates after a review |
| `20261023130000_website_generator.sql` | Templates, websites, views, public site RPC |
| `20261023140000_security_hardening.sql` | Private helper schema, merged policies, indexes |

---

## 15. Web preview deployment

A web build of the app is hosted on **GitHub Pages** for quick testing without
installing anything:

**https://thenobleinux.github.io/Bukii/**

It is served from the `gh-pages` branch. To update it after code changes:

```bash
flutter build web --release --base-href /Bukii/
cd build/web
touch .nojekyll
git init -b gh-pages && git add -A && git commit -m "Web build"
git push -f https://github.com/theNobleinux/Bukii gh-pages
```

GitHub publishes the new version within a couple of minutes.

> Chrome may show a "Dangerous site" warning for `thenobleinux.github.io`. This is a
> Safe Browsing flag on the domain, not the app. Report it at
> https://safebrowsing.google.com/safebrowsing/report_error/ or host the preview on
> Vercel instead.

---

## 16. Before going live

1. **SMS provider.** Supabase → Authentication → Sign In / Providers → **Phone** →
   add **Termii** (Nigerian, cheaper) or **Twilio** credentials. Until then only the
   test numbers can sign in.
2. **Remove demo data** if not wanted: delete the business **Bukii Demo Barbers**
   (Table Editor → `businesses`). Its services, staff, hours and website are removed
   with it.
3. **Remove test OTP numbers** (Authentication → Phone → Test OTPs).
4. **Revoke build access tokens** (Supabase → Account → Access Tokens).
5. **Auth URLs.** Set the Site URL in Authentication → URL Configuration when the
   final web domain is known.
6. **Optional:** automatically mark old confirmed bookings as completed with a
   scheduled job (`pg_cron`), if owners don't do it themselves.
7. **Optional:** move the project closer to Nigeria for speed. Region can only be
   chosen when a project is created, so this means a new project + running the
   migrations there.

---

## 17. What the frontend still needs

The backend for all of this already exists. Only screens are missing.

### Business owner app

| Screen | Uses |
|---|---|
| Become an owner / onboarding | `become_business_owner()`, insert into `businesses` |
| Business profile | `businesses` update, `business-media` uploads |
| Services list + editor | `services` insert / update / delete |
| Staff list + editor | `staff_members`, `staff_services` |
| Opening hours | `business_hours` update |
| Holidays / time off | `business_closures` |
| Bookings list | `bookings` select with `booking_services` and `profiles(full_name, phone)` |
| Booking actions | `update_booking_status`, `cancel_booking`, `reschedule_booking` |
| Dashboard | `get_business_stats` |
| Website builder | `templates`, `business_websites`, `check_slug_available`, `get_public_site` for preview |
| Reviews + replies | `reviews` select / update `owner_reply` |

### Customer app (small gaps)

- Leave a review after a completed visit (`reviews` insert).
- Upload a profile photo (`avatars` bucket, then `profiles.avatar_url`).
- Real distance / "near me" (needs device location + `latitude` / `longitude`).
- Route business owners to an owner home screen after sign-in (currently they land
  on the customer screens).
