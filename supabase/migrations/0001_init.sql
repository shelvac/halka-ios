-- ============================================================================
-- Halka — çekirdek şema (ADR-002)
-- Supabase (PostgreSQL), bölge: EU Central (Frankfurt) — KVKK
-- Tablolar: users, rings_daily, meals, meal_logs, workouts, workout_logs,
--           supplements, blood_tests, dietitians, packages, purchases,
--           diet_programs, reviews, messages
-- Tüm tablolarda Row Level Security AÇIK: sağlık verisi özel nitelikli
-- kişisel veridir; hiçbir satır sahibinden (veya aktif paketi olan
-- diyetisyeninden) başkasına görünmez.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1 · users — auth.users'a 1:1 profil
-- ---------------------------------------------------------------------------
create table public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '',
  role text not null default 'user' check (role in ('user', 'dietitian')),
  birth_date date,
  sex text check (sex in ('female', 'male', 'other')),
  height_cm numeric(5, 1),
  target_weight_kg numeric(5, 2),
  kvkk_accepted_at timestamptz,          -- aydınlatma metni onayı
  health_consent_at timestamptz,         -- sağlık verisi AÇIK RIZA (ayrı onay!)
  created_at timestamptz not null default now()
);

-- Yeni auth kullanıcısı → otomatik profil satırı
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.users (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''));
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- 2 · rings_daily — günlük halka değerleri (Egzersiz/Su/Uyku/Beslenme)
-- ---------------------------------------------------------------------------
create table public.rings_daily (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  day date not null,
  exercise_min integer not null default 0,
  water_ml integer not null default 0,
  sleep_hours numeric(3, 1) not null default 0,
  nutrition_kcal integer not null default 0,
  updated_at timestamptz not null default now(),
  unique (user_id, day)
);

-- ---------------------------------------------------------------------------
-- 3 · meals — planlanan öğünler (haftalık plan; slot 0=Sabah…3=Akşam)
-- ---------------------------------------------------------------------------
create table public.meals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  day date not null,
  slot smallint not null check (slot between 0 and 3),
  meal_time text not null,               -- "09:00"
  title text not null,
  kcal integer not null default 0,
  source text not null default 'plan' check (source in ('plan', 'coach', 'dietitian', 'catalog')),
  unique (user_id, day, slot)
);

-- ---------------------------------------------------------------------------
-- 4 · meal_logs — yenenler (kalori günlüğü; Beslenme halkasının kaynağı)
-- ---------------------------------------------------------------------------
create table public.meal_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  day date not null,
  source text not null check (source in ('plan', 'photo', 'manual')),
  title text not null,
  kcal integer not null,
  photo_path text,                       -- storage: meal-photos bucket
  ai_items jsonb,                        -- Vision AI kalem dökümü
  logged_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 5 · workouts — kullanıcı programları
-- ---------------------------------------------------------------------------
create table public.workouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  name text not null,
  region text not null,
  level text not null,
  items jsonb not null default '[]',     -- [{name, region, reps}]
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 6 · workout_logs — tamamlanan antrenmanlar
-- ---------------------------------------------------------------------------
create table public.workout_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  workout_id uuid references public.workouts (id) on delete set null,
  started_at timestamptz not null,
  duration_min integer not null,
  done_count integer not null default 0,
  total_count integer not null default 0
);

-- ---------------------------------------------------------------------------
-- 7 · supplements — takviye/ilaç + hatırlatıcı
-- ---------------------------------------------------------------------------
create table public.supplements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  name text not null,
  dose text not null default '',
  time_of_day text not null,             -- "09:30"
  notify boolean not null default false,
  taken_dates date[] not null default '{}',  -- uyum yüzdesi buradan hesaplanır
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 8 · blood_tests — tahlil değerleri (PDF ayrıştırma çıktısı)
-- ---------------------------------------------------------------------------
create table public.blood_tests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  taken_at date not null,
  lab text,
  group_name text,                       -- Biyokimya / Hormonlar / Hemogram
  name text not null,
  value numeric not null,
  unit text not null default '',
  ref_low numeric,
  ref_high numeric,
  pdf_path text,                         -- storage: blood-pdfs bucket
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 9 · dietitians — diyetisyen vitrini profili
-- ---------------------------------------------------------------------------
create table public.dietitians (
  id uuid primary key references public.users (id) on delete cascade,
  specialty text not null default '',
  bio text not null default '',
  years_experience integer not null default 0,
  verified boolean not null default false,   -- diploma + oda kaydı manuel onayı
  rating numeric(2, 1) not null default 0,
  review_count integer not null default 0,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 10 · packages — seans paketleri (fiyatlar kuruş cinsinden)
-- ---------------------------------------------------------------------------
create table public.packages (
  id uuid primary key default gen_random_uuid(),
  dietitian_id uuid not null references public.dietitians (id) on delete cascade,
  title text not null default '8 seanslık takip paketi',
  sessions integer not null default 8,
  price_kurus bigint not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 11 · purchases — danışan → paket satın alma (ADR-004: iyzico split)
-- ---------------------------------------------------------------------------
create table public.purchases (
  id uuid primary key default gen_random_uuid(),
  package_id uuid not null references public.packages (id),
  client_id uuid not null references public.users (id) on delete cascade,
  dietitian_id uuid not null references public.dietitians (id),
  price_kurus bigint not null,
  platform_fee_kurus bigint not null,    -- %15 platform komisyonu
  provider text not null check (provider in ('iyzico', 'iap')),
  provider_ref text,                     -- iyzico paymentId / IAP transaction
  status text not null default 'pending'
    check (status in ('pending', 'paid', 'refunded', 'cancelled')),
  sessions_left integer not null,
  purchased_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 12 · diet_programs — diyetisyenin gönderdiği haftalık program
-- ---------------------------------------------------------------------------
create table public.diet_programs (
  id uuid primary key default gen_random_uuid(),
  dietitian_id uuid not null references public.dietitians (id),
  client_id uuid not null references public.users (id) on delete cascade,
  week_start date not null,
  kcal_target integer not null default 1400,
  plan jsonb not null,                   -- 7 gün × 4 öğün [{slot, time, title}]
  allergy_conflicts jsonb not null default '[]',  -- gönderim anındaki uyarılar
  sent_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 13 · reviews — diyetisyen değerlendirmeleri
-- ---------------------------------------------------------------------------
create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  dietitian_id uuid not null references public.dietitians (id) on delete cascade,
  client_id uuid not null references public.users (id) on delete cascade,
  stars smallint not null check (stars between 1 and 5),
  comment text not null default '',
  created_at timestamptz not null default now(),
  unique (dietitian_id, client_id)
);

-- ---------------------------------------------------------------------------
-- 14 · messages — diyetisyen ↔ danışan mesajlaşma (Realtime ile)
-- ---------------------------------------------------------------------------
create table public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.users (id) on delete cascade,
  recipient_id uuid not null references public.users (id) on delete cascade,
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- Row Level Security
-- ============================================================================
alter table public.users enable row level security;
alter table public.rings_daily enable row level security;
alter table public.meals enable row level security;
alter table public.meal_logs enable row level security;
alter table public.workouts enable row level security;
alter table public.workout_logs enable row level security;
alter table public.supplements enable row level security;
alter table public.blood_tests enable row level security;
alter table public.dietitians enable row level security;
alter table public.packages enable row level security;
alter table public.purchases enable row level security;
alter table public.diet_programs enable row level security;
alter table public.reviews enable row level security;
alter table public.messages enable row level security;

-- Yardımcı: bu diyetisyenin, bu danışan için aktif (ödenmiş) paketi var mı?
create or replace function public.dietitian_has_client(dietitian uuid, client uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.purchases p
    where p.dietitian_id = dietitian
      and p.client_id = client
      and p.status = 'paid'
  );
$$;

-- users: herkes kendi profilini okur/günceller; diyetisyen, danışanının profilini okur
create policy users_select_own on public.users
  for select using (id = auth.uid() or public.dietitian_has_client(auth.uid(), id));
create policy users_update_own on public.users
  for update using (id = auth.uid());

-- Sahiplik + diyetisyen-okuma politikaları (sağlık verisi tabloları)
create policy rings_own on public.rings_daily
  for all using (user_id = auth.uid());
create policy rings_dietitian_read on public.rings_daily
  for select using (public.dietitian_has_client(auth.uid(), user_id));

create policy meals_own on public.meals
  for all using (user_id = auth.uid());
create policy meals_dietitian_read on public.meals
  for select using (public.dietitian_has_client(auth.uid(), user_id));

create policy meal_logs_own on public.meal_logs
  for all using (user_id = auth.uid());
create policy meal_logs_dietitian_read on public.meal_logs
  for select using (public.dietitian_has_client(auth.uid(), user_id));

create policy workouts_own on public.workouts
  for all using (user_id = auth.uid());
create policy workout_logs_own on public.workout_logs
  for all using (user_id = auth.uid());

create policy supplements_own on public.supplements
  for all using (user_id = auth.uid());
create policy supplements_dietitian_read on public.supplements
  for select using (public.dietitian_has_client(auth.uid(), user_id));

create policy blood_tests_own on public.blood_tests
  for all using (user_id = auth.uid());
create policy blood_tests_dietitian_read on public.blood_tests
  for select using (public.dietitian_has_client(auth.uid(), user_id));

-- Vitrin: doğrulanmış diyetisyenler ve aktif paketler herkese görünür
create policy dietitians_public_read on public.dietitians
  for select using (verified = true or id = auth.uid());
create policy dietitians_update_own on public.dietitians
  for update using (id = auth.uid());

create policy packages_public_read on public.packages
  for select using (active = true or dietitian_id = auth.uid());
create policy packages_manage_own on public.packages
  for all using (dietitian_id = auth.uid());

-- purchases: taraflar görür; yazma yalnızca service_role (ödeme webhook'u) ile
create policy purchases_parties_read on public.purchases
  for select using (client_id = auth.uid() or dietitian_id = auth.uid());

-- diet_programs: diyetisyen yazar, danışan okur
create policy diet_programs_dietitian_all on public.diet_programs
  for all using (dietitian_id = auth.uid());
create policy diet_programs_client_read on public.diet_programs
  for select using (client_id = auth.uid());

-- reviews: herkes okur, danışan yalnızca paketi olduğu diyetisyene yazar
create policy reviews_public_read on public.reviews
  for select using (true);
create policy reviews_client_insert on public.reviews
  for insert with check (
    client_id = auth.uid()
    and public.dietitian_has_client(dietitian_id, auth.uid())
  );

-- messages: yalnızca gönderen/alıcı
create policy messages_parties_read on public.messages
  for select using (sender_id = auth.uid() or recipient_id = auth.uid());
create policy messages_send on public.messages
  for insert with check (sender_id = auth.uid());

-- ============================================================================
-- Storage bucket'ları (SQL yerine Dashboard → Storage'dan da açılabilir):
--   meal-photos  (private)  — öğün fotoğrafları
--   blood-pdfs   (private)  — tahlil PDF'leri
--   avatars      (public)   — profil fotoğrafları
-- ============================================================================
