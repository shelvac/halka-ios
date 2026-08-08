-- Öğün kaydının kalıcılığı (US-024).
--
-- Sorun: işaretlenen öğünler, fotoğraftan eklenen ekstralar ve menü
-- değişiklikleri yalnızca bellekteydi. Uygulama kapanınca hepsi gidiyordu ve
-- beslenme halkası sıfırlanıyordu — üstelik sıfırlanan halka `rings_daily`ye
-- yazılıp sunucudaki doğru değeri de eziyordu.
--
-- Neden haftalık tek satır: uygulamanın öğün planı haftalık bir ızgara
-- (0=Pazartesi … 6=Pazar). İşaretler güne değil, haftanın gününe bağlı.
-- `week_start` sayesinde geçen haftanın işaretleri bu haftaya sızmaz:
-- hafta değiştiğinde satır bayat sayılır ve temiz başlanır.

create table if not exists public.meal_state (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  week_start date not null,
  eaten      jsonb not null default '[]'::jsonb,   -- ["0-1","2-3"] gün-öğün
  extras     jsonb not null default '[]'::jsonb,   -- [{day,title,kcal,time}]
  overrides  jsonb not null default '{}'::jsonb,   -- {"0-1":"Yulaf"}
  updated_at timestamptz not null default now()
);

comment on table public.meal_state is
  'Haftalık öğün işaretleri ve ekstra öğünler. week_start eskiyse istemci yok sayar.';

alter table public.meal_state enable row level security;

drop policy if exists meal_state_own on public.meal_state;
create policy meal_state_own on public.meal_state
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Diyetisyen, danışanının öğün kaydını görebilir (yazamaz).
drop policy if exists meal_state_dietitian_read on public.meal_state;
create policy meal_state_dietitian_read on public.meal_state
  for select
  using (public.dietitian_has_client(auth.uid(), user_id));
