-- Koç sohbet geçmişi (0024).
--
-- Sohbet yalnızca bellekte yaşıyordu: uygulama kapanınca koçla yazışmalar
-- ve plan kartları kayboluyordu. Tek satır / kullanıcı; son ~200 mesaj
-- jsonb olarak saklanır. RLS: herkes yalnızca kendi sohbetini okur/yazar.

create table if not exists public.coach_state (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  messages   jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.coach_state enable row level security;

drop policy if exists coach_state_own on public.coach_state;
create policy coach_state_own on public.coach_state
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
