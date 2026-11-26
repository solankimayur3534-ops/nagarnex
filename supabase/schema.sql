-- NagarNex Supabase PostgreSQL Schema & Demo Seed Data
-- Run in Supabase SQL Editor. Also create a public storage bucket named `waste-photos`.

-- 1. Waste Reports & Blackspot Clusters
create table if not exists waste_reports (
  id uuid primary key default gen_random_uuid(),
  ward_name text not null,
  place_name text not null,
  lat double precision not null,
  lng double precision not null,
  waste_type text not null,             -- 'Plastic' | 'Wet/Food' | 'Glass' | 'E-Waste' | 'Mixed/Debris'
  severity text not null,               -- 'High' | 'Medium' | 'Low'
  ai_confidence numeric,
  status text default 'open',           -- 'open' | 'pending_verification' | 'verified_cleared'
  report_count int default 1,           -- Incremented on <=150m duplicate merge
  is_recurring boolean default false,   -- True if repeat blackspot (report_count >= 5)
  before_photo_url text not null,
  after_photo_url text,
  verify_votes int default 0,           -- Requires >=3 (or demo threshold) for closure
  sla_deadline timestamptz not null,
  resolved_at timestamptz,
  is_demo boolean default false,
  created_at timestamptz default now()
);

-- 2. Nearby Dry/Wet Waste Collection Centers
create table if not exists collection_centers (
  id uuid primary key default gen_random_uuid(),
  center_name text not null,
  ward_name text not null,
  address text not null,
  accepted_types text[] not null,
  lat double precision not null,
  lng double precision not null,
  is_demo boolean default true
);

-- 3. Community Clean-Up Micro-Drives
create table if not exists micro_drives (
  id uuid primary key default gen_random_uuid(),
  report_id uuid references waste_reports(id) on delete set null,
  title text not null,
  ward_name text not null,
  meeting_point text not null,
  drive_time timestamptz not null,
  rsvp_count int default 1,
  is_demo boolean default false
);

-- 4. Citizen Impact Passport
create table if not exists citizen_profiles (
  id uuid primary key default gen_random_uuid(),
  display_name text not null,
  ward_name text not null,
  verified_fixes int default 0,
  drives_joined int default 0,
  consensus_votes int default 0,
  civic_points int default 0
);

-- Seed Bengaluru Demo Waste Reports (is_demo = true)
insert into waste_reports (ward_name, place_name, lat, lng, waste_type, severity, ai_confidence, status, report_count, is_recurring, before_photo_url, after_photo_url, verify_votes, sla_deadline, resolved_at, is_demo)
values
  ('Ward 150 Bellandur', 'Bellandur Lake Service Road', 12.9304, 77.6784, 'Mixed/Debris', 'High', 0.94, 'verified_cleared', 9, true, 'demo://before/bellandur', 'demo://after/bellandur', 4, now() - interval '12 hours', now() - interval '4 hours', true),
  ('Ward 80 Indiranagar', 'Indiranagar 12th Main Corner', 12.9718, 77.6412, 'Plastic', 'Medium', 0.91, 'verified_cleared', 6, true, 'demo://before/indiranagar', 'demo://after/indiranagar', 3, now() - interval '20 hours', now() - interval '9 hours', true),
  ('Ward 151 Koramangala', 'Koramangala 80ft Road Bus Stop', 12.9352, 77.6245, 'Wet/Food', 'High', 0.96, 'open', 7, true, 'demo://before/koramangala', null, 0, now() + interval '5 hours', null, true),
  ('Ward 84 Whitefield', 'ITPL Main Road Gate 2', 12.9850, 77.7366, 'E-Waste', 'High', 0.89, 'open', 5, true, 'demo://before/whitefield', null, 1, now() + interval '2 hours', null, true),
  ('Ward 174 HSR Layout', 'HSR Sector 2 27th Main', 12.9121, 77.6446, 'Plastic', 'Medium', 0.92, 'pending_verification', 3, false, 'demo://before/hsr', 'demo://after/hsr', 2, now() + interval '11 hours', null, true),
  ('Ward 169 Jayanagar', 'Jayanagar 4th Block Market Edge', 12.9299, 77.5838, 'Wet/Food', 'Low', 0.88, 'verified_cleared', 4, false, 'demo://before/jayanagar', 'demo://after/jayanagar', 3, now() - interval '30 hours', now() - interval '18 hours', true),
  ('Ward 112 Malleswaram', 'Sampige Road 8th Cross', 13.0031, 77.5643, 'Glass', 'Medium', 0.90, 'open', 2, false, 'demo://before/malleswaram', null, 0, now() + interval '18 hours', null, true);

-- Seed Bengaluru Dry/Wet/E-Waste Collection Centers (is_demo = true)
insert into collection_centers (center_name, ward_name, address, accepted_types, lat, lng, is_demo)
values
  ('Bellandur Dry Waste Collection Centre', 'Ward 150 Bellandur', 'Near EcoSpace Gate, Bellandur', array['Dry', 'Plastic', 'E-Waste'], 12.9279, 77.6810, true),
  ('Indiranagar Swachh Kiosk', 'Ward 80 Indiranagar', '100ft Rd, HAL 2nd Stage', array['Dry', 'Wet', 'Glass'], 12.9784, 77.6408, true),
  ('Koramangala Zero-Waste Hub', 'Ward 151 Koramangala', '3rd Block, Near BDA Complex', array['Dry', 'Wet', 'E-Waste'], 12.9310, 77.6288, true),
  ('Whitefield E-Waste & Dry Point', 'Ward 84 Whitefield', 'Pattandur Agrahara Main Rd', array['Dry', 'E-Waste'], 12.9815, 77.7412, true),
  ('Jayanagar Civic Recovery Centre', 'Ward 169 Jayanagar', '9th Main, 4th Block', array['Dry', 'Wet', 'Glass'], 12.9255, 77.5862, true);

-- Seed Community Clean-Up Micro-Drives (is_demo = true)
insert into micro_drives (title, ward_name, meeting_point, drive_time, rsvp_count, is_demo)
values
  ('80ft Road Bus Stop Morning Blitz', 'Ward 151 Koramangala', 'Koramangala 80ft Rd Bus Shelter', now() + interval '1 day', 14, true),
  ('ITPL Gate 2 E-Waste & Litter Sort', 'Ward 84 Whitefield', 'ITPL Main Gate 2 Footpath', now() + interval '1 day 2 hours', 9, true),
  ('Bellandur Lake Buffer Edge Sweep', 'Ward 150 Bellandur', 'Bellandur Lake Service Rd North', now() + interval '2 days', 22, true);

-- Create public storage bucket for Before/After photos
insert into storage.buckets (id, name, public)
values ('waste-photos', 'waste-photos', true)
on conflict (id) do nothing;

do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'Public Access waste-photos'
  ) then
    create policy "Public Access waste-photos" on storage.objects for all using (bucket_id = 'waste-photos') with check (bucket_id = 'waste-photos');
  end if;
end $$;
