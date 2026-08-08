-- Yemek veritabanı ve fotoğraf analizi kaydı (US-029).
--
-- Neden kendi tablomuz: AI'ın döndürdüğü kaloriye doğrudan güvenmek
-- tutarsızlık üretir — aynı yemek her çağrıda farklı sayı alabilir.
-- AI yalnızca "ne yendiği" ve "ne kadar" sorusunu cevaplıyor; kalori bu
-- tablodan geliyor. Aynı tablo öğün planını, market listesini ve
-- diyetisyen panelini de besleyecek.

create table if not exists public.foods (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  -- Aramada Türkçe karakter sorunu yaşamamak için sadeleştirilmiş ad
  -- ("Şehriyeli pilav" → "sehriyeli pilav"). lower() yetmiyor: Türkçe'de
  -- "İ" harfi lower() ile "i" + birleşik nokta üretiyor.
  search_key   text not null,
  category     text,
  -- 100 gram başına besin değerleri
  kcal_100g    integer not null,
  protein_100g numeric(5,1),
  carb_100g    numeric(5,1),
  fat_100g     numeric(5,1),
  -- Bir "porsiyon" kaç gram? Porsiyon seçicisinin dayanağı.
  portion_g    integer not null default 100,
  portion_name text not null default 'porsiyon',
  created_at   timestamptz not null default now()
);

create index if not exists foods_search_idx on public.foods (search_key text_pattern_ops);
create unique index if not exists foods_name_idx on public.foods (search_key);

-- Katalog herkese açık okunur, kimse yazamaz (yalnızca service_role).
alter table public.foods enable row level security;
drop policy if exists foods_read_all on public.foods;
create policy foods_read_all on public.foods for select to authenticated using (true);

-- Fotoğraf analizinin kaydı: AI ne dedi, kullanıcı neye çevirdi.
--
-- Fotoğrafın KENDİSİ saklanmıyor (KVKK): arka planda yüz, ev, başka
-- kişiler olabilir. Öğrenme için metin çifti yeterli.
create table if not exists public.meal_photo_log (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  created_at  timestamptz not null default now(),
  provider    text not null,
  model       text not null,
  -- AI'ın ilk tahmini ve kullanıcının kaydettiği son hâli
  ai_items    jsonb not null default '[]'::jsonb,
  final_items jsonb not null default '[]'::jsonb,
  -- Kullanıcı düzeltme yaptı mı? Doğruluk ölçümünün tek kaynağı.
  corrected   boolean not null default false,
  latency_ms  integer
);

create index if not exists meal_photo_log_user_idx
  on public.meal_photo_log (user_id, created_at desc);

alter table public.meal_photo_log enable row level security;
drop policy if exists meal_photo_log_own on public.meal_photo_log;
create policy meal_photo_log_own on public.meal_photo_log
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Günlük kota: ücretsiz katmanda fotoğraf analizi sınırlı. Sunucu tarafında
-- sayılıyor — uygulama ne yaparsa yapsın aşılamaz, hatalı bir döngü
-- sağlayıcı faturasını patlatamaz.
create or replace function public.meal_photo_quota_used(p_user uuid)
returns integer
language sql
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.meal_photo_log
  where user_id = p_user
    and created_at >= (now() at time zone 'Europe/Istanbul')::date;
$$;

comment on function public.meal_photo_quota_used is
  'Kullanıcının bugün kaç fotoğraf analizi yaptığı (Europe/Istanbul günü).';
