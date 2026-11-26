# NagarNex — Project Documentation & Technical Disclosure

> **Independent Citizen Initiative:** NagarNex is an independent, citizen-verified waste accountability platform for Bengaluru. It is not affiliated with any government or municipal body.

---

## 1. Problem Statement & Urban Waste Gaps (Bengaluru)
Bengaluru generates approximately **5,880 to 6,500 tonnes per day (TPD)** of municipal solid waste, with an estimated **1,700–1,775 TPD** processing shortfall and **~800–1,100 chronic garbage blackspots** (down from 1,500+ across city zones, with outer East/South-East corridors such as Mahadevapura, Bellandur, and Whitefield experiencing higher repeat dumping).

Existing civic complaint apps suffer from three structural failures:
1. **Passive Ticket Spam:** Multiple citizens reporting the same overflowing bin or roadside dump create duplicate tickets instead of measuring urgency.
2. **Unverified Closures:** Tickets are often marked "Closed" on a status toggle alone without visual proof that the street was actually cleaned.
3. **No Citizen Mobilization Loop:** Chronic blackspots lack a lightweight mechanism for neighbors to organize 45-minute clean-up sprints or see rectified streets celebrated publicly.

---

## 2. Solution & Complete End-to-End User Flow

1. **Landing & Discovery (`/`):**
   - Visitors see NagarNex's 5-step accountability loop, live Bengaluru metrics, and can enter any view with **zero login friction** (a persistent `Citizen Impact Passport` is created automatically via `SharedPreferences` + Supabase `citizen_profiles`).
2. **15-Second AI Waste Intake (`/#/intake`):**
   - Citizen clicks **Click Photo (Camera)** (or **Upload Photo**).
   - Client-side codec (`AiVisionService.stripExifAndCompress`) strips all **EXIF metadata** (GPS headers, camera model, timestamps) and resizes the image to `640px` width (~60% token savings).
   - Citizen drags/zooms in the interactive crop viewport and taps **`Check with AI & Auto-Fill Details`**.
   - Secure backend proxy (`POST /api/vision`) calls **Google Gemini (`gemini-3-flash-preview`)** with `maxOutputTokens: 160` and returns structured JSON: `waste_type`, `severity`, `confidence`, and `contains_faces_or_plates`.
   - If faces or vehicle plates are detected, the **Privacy Blur** guard blocks submission until blurred.
3. **150m Blackspot Duplicate Clustering (`GeoUtils.findMatchingCluster`):**
   - On submit, Haversine distance checks active reports within `<= 150m` with matching `waste_type`.
   - Matching reports **merge** (`report_count + 1`, flagging `is_recurring = true` at `>= 5` reports) instead of creating duplicate pins.
4. **Live Map, Tracking & Municipal Triage (`/#/map` & `/#/ward-index`):**
   - Citizens and ward teams view 150m clusters, SLA countdowns, and Dry/Wet/E-Waste Collection Centers.
   - Citizens tap the **Bell (`🔔`)** or submit a report to receive **Supabase Realtime** status updates inside **My Registered Problem Updates**.
   - Ward teams/NGOs can filter `Action Required` in **Ward Index** and export **Open Data CSV (`CC-BY-4.0`)**.
5. **1-Click Community Clean-Up Micro-Drives (`/#/drives`):**
   - Any overdue or recurring blackspot can launch a **Community Clean-Up Micro-Drive** with date, meeting point, and live `1-Click RSVP` counts.
6. **Before/After Proof Verification & Roadside QR Board (`/#/board`):**
   - Closing a blackspot requires uploading an **"After" photo** within `<= 50m` GPS proximity (with a `Demo Mode` GPS override for remote judges), dual-image **Gemini Vision** comparison (`cleared`, `match_score`), and citizen consensus.
   - Verified spots transition to `Verified Cleared ✓` with `resolved_at` timestamp and appear on the numbered **Public Roadside Rectified Board** with a scannable QR code (`nagarnex.in/#/board`).

---

## 3. Technical Architecture & Security Decisions

* **Frontend / Cross-Platform:** Flutter (`3.47.8`, Web + Android responsive UI), `flutter_riverpod`, `go_router`, `flutter_map` + `latlong2` (OpenStreetMap), `qr_flutter`, `image_picker`, `geolocator`, `shared_preferences`.
* **Backend Database & Storage:** Supabase PostgreSQL (`waste_reports`, `collection_centers`, `micro_drives`, `citizen_profiles`), Supabase Realtime (`postgres_changes`), and Supabase Storage (`waste-photos` public bucket).
* **Secure AI Proxy (`api/vision.js`):** Deployed as a Vercel Serverless Function. `GEMINI_API_KEY` is stored **strictly in server environment variables** (never in client JS or GitHub). Includes per-IP rate limiting (`12 req/min`), daily quota cap (`200 req/day`), duplicate-image client caching, and `1.5 MB` payload cap.
* **SEO & AI-Agent Reachability:** `nagarnex.in` canonical metadata, OpenGraph & Twitter/X cards, JSON-LD `WebApplication` schema, `<noscript>` semantic HTML summary, `robots.txt`, `sitemap.xml`, and `llms.txt`.

---

## 4. Limitations & Future Roadmap

### Current Limitations
* Guest `Citizen Impact Passport` relies on browser `SharedPreferences` + UUID; clearing browser storage resets the local device link unless authenticated.
* In-memory rate limiting in `api/vision.js` resets across serverless cold starts.

### Future Roadmap
1. Optional OTP/phone sign-in for ward marshals and resident welfare associations (RWAs).
2. Automated Ward WhatsApp/SMS digest alerts for overdue `>24h` blackspots.
3. On-device TFLite fallback model for offline rural/peri-urban capture.

---

## 5. Full Disclosure of AI Tools, APIs, Libraries & Datasets
* **AI Vision Model:** Google Gemini (`gemini-3-flash-preview`) via Google AI Studio REST API (`generativelanguage.googleapis.com`).
* **Frameworks & Libraries:** Flutter, Dart, `supabase_flutter`, `flutter_map`, `latlong2`, `flutter_riverpod`, `go_router`, `image_picker`, `geolocator`, `qr_flutter`, `http`, `intl`, `shared_preferences`, `uuid`.
* **Map & Geospatial Data:** OpenStreetMap (`tile.openstreetmap.org`).
* **Seed & Public Reference Data:** Bengaluru municipal solid waste metrics sourced from public BBMP/BSWML reports (2024–2025); pre-seeded Bengaluru ward coordinates and sample pins (`is_demo = true` in `supabase/schema.sql`).
