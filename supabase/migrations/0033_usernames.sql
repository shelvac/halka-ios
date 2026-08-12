-- E7 · Benzersiz kullanıcı adı (0033) — Simge'nin kararı: "Instagram'daki
-- gibi": kayıt sırasında seçilir, alınmışsa anında söylenir, arama
-- kullanıcı adıyla yapılır (ad-soyad araması kaldırıldı).

alter table public.users add column if not exists username text;

-- Benzersizlik büyük/küçük harf duyarsız.
create unique index if not exists users_username_idx
  on public.users (lower(username));

-- Biçim: 3-20 karakter; küçük harf, rakam, nokta, alt çizgi.
create or replace function public.username_valid(p text) returns boolean
language sql immutable as $$
  select lower(trim(p)) ~ '^[a-z0-9._]{3,20}$';
$$;

create or replace function public.username_available(p text) returns boolean
language sql security definer set search_path = public as $$
  select public.username_valid(p)
     and not exists (
       select 1 from public.users
       where lower(username) = lower(trim(p)) and id <> auth.uid());
$$;

create or replace function public.set_username(p text)
returns json language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); normalized text := lower(trim(p));
begin
  if me is null then
    return json_build_object('ok', false, 'err', 'Oturum bulunamadı.');
  end if;
  if not public.username_valid(normalized) then
    return json_build_object('ok', false,
      'err', 'Kullanıcı adı 3-20 karakter olmalı; harf, rakam, nokta ve alt çizgi kullanılabilir.');
  end if;
  begin
    update public.users set username = normalized where id = me;
  exception when unique_violation then
    return json_build_object('ok', false, 'err', 'Bu kullanıcı adı alınmış — başka bir ad dene.');
  end;
  return json_build_object('ok', true, 'username', normalized);
end $$;

-- Arama artık KULLANICI ADIYLA (dönüş tipi değişti: drop + create).
drop function if exists public.search_users(text);
create function public.search_users(p_query text)
returns table (user_id uuid, name text, username text, status text)
language sql security definer set search_path = public as $$
  select u.id,
         coalesce(nullif(u.full_name, ''), 'İsimsiz kullanıcı'),
         u.username,
         case
           when exists (select 1 from public.friendships f
                        where f.user_a = least(auth.uid(), u.id)
                          and f.user_b = greatest(auth.uid(), u.id)) then 'friend'
           when exists (select 1 from public.friend_requests r
                        where r.from_user = auth.uid() and r.to_user = u.id) then 'sent'
           when exists (select 1 from public.friend_requests r
                        where r.from_user = u.id and r.to_user = auth.uid()) then 'incoming'
           else 'none'
         end
  from public.users u
  where u.id <> auth.uid()
    and u.username is not null
    and length(trim(p_query)) >= 3
    and u.username ilike '%' || lower(trim(p_query)) || '%'
  order by u.username
  limit 10;
$$;

-- Özet ve isteklerde kullanıcı adı da görünsün.
drop function if exists public.friend_overview();
create function public.friend_overview()
returns table (
  friend_id uuid, name text, username text, exercise_min integer,
  water_ml integer, steps integer, nutrition_kcal integer, active_today boolean
)
language sql security definer set search_path = public as $$
  select u.id,
         coalesce(nullif(u.full_name, ''), 'Arkadaş'),
         u.username,
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

drop function if exists public.incoming_friend_requests();
create function public.incoming_friend_requests()
returns table (from_id uuid, name text, username text)
language sql security definer set search_path = public as $$
  select r.from_user,
         coalesce(nullif(u.full_name, ''), 'İsimsiz kullanıcı'),
         u.username
  from public.friend_requests r
  join public.users u on u.id = r.from_user
  where r.to_user = auth.uid()
  order by r.created_at desc;
$$;
