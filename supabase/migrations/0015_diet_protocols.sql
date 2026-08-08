-- Beslenme protokolleri, kullanıcı tercihleri ve üretilen planlar (US-030).
--
-- Plan üretimi bir DİL problemi değil, bir KISIT problemi: 245 yemekten
-- hedef kaloriyi ±%5 tutturan, alerjilere uyan, tekrar etmeyen bir hafta
-- seçmek. Bunu kendi kodumuz yapıyor — deterministik, anında, bedava ve
-- LLM'den güvenilir (hedefi tutturması garanti).
--
-- Kaynaklar sütunda saklanıyor: kullanıcı bir protokolün neye dayandığını
-- görebilmeli. Kanıt düzeyi de öyle — "Dukan" ile "Akdeniz" aynı güvenle
-- sunulamaz.

create table if not exists public.diet_protocols (
  key             text primary key,
  name            text not null,
  summary         text not null,
  -- güçlü | orta | zayıf | gelişmekte
  evidence        text not null,
  evidence_note   text,
  source_url      text,

  -- Makro dağılımı (enerjinin yüzdesi). Protein g/kg verilmişse o öncelikli.
  carb_pct_min    integer, carb_pct_max    integer,
  fat_pct_min     integer, fat_pct_max     integer,
  protein_pct_min integer, protein_pct_max integer,
  protein_g_per_kg numeric(3,1),

  -- `foods.category` değerleriyle eşleşir.
  favor_categories text[] not null default '{}',
  limit_categories text[] not null default '{}',
  avoid_categories text[] not null default '{}',
  -- Yemek etiketleriyle eşleşir (foods.tags).
  avoid_tags       text[] not null default '{}',

  -- Bu bayraklardan biri kullanıcıda varsa protokol HİÇ gösterilmez.
  contraindications text[] not null default '{}',
  -- Gösterilir ama hekim onayı adımı eklenir.
  needs_doctor      boolean not null default false,
  warning           text,

  -- Dukan gibi evreli protokoller için.
  phases          jsonb,
  sort_order      integer not null default 100
);

alter table public.diet_protocols enable row level security;
drop policy if exists diet_protocols_read on public.diet_protocols;
create policy diet_protocols_read on public.diet_protocols
  for select to authenticated using (true);

-- Yemek etiketleri: üreticinin filtreleyebilmesi için.
alter table public.foods add column if not exists tags text[] not null default '{}';

comment on column public.foods.tags is
  'et, kirmizi_et, balik, vejetaryen, vegan, gluten, laktoz, yuksek_seker, alkol';

-- Sihirbazın topladığı tercihler.
create table if not exists public.plan_preferences (
  user_id        uuid primary key references auth.users(id) on delete cascade,
  goal           text not null default 'lose',      -- lose | maintain | gain
  protocol_key   text references public.diet_protocols(key),
  diet_style     text not null default 'omnivore',  -- omnivore | vegetarian | vegan
  allergies      text[] not null default '{}',
  dislikes       text[] not null default '{}',
  meals_per_day  integer not null default 4,
  meal_times     text[] not null default '{"08:30","13:00","16:30","20:00"}',
  eating_out_days integer not null default 0,
  workout_days   integer not null default 3,
  equipment      text not null default 'home',      -- none | home | gym
  injuries       text[] not null default '{}',
  -- Sağlık taraması: gebelik, böbrek, diyabet, yeme bozukluğu geçmişi…
  health_flags   text[] not null default '{}',
  updated_at     timestamptz not null default now()
);

alter table public.plan_preferences enable row level security;
drop policy if exists plan_preferences_own on public.plan_preferences;
create policy plan_preferences_own on public.plan_preferences
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists plan_preferences_dietitian on public.plan_preferences;
create policy plan_preferences_dietitian on public.plan_preferences
  for select using (public.dietitian_has_client(auth.uid(), user_id));

-- Üretilen haftalık planlar.
create table if not exists public.plan_weeks (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  week_start    date not null,
  protocol_key  text,
  kcal_target   integer not null,
  protein_g     integer, carb_g integer, fat_g integer,
  -- 7 gün × öğünler: [{day, meals:[{slot,time,food_id,name,grams,kcal}]}]
  meals         jsonb not null default '[]'::jsonb,
  -- 7 gün: [{day, type, title, minutes, blocks:[…]}]
  workouts      jsonb not null default '[]'::jsonb,
  created_at    timestamptz not null default now(),
  unique (user_id, week_start)
);

create index if not exists plan_weeks_user_idx
  on public.plan_weeks (user_id, week_start desc);

alter table public.plan_weeks enable row level security;
drop policy if exists plan_weeks_own on public.plan_weeks;
create policy plan_weeks_own on public.plan_weeks
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists plan_weeks_dietitian on public.plan_weeks;
create policy plan_weeks_dietitian on public.plan_weeks
  for select using (public.dietitian_has_client(auth.uid(), user_id));
