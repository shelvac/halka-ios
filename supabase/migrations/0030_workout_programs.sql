-- Kullanıcı antrenman programları (0030) — E4'ün son parçası.
--
-- "Programlarım" demo veriyle doluydu ve bellekteydi: herkes aynı sahte
-- programları görüyor, kurulan program uygulama kapanınca kayboluyordu.
-- Artık kullanıcı başına kalıcı; RLS ile yalnızca sahibi görür.

create table if not exists public.workout_programs (
  id         uuid primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  name       text not null,
  region     text not null default '',
  level      text not null default '',
  -- [{name, region, reps}]
  items      jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists workout_programs_user_idx
  on public.workout_programs (user_id, created_at);

alter table public.workout_programs enable row level security;

drop policy if exists workout_programs_own on public.workout_programs;
create policy workout_programs_own on public.workout_programs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
