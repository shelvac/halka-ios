-- US-016 — Profil verisinin gerçek olması.
--
-- 0001'de `users` tablosunda doğum tarihi, cinsiyet, boy ve hedef kilo vardı;
-- kişiye özel halka hedefi hesaplayabilmek için iki alan eksikti:
--   · güncel kilo — BMR/TDEE hesabının girdisi (body_metrics zaman serisi ayrı
--     tutuluyor; burada "şu anki" değer, hızlı okuma için)
--   · hareket düzeyi — TDEE çarpanı
-- Ayrıca profilin doldurulup doldurulmadığını tek bakışta anlamak için
-- `profile_completed_at` (US-026 onboarding akışı bunu kullanacak).

alter table public.users
  add column if not exists weight_kg numeric(5, 2),
  add column if not exists activity_level text
    check (activity_level in ('sedentary', 'light', 'moderate', 'active', 'very_active')),
  add column if not exists profile_completed_at timestamptz;

comment on column public.users.weight_kg is
  'Güncel kilo (kg). Zaman serisi body_metrics tablosunda.';
comment on column public.users.activity_level is
  'TDEE çarpanı için hareket düzeyi.';
comment on column public.users.profile_completed_at is
  'Profil adımlarının tamamlandığı an; boşsa onboarding gösterilir.';
