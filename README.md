# VBUS - VIT Bhopal University Bus Tracking System

A Flutter app for managing and tracking university bus transport at VIT Bhopal. Two user roles: passengers (students and faculty) and conductors, on a shared Supabase backend.

Live Demo: **https://viyxsh.github.io/VBus/**

A read-only browser build. Tap Enter Demo (Student) or Enter Demo (Conductor) to explore every screen. Nothing you do is saved to the backend, and everything resets on reload. See Web Demo (Live Prototype) for details.

---

## Table of Contents

- [Overview](#overview)
- [Tech Stack](#tech-stack)
- [Features](#features)
  - [Passenger Features](#passenger-features)
  - [Conductor Features](#conductor-features)
  - [Shared Features](#shared-features)
- [Project Structure](#project-structure)
- [Database Schema](#database-schema)
- [Getting Started](#getting-started)
- [Environment Setup](#environment-setup)
- [Database Migrations](#database-migrations)
- [Running the App](#running-the-app)
- [Web Demo (Live Prototype)](#web-demo-live-prototype)
- [Running Tests](#running-tests)
- [Known Limitations](#known-limitations)

---

## Overview

VBUS replaces manual attendance, paper seat booking, and ad-hoc WhatsApp groups between bus conductors and passengers at VIT Bhopal. Buses run routes across Bhopal, Sehore, and Ashta districts.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| State management | Riverpod 2.x (code generation) |
| Navigation | go_router |
| Backend | Supabase (PostgreSQL, Auth, Realtime, Storage) |
| Maps | flutter_map (OpenStreetMap tiles) + OSRM (free road-following routing) |
| OCR | Google ML Kit Text Recognition |
| Translation | Google ML Kit On-Device Translation (Hindi/English) |
| Notifications | flutter_local_notifications |
| Authentication | Google OAuth (passengers), username/password (conductors) |

---

## Features

### Passenger Features

**Registration and Approval**
- Sign in with a VIT Bhopal Google account (@vitbhopal.ac.in)
- Complete a registration form with name, institute ID, phone, bus selection, boarding stop, and fee receipt upload
- Accounts stay in a pending state until a conductor approves them

**Live Bus Tracking**
- Map view showing the full bus route as a road-following polyline sourced from OSRM (no Directions API cost)
- When a trip is active, a live bus marker updates in real time via Supabase Realtime
- When no trip is active, the map shows the static route for reference
- Recenter and zoom controls built into the map
- Custom stop pins: long-press anywhere on the map to drop a named pin with an arrival notification threshold (2, 5, 10, or 15 minutes before the bus gets there)

**Seat Booking**
- Booking window opens at 8:00 PM for the following day's trip
- Bookings can be edited until 7:00 PM on the day of the trip
- An edit-confirm flow prevents accidental seat changes: tap Edit, pick a new seat, then Confirm
- Seats are colour-coded: orange for faculty-reserved rows, red for student rows
- Tap a booked seat to see who reserved it
- A legend toggle in the app bar shows or hides the seat colours
- A daily cron job (pg_cron) deletes records older than 7 days, so a 7-day history is kept
- History is available from the profile screen

**Inbox**
- Broadcast group chat with the entire bus
- Private one-to-one chat with the conductor
- Real-time inbox preview updates via Supabase Realtime subscriptions
- Call button for private chats that opens the native dialer
- Info panel showing the other party's name, phone, ID, user type, and boarding stop

**Chat & Translation**
- On-device Hindi-to-English and English-to-Hindi translation using Google ML Kit
- Translation appears inline inside the message bubble, separated by a dotted line
- An arrow button beside each bubble toggles the translation
- Date separators between message groups (Today, Yesterday, weekday, DD/MM/YY), WhatsApp-style
- Inbox timestamps follow the same date format

**Profile**
- Edit name and phone number
- View and remove custom map pins
- Toggle seat booking reminders and custom pin arrival notifications
- View 7-day seat booking history

---

### Conductor Features

**Attendance**
- Start a trip to generate attendance records for all approved passengers on the bus
- The current stop advances automatically when the conductor's GPS comes within 300 metres of the next stop, so there is no button to press
- Scan a passenger's VIT ID card with the device camera; OCR reads the registration number and marks the passenger present
- Passengers at stops the bus has already passed without scanning are marked missing automatically
- At trip end, passengers still waiting are marked absent
- Filter the list by status (Total, Present, Missed, Absent, Waiting) and search by name
- End the trip manually from the app bar

**Live Map**
- Same road-following polyline as the passenger view
- The conductor's own GPS location shows as a live bus marker at all times
- Location is broadcast to Supabase only during an active trip, so passengers can track the bus
- Recenter and zoom controls built into the map

**Bus Controls**
- Change the number of faculty-reserved rows on the left and right sides of the bus from the profile screen
- Changes take effect immediately for all passengers

**Manage Passengers**
- Search and view all approved passengers on the bus
- Remove a passenger from the bus

**Inbox**
- Broadcast group chat with all passengers
- Private one-to-one chats with individual passengers
- Start a new private chat with any approved passenger using the compose button
- Call button for private chats (always visible; shows "Phone number not available" if missing)
- Real-time inbox updates via Supabase Realtime subscriptions

---

### Shared Features

- Real-time messaging using Supabase Realtime with INSERT subscriptions on the messages table
- Messages show sender name, timestamp, and a preview in the inbox
- Local notifications for seat booking reminders and bus proximity alerts
- Conductor write operations (approve, reject, remove, seat management) go through SECURITY DEFINER RPC functions, because RLS alone cannot give conductors rights over passenger rows. Each function verifies the caller against staff_credentials and only touches rows on the caller's own bus.
- Newly approved passengers see only broadcast messages sent after their approval (older messages are hidden)
- Row-level security is enabled on all public tables

---

## Project Structure

```
lib/
  app/
    router/           # go_router configuration and redirect logic
  core/
    constants/        # AppConfig (Supabase URL, anon key)
    enums/            # ApprovalStatus, UserRole
    services/         # RouteService (OSRM), NotificationService, TranslationService
    utils/            # EmailUtils
    widgets/          # Shared widgets
  data/
    repositories/     # AuthRepository, ChatRepository, etc.
  features/
    auth/             # Role selection, registration, pending approval screens
    chat/             # Shared ChatScreen used by both roles
    conductor/
      attendance/     # Trip management, OCR scanning, GPS-based stop tracking
      home/           # Conductor home shell (IndexedStack + NavigationBar)
      inbox/          # Broadcast and private chat list
      profile/        # Edit profile, bus controls, manage passengers
    passenger/
      home/           # Passenger home shell
      inbox/          # Broadcast and private chat list
      profile/        # Edit profile, seat history, custom pins, notifications
      seat_booking/   # Seat map and booking screen
```

---

## Database Schema

| Table | Purpose |
|---|---|
| passengers | Student and faculty accounts with approval status |
| staff_credentials | Conductor accounts linked to Supabase auth |
| buses | Bus configuration including seat counts and reserved rows |
| routes | Named routes per city |
| bus_stops | Stops with coordinates and stop order per route |
| cities | Cities served by the network |
| trips | Active and historical trip records with current stop index |
| attendance | Per-passenger attendance state for each trip |
| bus_locations | Live GPS position of each bus (one row per bus, upserted) |
| seat_bookings | Daily seat reservations with booking date |
| chat_rooms | Broadcast (one per bus) and direct (one per passenger per bus) rooms |
| messages | Chat messages with sender name and type |
| custom_pins | User-defined map pins with notification thresholds |

Row-level security is enabled on all public tables. Conductor write operations go through SECURITY DEFINER RPC functions that check the caller is the assigned conductor before acting.

---

## Getting Started

**Prerequisites**

- Flutter SDK 3.8.1 or later
- A Supabase project with the schema applied
- Google OAuth credentials configured for passenger sign-in
- Android NDK 27.0.12077973
- iOS deployment target 14.0 or later with CocoaPods installed

---

## Environment Setup

Create `.env.json` at the project root (this file is gitignored):

```json
{
  "SUPABASE_URL": "https://your-project.supabase.co",
  "SUPABASE_ANON_KEY": "your-anon-key"
}
```

No maps API key is needed: the map renders OpenStreetMap tiles through flutter_map on every platform.

Configure Supabase:
- Enable Email and Google OAuth providers in Authentication settings
- Set Site URL to `com.vitbhopal.vbusf://login-callback`
- Add `com.vitbhopal.vbusf://login-callback` to allowed redirect URLs
- Apply the versioned schema (see Database Migrations below). The RPC functions are part of the committed migrations, so there is no manual SQL-editor step.
- Schedule the seat booking cleanup job (requires pg_cron enabled):

```sql
select cron.schedule(
  'cleanup-old-seat-bookings',
  '30 14 * * *',
  $$
    delete from public.seat_bookings
    where booking_date < current_date - interval '7 days';
  $$
);
```

---

## Database Migrations

The schema lives in `supabase/migrations/` and is applied with the Supabase CLI:

```bash
supabase login                       # once; token from supabase.com/dashboard/account/tokens
supabase link --project-ref <ref>    # once per checkout
supabase db push                     # applies pending migrations to the linked project
supabase db push --dry-run           # preview first
```

A few rules that keep this working:

- Do not make schema changes in the dashboard SQL editor. Write a new `supabase/migrations/<timestamp>_<name>.sql` file and push it, so the committed history stays the source of truth.
- `supabase/seed.sql` has the reference data (cities, routes, bus stops, buses). `supabase db reset` applies migrations plus the seed locally; it needs Docker.
- `supabase/rpc_functions.sql` is kept for reference only. The live RPC definitions come from the migrations.
- If something does get changed in the dashboard, run `supabase db pull` (also needs Docker) to turn it into a reviewed migration.

---

## Running the App

Always include `--dart-define-from-file` so environment variables are compiled into the binary:

```bash
flutter run --dart-define-from-file=.env.json
```

For release builds:

```bash
flutter build apk --dart-define-from-file=.env.json
flutter build ipa --dart-define-from-file=.env.json
```

Without this flag the app crashes at startup with an assertion about an empty Supabase URL.

---

## Web Demo (Live Prototype)

A browser build is published so people can try the app without installing anything:

**Live link:** https://viyxsh.github.io/VBus/

The web build is a **read-only live prototype**. It runs against the real Supabase project but never writes to it. Seat bookings, chat messages, pins, profile edits, and every conductor trip and attendance action return a simulated success, so the link can be shared without worrying about someone changing real data. Anything a visitor does resets when the page reloads.

### How demo mode works

`AppConfig.demoMode` defaults to **on for web** and **off for mobile** (override with `--dart-define=DEMO_MODE=true|false`). When on:

- Every repository write is intercepted and simulated; nothing reaches the backend.
- Chat messages and custom pins are held in memory for the session, then clear on reload.
- The seat screen shows pre-filled taken seats and the booking window is always open.
- The conductor attendance page shows a generated roster whose states track the live trip's position.
- Map/GPS, notifications, and ML Kit OCR (none of which run on web) are guarded behind `kIsWeb`.

### Demo accounts and seed data

On web the role-selection screen offers one-tap Enter Demo (Student) and Enter Demo (Conductor) sign-ins (the manual conductor form is hidden). Setting these up takes three things:

1. Two Supabase Auth users created in the Dashboard:
   - Student: an address in the student email format; `demo_account.sql` contains the exact one to use
   - Conductor: `conductor_demo@vbus.internal`
2. The one-shot scripts in [`supabase/`](supabase/) run once in the Dashboard SQL Editor, in order:
   - `demo_account.sql` creates the demo student passenger row and assigns a bus
   - `demo_conductor.sql` points that bus's conductor at the demo auth user
   - `demo_seed.sql` starts a self-moving trip via `pg_cron`, so the map, timeline, and ETA animate on their own
   
   The RPC functions are part of the migrations, so they need no manual step.
3. `.env.json` filled with `DEMO_STUDENT_EMAIL` / `DEMO_STUDENT_PASSWORD` and `DEMO_CONDUCTOR_USERNAME` / `DEMO_CONDUCTOR_PASSWORD` matching the auth users (baked in at build time). These have no built-in defaults: if the values are missing, the one-tap demo sign-in buttons stay hidden.

### Building and deploying the web bundle

```bash
flutter build web --release --dart-define-from-file=.env.json --base-href /VBus/
```

The build output in `build/web` goes to the `gh-pages` branch, which GitHub Pages serves. Use `--base-href /VBus/` so asset paths resolve under the project-pages path.

---

## Running Tests

```bash
flutter test
```

The test suite covers:

- Email validation for student, faculty, and conductor formats
- OCR registration number extraction and branch code patterns
- Seat label calculation for different bus layouts
- Booking window open, close, and lock logic, including the date rollover at 8 PM
- The attendance state machine: scanning, stop advancement, trip end, stats, and list ordering
- Polyline decoding and geo distance helpers
- Route structure and coordinate validity

---

## Known Limitations

**Phone calls on simulator**: The iOS Simulator has no Phone app, so the in-chat call button shows a not-supported snackbar. It works on physical devices.

**Maps on simulator**: Map tiles may render slowly on first load while the simulator warms up its network stack. Everything works on physical devices, the Android emulator, and browsers.

**GPS attendance**: Automatic stop advancement needs a real device GPS signal. On emulators with mocked location the attendance screen will not advance stops by itself.

**Background notifications**: Custom pin arrival notifications fire when the app is in the foreground or background, but not when it is terminated. Full background delivery would need Firebase Cloud Messaging.

**Multiple buses**: The seed data covers 10 buses; the app's demo configuration focuses on bus 11 on the Minal route. More buses can be added by inserting rows into the buses, routes, and bus_stops tables.

**Translation model download**: The first translation on each device downloads the Hindi/English language models (a few MB each). Translations after that are instant.
