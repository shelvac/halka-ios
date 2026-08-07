-- US-023 — Adım ve aktif enerjinin geçmişi.
--
-- `rings_daily` yalnızca dört halkayı (egzersiz, su, uyku, beslenme) tutuyordu.
-- Adım ve aktif enerji halka DEĞİL — Apple tempolu yürüyüşü zaten egzersiz
-- dakikası saydığı için adımı halkaya katmıyoruz — ama takvimde geçmişe dönük
-- görünmeleri isteniyor; bu yüzden aynı satırda istatistik olarak saklanıyorlar.

alter table public.rings_daily
  add column if not exists steps integer not null default 0,
  add column if not exists active_energy_kcal integer not null default 0;

comment on column public.rings_daily.steps is
  'Günlük adım (Apple Health). Halka değil, istatistik.';
comment on column public.rings_daily.active_energy_kcal is
  'Günlük aktif enerji (kcal, Apple Health). Halka değil, istatistik.';
