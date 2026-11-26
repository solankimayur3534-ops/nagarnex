# NagarNex — Bengaluru Public & Municipal Waste Accountability Platform

**NagarNex** is an independent, citizen-verified waste accountability platform for Bengaluru that turns public garbage reports into clustered waste blackspots, GPS-verified before-and-after clearances, community clean-up micro-drives, and a public roadside rectified-solutions leaderboard.

> **Independent Citizen Initiative:** NagarNex is not affiliated with any government or municipal body. All pre-seeded map pins, report counts, and ward scores in Demo Mode are marked with a visible **`DEMO DATA`** badge.

---

## Core Features
1. **15-Second AI Waste Intake (`/intake`):** Upload/capture photo, automatic client-side EXIF metadata stripping, face/number-plate privacy flag & blur toggle, GPS capture (with Bengaluru fallback), and Gemini Vision AI classification (`Plastic`, `Wet/Food`, `Glass`, `E-Waste`, `Mixed/Debris` + `High/Medium/Low` severity).
2. **150m Blackspot Duplicate Clustering:** Haversine distance matching merges duplicate reports within `<= 150m` (matching waste type) into a single blackspot cluster and flags repeat hotspots (`report_count >= 5`).
3. **Live Map & Collection Centers (`/map`):** OpenStreetMap `flutter_map` with filters (`All Spots`, `Repeat Blackspots`, `Verified Cleared`, `Collection Centers`), live SLA countdowns, and action cards.
4. **Before/After Citizen Proof Verification:** Requires an "After" clearance photo within 50m GPS proximity (with a `Demo Mode` GPS override for remote judges) and citizen consensus before transitioning to `Verified Cleared`.
5. **1-Click Community Micro-Drives (`/drives`):** Host or RSVP to community clean-up drives with live RSVP counters and a **Citizen Impact Passport** drawer.
6. **Ward Index (`/ward-index`) & Roadside Digital Board (`/board`):** Ranked Ward Improvement Scores with CSV export, plus a 16:9 public leaderboard of numbered rectified Bengaluru locations and a scannable QR code.

---

## Setup & Run Instructions

### 1. Prerequisites
- Flutter `3.47+` (Web + Android)
- Optional: [Supabase](https://supabase.com/) project + [Gemini API Key](https://ai.google.dev/)

### 2. Database Setup (Optional — Demo Mode works out of the box)
1. Open your Supabase SQL Editor and run [`supabase/schema.sql`](supabase/schema.sql).
2. Create a public Storage bucket named `waste-photos`.

### 3. Run Locally
```bash
flutter pub get
flutter run -d chrome
```

To connect live Supabase & Gemini Vision:
```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=GEMINI_API_KEY=YOUR_GEMINI_KEY
```

### 4. Production Web Build (Vercel / Firebase Hosting)
```bash
flutter build web --release
```
Deploy the generated `build/web` directory to Vercel or Firebase Hosting.

---

## Tech Stack & Disclosures
- **Framework:** Flutter (Web + Android responsive UI)
- **Packages:** `flutter_map`, `latlong2`, `supabase_flutter`, `geolocator`, `image_picker`, `qr_flutter`, `go_router`, `flutter_riverpod`, `http`, `intl`
- **Map Tiles:** OpenStreetMap (`tile.openstreetmap.org`)
- **AI Models:** Google Gemini 2.5 Flash Vision REST API (with deterministic offline fallback)
- **Datasets:** Synthetic Bengaluru ward & blackspot demo seed data (`is_demo = true`)
