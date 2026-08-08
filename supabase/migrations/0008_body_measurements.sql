-- US-025 — Vücut ölçümleri (akıllı tartı).
--
-- 0001'de yalnızca `blood_tests` vardı; vücut kompozisyonu demo veriden
-- geliyordu. Akıllı tartılar tek tartımda 15+ değer üretiyor (yağ oranı, kas
-- kütlesi, su, kemik, metabolizma…); her tartım bir satır olarak saklanıyor ki
-- ölçümler arası karşılaştırma ("bir öncekine göre −1,05 kg") yapılabilsin.
--
-- Tüm ölçü alanları NULL olabilir: basit bir tartı yalnızca kiloyu verir,
-- eksik alanı sıfır yazmak veriyi bozardı.

create table if not exists public.body_measurements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  measured_at timestamptz not null,

  weight_kg numeric(5, 2),
  bmi numeric(4, 1),
  fat_percent numeric(4, 1),
  fat_mass_kg numeric(5, 2),
  skeletal_muscle_percent numeric(4, 1),
  skeletal_muscle_kg numeric(5, 2),
  muscle_percent numeric(4, 1),
  muscle_mass_kg numeric(5, 2),
  visceral_fat numeric(4, 1),
  water_percent numeric(4, 1),
  water_mass_kg numeric(5, 2),
  bmr_kcal integer,
  obesity_percent numeric(4, 1),
  bone_mass_kg numeric(4, 2),
  protein_percent numeric(4, 1),
  lean_mass_kg numeric(5, 2),
  metabolic_age integer,

  -- 'photo' = tartı ekranının fotoğrafından okundu, 'manual' = elle girildi
  source text not null default 'manual' check (source in ('photo', 'manual')),
  photo_path text,                       -- storage: scale-photos bucket
  created_at timestamptz not null default now(),

  -- Aynı tartım iki kez kaydedilmesin (fotoğraf tekrar yüklenirse).
  unique (user_id, measured_at)
);

create index if not exists body_measurements_user_time
  on public.body_measurements (user_id, measured_at desc);

alter table public.body_measurements enable row level security;

drop policy if exists body_measurements_own on public.body_measurements;
create policy body_measurements_own on public.body_measurements
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Diyetisyen, danışanının ölçümlerini görebilir (0001'deki yardımcı fonksiyon).
-- Fonksiyon İKİ parametre alıyor: (diyetisyen, danışan).
drop policy if exists body_measurements_dietitian_read on public.body_measurements;
create policy body_measurements_dietitian_read on public.body_measurements
  for select to authenticated
  using (public.dietitian_has_client(auth.uid(), user_id));

-- Tartı ekranı fotoğrafları — avatarlarla aynı düzen: ÖZEL bucket, dosya yolu
-- kullanıcının kendi id'siyle başlamak zorunda.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('scale-photos', 'scale-photos', false, 10485760,
        array['image/jpeg', 'image/png', 'image/heic', 'image/webp'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "scale_select_own" on storage.objects;
create policy "scale_select_own" on storage.objects
  for select to authenticated
  using (bucket_id = 'scale-photos'
         and lower((storage.foldername(name))[1]) = lower(auth.uid()::text));

drop policy if exists "scale_insert_own" on storage.objects;
create policy "scale_insert_own" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'scale-photos'
              and lower((storage.foldername(name))[1]) = lower(auth.uid()::text));

drop policy if exists "scale_delete_own" on storage.objects;
create policy "scale_delete_own" on storage.objects
  for delete to authenticated
  using (bucket_id = 'scale-photos'
         and lower((storage.foldername(name))[1]) = lower(auth.uid()::text));
