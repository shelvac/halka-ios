-- Egzersiz kütüphanesi (US-031).
--
-- Uygulamada 25 tane elle yazılmış egzersiz vardı (ad · bölge · tekrar).
-- Bölgesel program üretmek için yeterli değil: ekipman, seviye, birincil/
-- ikincil kas, bileşik mi izolasyon mu bilgisi olmadan ACSM hacim kurallarını
-- uygulayamayız.
--
-- Kaynak: free-exercise-db (yuhonas) — 873 egzersiz, KAMU MALI (public
-- domain) lisans, github.com/yuhonas/free-exercise-db. Telifli bir kaynak
-- (ExRx gibi) ticari üründe kullanılamazdı.
--
-- Adlar: Türkiye'de salon dili büyük ölçüde İngilizce (squat, bench press,
-- lat pulldown). Zorla çeviri yapmak yerine özgün ad korunuyor; yaygın
-- Türkçe karşılığı olanlara `name_tr` veriliyor ve arayüz onu tercih ediyor.

create table if not exists public.exercises (
  id            text primary key,          -- kaynak slug
  name          text not null,             -- özgün (İngilizce) ad
  name_tr       text,                      -- yaygın Türkçe karşılığı varsa
  region        text not null,             -- Göğüs, Sırt, Ön Bacak…
  muscles_primary   text[] not null default '{}',
  muscles_secondary text[] not null default '{}',
  equipment     text not null,             -- Barbell, Dumbbell, Ekipmansız…
  -- Üreticinin filtresi: none = ekipmansız, home = ev, gym = salon
  needs         text not null default 'gym',
  level         text not null,             -- Başlangıç | Orta | İleri
  category      text not null,             -- Kuvvet | Esneme | Kardiyo…
  mechanic      text,                      -- compound | isolation
  force         text,                      -- push | pull | static
  images        text[] not null default '{}',
  -- Talimatlar ayrı bir geçişte Türkçeleştirilip eklenecek.
  instructions  text[] not null default '{}'
);

create index if not exists exercises_region_idx on public.exercises (region);
create index if not exists exercises_needs_idx  on public.exercises (needs, level);

alter table public.exercises enable row level security;
drop policy if exists exercises_read on public.exercises;
create policy exercises_read on public.exercises
  for select to authenticated using (true);

comment on table public.exercises is
  'free-exercise-db (kamu malı) kaynaklı egzersiz kütüphanesi.';
