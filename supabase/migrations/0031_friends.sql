-- E7 · Arkadaşlar — gerçek altyapı (0031).
--
-- Eşleşme ARKADAŞ KODUyla: e-postayla arama, kayıtlı adres taramaya
-- (enumeration) açık olurdu; kodunu paylaşan kişi rızasını göstermiş
-- olur ve ekleme anında karşılıklıdır. Arkadaşlar birbirinin yalnızca
-- GÜNLÜK AKTİVİTE ÖZETİNİ görür (egzersiz dk, adım, su, kalori, bugün
-- aktif mi) — öğünler, ölçümler, tahliller asla paylaşılmaz.

alter table public.users add column if not exists friend_code text unique;

-- Karışmayan alfabe (0/O ve 1/I yok) — telefonda okunup yazılası kod.
create or replace function public.gen_friend_code() returns text
language sql volatile as $$
  select string_agg(substr('23456789ABCDEFGHJKMNPQRSTUVWXYZ',
         (floor(random() * 31) + 1)::int, 1), '')
  from generate_series(1, 6);
$$;

-- Mevcut kullanıcılara kod (çakışırsa yeniden denenir).
do $$
declare r record;
begin
  for r in select id from public.users where friend_code is null loop
    loop
      begin
        update public.users set friend_code = public.gen_friend_code()
          where id = r.id;
        exit;
      exception when unique_violation then
        -- yeniden dene
      end;
    end loop;
  end loop;
end $$;

-- Yeni kullanıcı satırına otomatik kod.
create or replace function public.set_friend_code() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.friend_code is null then
    new.friend_code := public.gen_friend_code();
  end if;
  return new;
end $$;

drop trigger if exists users_friend_code on public.users;
create trigger users_friend_code before insert on public.users
  for each row execute function public.set_friend_code();

-- Arkadaşlık: tek satır, kanonik sıra (küçük uuid önce).
create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references public.users(id) on delete cascade,
  user_b uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_a, user_b),
  check (user_a < user_b)
);

alter table public.friendships enable row level security;

drop policy if exists friendships_select on public.friendships;
create policy friendships_select on public.friendships
  for select using (auth.uid() in (user_a, user_b));

drop policy if exists friendships_delete on public.friendships;
create policy friendships_delete on public.friendships
  for delete using (auth.uid() in (user_a, user_b));

-- insert politikası bilinçli olarak YOK: yazma yalnızca add_friend
-- RPC'sinden (security definer) — kod doğrulaması atlanamaz.

create or replace function public.add_friend(p_code text)
returns json language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  target record;
begin
  if me is null then
    return json_build_object('ok', false, 'err', 'Oturum bulunamadı.');
  end if;
  select id, full_name into target from public.users
    where upper(friend_code) = upper(trim(p_code));
  if target.id is null then
    return json_build_object('ok', false, 'err', 'Bu koda sahip bir kullanıcı bulunamadı.');
  end if;
  if target.id = me then
    return json_build_object('ok', false, 'err', 'Bu senin kendi kodun.');
  end if;
  insert into public.friendships (user_a, user_b)
    values (least(me, target.id), greatest(me, target.id))
    on conflict (user_a, user_b) do nothing;
  return json_build_object('ok', true,
    'name', coalesce(nullif(target.full_name, ''), 'Arkadaşın'));
end $$;

create or replace function public.remove_friend(p_friend uuid)
returns void language sql security definer set search_path = public as $$
  delete from public.friendships
  where user_a = least(auth.uid(), p_friend)
    and user_b = greatest(auth.uid(), p_friend);
$$;

-- Arkadaş özeti: ad + bugünün aktivitesi. security definer yalnızca bu
-- alanları döner — başka hiçbir veri sızmaz.
create or replace function public.friend_overview()
returns table (
  friend_id uuid,
  name text,
  exercise_min integer,
  water_ml integer,
  steps integer,
  nutrition_kcal integer,
  active_today boolean
)
language sql security definer set search_path = public as $$
  select u.id,
         coalesce(nullif(u.full_name, ''), 'Arkadaş'),
         coalesce(r.exercise_min, 0),
         coalesce(r.water_ml, 0),
         coalesce(r.steps, 0),
         coalesce(r.nutrition_kcal, 0),
         coalesce(r.visited, false)
  from public.friendships f
  join public.users u
    on u.id = case when f.user_a = auth.uid() then f.user_b else f.user_a end
  left join public.rings_daily r
    on r.user_id = u.id
   and r.day = (now() at time zone 'Europe/Istanbul')::date
  where auth.uid() in (f.user_a, f.user_b)
  order by 2;
$$;
