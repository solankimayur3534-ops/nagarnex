# NagarNex — Complete Architecture, End-to-End Flow & Technical Report

> **Independent Citizen Initiative:** NagarNex (`https://nagarnex.vercel.app`) is a citizen-verified waste accountability platform for Bengaluru. It unites AI waste triage, strict Bengaluru geospatial clustering, GPS-matched Before/After clearance proof, community micro-drives, and multi-tier governance.

---

## 1. Problem Statement & Urban Waste Gaps (Bengaluru)
Bengaluru generates approximately **5,880 to 6,500 tonnes per day (TPD)** of municipal solid waste, with recurring roadside garbage blackspots across outer and core wards. Existing civic complaint systems suffer from:
1. **Passive Ticket Spam:** Duplicate reports on the same overflowing spot create redundant tickets instead of measuring urgency.
2. **Unverified Closures:** Tickets are closed on a status toggle alone without GPS-matched visual proof.
3. **Unrelated / Spam Uploads:** Users can submit irrelevant photos without AI relevance filtering.
4. **No Citizen Mobilization Loop:** Chronic blackspots lack 1-click neighborhood clean-up sprints and public street recognition.

---

## 2. Complete End-to-End System Flow

### Step 1: Startup, PWA Fullscreen & Dynamic Permission Gate
- **Landing & Discovery (`/`):** Displays animated `AnimatedLogo`, 3D glassmorphic `LIVE CIVIC PULSE` card, count-up KPI metrics, rotating Live Civic Ticker, and a **4-Step Judge Demo Tour** (`JudgeTourOverlay`).
- **Mobile Fullscreen PWA:** Tapping **Launch App** on mobile triggers Web Fullscreen (`enterFullscreenIfMobile()`), paired with `display: "fullscreen"` in `manifest.json` and `viewport-fit=cover`.
- **Supabase Policy Gate (`PermissionGateDialog`):** On startup (`_loadInitial`), NagarNex fetches `app_settings` from Supabase (`enforce_camera_only`, `enforce_gps_only`).
  - If either policy is `true`, the app checks live browser/device Camera and GPS permissions on every load/refresh and shows a non-dismissible gate until granted.
  - If both are `false`, citizens and judges can explore freely with zero friction.

### Step 2: 15-Second AI Waste Intake (`/#/intake`)
- **Capture & Privacy:** Citizen clicks **Click Photo (Camera)** (or **Upload Photo** unless `enforce_camera_only` is active). `AiVisionService.stripExifAndCompress()` strips all EXIF metadata and resizes to `640px`.
- **Interactive Crop & AI Relevance Guard:** Citizen adjusts the crop viewport and taps **Check with AI & Auto-Fill Details**.
  - `POST /api/vision` calls **Google Gemini (`gemini-2.0-flash`)** and returns structured JSON:
    - `is_waste` (`boolean`) & `rejection_reason` (`string`): Rejects non-waste photos (e.g., landscapes, selfies, unrelated objects) with a red banner and blocks submission.
    - `waste_type`, `severity`, `confidence`, and `contains_faces_or_plates` (triggers mandatory Privacy Blur toggle).
- **Bengaluru-Locked Map & GPS:** `FlutterMap` uses `CameraConstraint.contain(bounds: AppConstants.bengaluruBounds)` (`12.78–13.18, 77.38–77.82`) with Street / Esri Satellite / 3D Camera tilt and Full Map modal.

### Step 3: 150m Spatial Clustering (`GeoUtils.findMatchingCluster`)
- On submission, Haversine distance checks active reports within `<= 150m` and matching `waste_type`.
- Matching reports **merge** (`report_count + 1`, flagging `is_recurring = true` at `>= 5` reports) and award `+15` Civic Points (`+25` for new blackspots).

### Step 4: Live Bengaluru Map & Collection Hubs (`/#/map`)
- Shows live blackspot markers, collection centers (Dry/Wet/E-Waste), blue Current Location GPS marker, **My Location** button, **Full Map** toggle, and 3 **Live Ward Health Cards**.
- Subscribed to **Supabase Realtime** (`postgres_changes` on `waste_reports`).

### Step 5: Query Status & Solved Tracker (`UpdatesSheet`)
- Clicking the **Bell (`🔔`)** icon opens **Query Status & Problem Updates** with:
  - **My Queries** vs. **All City Queries** tabs and instant search by place, ward, or ID.
  - **3-Step Progress Bar** (`1. Reported → 2. Review → 3. Solved ✓`) with clear `SOLVED ✓`, `VERIFYING`, or `OPEN · NOT SOLVED` badges and IST timestamps.

### Step 6: Micro-Drives, Before/After Proof & Roadside QR Board (`/#/drives`, `/#/board`)
- **Micro-Drives (`/#/drives`):** 1-click volunteer RSVP (`+15` Civic Points) and drive creation (`+30` Civic Points).
- **Before/After Proof (`VerifyProofModal`):** Requires `<= 50m` GPS proximity, dual-image AI comparison, and citizen consensus votes (`verifyVotes`).
- **Roadside QR Board (`/#/board`):** Displays numbered cleared Bengaluru streets (Bellandur, Indiranagar, Jayanagar) with Before/After street photos, `AI Match: 96%` badges, and a scannable QR code.

### Step 7: Governance, Admin Hierarchy & Civic Ranks (`PassportDrawer`)
- **6 Citizen Rank Tiers (`RankPassportCard`):** `🌱 Sprout` → `🌿 Sapling` → `🌳 Guardian` → `🏅 Protector` → `⭐ Champion` → `🏆 Legend`.
- **3-Tier Management Hierarchy:** Switchable between `Citizen`, `Municipal Ward Admin (BBMP / ULB)`, and `National Civic Admin (Super Policy)` with live Supabase `app_settings` policy toggles.

---

## 3. Technical Stack, SEO & Verification
- **Frontend:** Flutter Web & Android (`flutter_riverpod`, `go_router`, `flutter_map`, `latlong2`, `qr_flutter`, `image_picker`, `geolocator`, `shared_preferences`, `uuid`).
- **Backend:** Supabase PostgreSQL + Realtime + Storage (`waste-photos`), Vercel Serverless (`api/vision.js` with `12 req/min` IP rate limit & `200 req/day` cap).
- **SEO & Agentic Readiness:** `nagarnex.vercel.app` canonical/OG/Twitter/JSON-LD metadata, `sitemap.xml`, `robots.txt`, `llms.txt`, `/.well-known/ard.json`, `/.well-known/ai-catalog.json`, WebMCP `registerTool`, and `--source-maps`.
- **Automated Verification:** `flutter analyze --no-fatal-infos` (0 issues), `flutter test` (8/8 passing including 375x812 mobile layout test), `flutter build web --release --source-maps` (clean).
