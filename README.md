# VBUS - VIT Bhopal University Bus Tracking System

A Flutter application for managing and tracking university bus transport at VIT Bhopal. The system serves two user roles - passengers (students and faculty) and conductors - with a shared Supabase backend.

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
- [Running the App](#running-the-app)
- [Web Demo (Live Prototype)](#web-demo-live-prototype)
- [Running Tests](#running-tests)
- [Known Limitations](#known-limitations)

---

## Overview

VBUS replaces manual attendance, paper-based seat booking, and informal communication between bus conductors and passengers at VIT Bhopal. The app supports buses running routes across Bhopal, Sehore, and Ashta districts.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| State management | Riverpod 2.x (code generation) |
| Navigation | go_router |
| Backend | Supabase (PostgreSQL, Auth, Realtime, Storage) |
| Maps | Google Maps Flutter + OSRM (free road-following routing) |
| OCR | Google ML Kit Text Recognition |
| Notifications | flutter_local_notifications |
| Authentication | Google OAuth (passengers), username/password (conductors) |

---

## Features

### Passenger Features

**Registration and Approval**
- Sign in with a VIT Bhopal Google account (@vitbhopal.ac.in)
- Complete a registration form with name, institute ID, phone, bus selection, boarding stop, and fee receipt upload
- Accounts remain in a pending state until approved

**Live Bus Tracking**
- Map view showing the full bus route as a road-following polyline sourced from OSRM (no Directions API cost)
- When a trip is active, a live bus marker updates in real time via Supabase Realtime
- When no trip is active, the map shows the static route for reference
- Recenter and zoom controls built into the map
- Custom stop pins: long-press anywhere on the map to drop a named pin with a configurable arrival notification threshold (2, 5, 10, or 15 minutes before the bus arrives)

**Seat Booking**
- Booking window opens at 8:00 PM for the following day's trip
- Bookings can be edited until 7:00 PM on the day of the trip
- Seats are colour-coded: orange for faculty-reserved rows, red for student rows
- Tap a booked seat to see who reserved it
- A daily cron job (pg_cron) purges records older than 7 days while retaining a 7-day history
- History is accessible from the profile screen

**Inbox**
- Broadcast group chat with the entire bus
- Private one-to-one chat with the conductor
- In-app call button for private chats that opens the native dialer
- Info panel showing the other party's name, phone, ID, user type, and boarding stop

**Profile**
- Edit name and phone number
- View and remove custom map pins
- Toggle seat booking reminders and custom pin arrival notifications
- View 7-day seat booking history

---

### Conductor Features

**Attendance**
- Start a trip to automatically generate attendance records for all approved passengers on the bus
- The current stop advances automatically as the conductor's GPS moves within 300 metres of the next stop - no manual button required
- Scan a passenger's VIT ID card using the device camera; the OCR engine extracts the registration number and marks the passenger as present
- Passengers at stops the bus has passed without scanning are marked as missing automatically
- At trip end, remaining waiting passengers are marked as absent
- Filter the list by status (Total, Present, Missed, Absent, Waiting) and search by name
- End the trip manually from the app bar

**Live Map**
- Same road-following polyline as the passenger view
- The conductor's own GPS location is shown as a live bus marker at all times
- Location is broadcast to Supabase only during an active trip so passengers can track the bus
- Recenter and zoom controls built into the map

**Bus Controls**
- Adjust the number of faculty-reserved rows on the left and right sides of the bus from the profile screen
- Changes take effect immediately for all passengers

**Manage Passengers**
- Search and view all approved passengers on the bus
- Remove a passenger from the bus

**Inbox**
- Broadcast group chat with all passengers
- Private one-to-one chats with individual passengers
- Start a new private chat with any approved passenger using the compose button
- In-app call button for private chats

---

### Shared Features

- Real-time messaging using Supabase Realtime with INSERT subscriptions on the messages table
- Messages display sender name, timestamp, and a preview in the inbox
- Local notifications for seat booking reminders and bus proximity alerts
- All data is protected by row-level security policies on Supabase

---

## Project Structure

```
lib/
  app/
    router/           # go_router configuration and redirect logic
  core/
    constants/        # AppConfig (Supabase URL, anon key)
    enums/            # ApprovalStatus, UserRole
    services/         # RouteService (OSRM), NotificationService
    utils/            # EmailUtils
    widgets/          # Shared widgets
  data/
    repositories/     # AuthRepository
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

Row-level security is enabled on all public tables.

---

## Getting Started

**Prerequisites**

- Flutter SDK 3.8.1 or later
- A Supabase project with the schema applied
- A Google Cloud Platform project with Maps SDK for Android and Maps SDK for iOS enabled
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

Add your Google Maps API key in two places:

**Android** -- `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_MAPS_API_KEY"/>
```

**iOS** -- `ios/Runner/AppDelegate.swift`:
```swift
GMSServices.provideAPIKey("YOUR_MAPS_API_KEY")
```

Configure Supabase:
- Enable Email and Google OAuth providers in Authentication settings
- Set Site URL to `com.vitbhopal.vbusf://login-callback`
- Add `com.vitbhopal.vbusf://login-callback` to allowed redirect URLs
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

Running without this flag will cause the app to crash immediately with an assertion error about an empty Supabase URL.

---

## Web Demo (Live Prototype)

A browser build is published so the app can be shown without installing anything:

**Live link:** https://viyxsh.github.io/VBus/

The web build is a **read-only live prototype**. It runs against the real Supabase project but never writes to it — seat bookings, chat messages, custom pins, profile edits, and all conductor trip/attendance actions return a simulated success. This lets a public link be shared safely: visitors can explore every screen without altering real data or affecting one another, and any change a visitor makes resets when the page is reloaded.

### How demo mode works

`AppConfig.demoMode` defaults to **on for web** and **off for mobile** (override with `--dart-define=DEMO_MODE=true|false`). When on:

- Every repository write is intercepted and simulated; nothing reaches the backend.
- Chat messages and custom pins are held in memory for the session so they appear instantly, then clear on reload.
- The seat screen shows pre-filled "taken" seats and the booking window is always open.
- The conductor attendance page shows a generated roster whose states track the live trip's position.
- Map/GPS, notifications, and ML Kit OCR (none of which run on web) are guarded behind `kIsWeb`.

### Demo accounts and seed data

On web the role-selection screen offers one-tap **Enter Demo (Student)** and **Enter Demo (Conductor)** sign-ins (the manual conductor form is hidden). These require:

1. Two Supabase Auth users created in the Dashboard:
   - Student: a student-pattern email, e.g. `demo.23bce10001@vitbhopal.ac.in`
   - Conductor: `conductor_demo@vbus.internal`
2. The SQL scripts in [`supabase/`](supabase/) run once in the Dashboard SQL Editor, in order:
   - `demo_account.sql` — creates the demo student passenger row and assigns a bus
   - `demo_conductor.sql` — points that bus's conductor at the demo Auth user
   - `demo_seed.sql` — starts a self-moving trip via `pg_cron` so the map, timeline, and ETA animate on their own
3. `.env.json` filled with `DEMO_STUDENT_EMAIL` / `DEMO_STUDENT_PASSWORD` and `DEMO_CONDUCTOR_USERNAME` / `DEMO_CONDUCTOR_PASSWORD` matching the Auth users (baked in at build time).

### Building and deploying the web bundle

```bash
flutter build web --release --dart-define-from-file=.env.json --base-href /VBus/
```

The build output in `build/web` is published to the `gh-pages` branch, which GitHub Pages serves. Use `--base-href /VBus/` so asset paths resolve under the project-pages path.

---

## Running Tests

```bash
flutter test
```

The test suite covers:

- Email validation for student, faculty, and conductor formats
- OCR registration number extraction and branch code patterns
- Seat label calculation for different bus layouts
- Booking window open, close, and lock logic including date rollover at 8 PM
- Attendance state machine including scanning, stop advancement, trip end, and stats
- Route structure and coordinate validity

---

## Known Limitations

**Phone calls on simulator** -- The iOS Simulator has no Phone app, so the in-chat call button shows a "not supported" snackbar. It works correctly on physical devices.

**Maps on simulator** -- Google Maps tiles may not render on the iOS Simulator. Everything functions correctly on physical devices and the Android emulator.

**GPS attendance** -- Automatic stop advancement requires a real device GPS signal. On emulators with a mocked location the attendance screen will not advance stops automatically.

**Background notifications** -- Custom pin arrival notifications fire when the app is in the foreground or background but not when it is terminated. Full background delivery would require Firebase Cloud Messaging.

**Multiple buses** -- The configuration and coordinates in this repository cover bus 11 on the Vijay Market to VIT Campus route. Additional buses can be added by inserting rows into the buses, routes, and bus_stops tables with their respective stop coordinates.
