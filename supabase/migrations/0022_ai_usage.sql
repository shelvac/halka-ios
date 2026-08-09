-- AI kullanım sayacı (0022).
--
-- Plan üretimi gün başına bir model çağrısı; kota SUNUCUDA sayılmalı —
-- uygulamadaki bir döngü sağlayıcı faturasını patlatamamalı (analyze-meal
-- ile aynı ilke). İçerik LOGLANMIYOR: yalnızca kim, ne türü, ne zaman.

create table if not exists public.ai_usage_log (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  kind       text not null,            -- 'plan_day' | ...
  created_at timestamptz not null default now()
);

create index if not exists ai_usage_log_idx
  on public.ai_usage_log (user_id, kind, created_at desc);

alter table public.ai_usage_log enable row level security;
drop policy if exists ai_usage_own on public.ai_usage_log;
create policy ai_usage_own on public.ai_usage_log
  for select using (auth.uid() = user_id);

create or replace function public.ai_usage_today(p_user uuid, p_kind text)
returns integer
language sql
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.ai_usage_log
  where user_id = p_user
    and kind = p_kind
    and created_at >= (now() at time zone 'Europe/Istanbul')::date;
$$;
