-- 0034 · Halka puanı liderlik tablosu + davetli challenge'lar (E7 genişlemesi)
--
-- Puanlama felsefesi: mutlak değer değil, KENDİ hedefine uyum yüzdesi —
-- hedefler kişiye özel olduğu için (30-75 dk egzersiz gibi) herkes aynı
-- ligde adil yarışır. Hedefler istemcide türetildiğinden puanı istemci
-- hesaplar (0-110) ve rings_daily.score olarak yazar; sunucu yalnızca
-- toplar. Liderlik tablosu aylık sıfırlanır.
--
-- Challenge: davetli ve rızalı — arkadaş isteğiyle aynı ilke, kimse
-- istemeden yarışa sokulmaz. İlerleme rings_daily'den TÜRETİLİR, ayrıca
-- veri kopyalanmaz; katılan, diğer katılımcıların yalnızca "gün hedefini
-- kaç gün tutturduğunu" görür (zaten paylaşılan günlük özetin alt kümesi).

alter table public.rings_daily
  add column if not exists score integer not null default 0;

-- ---------------------------------------------------------------------------
-- Aylık liderlik: ben + arkadaşlarım. Seri = bugünden (bugün açılmadıysa
-- dünden) geriye kesintisiz "visited" gün sayısı.
create or replace function public.friend_leaderboard()
returns table (
  user_id uuid, name text, username text,
  points integer, streak integer, is_me boolean
)
language sql security definer set search_path = public as $$
  with me as (select auth.uid() as uid),
  today as (select (now() at time zone 'Europe/Istanbul')::date as d),
  circle as (
    select uid as id from me
    union
    select case when f.user_a = (select uid from me) then f.user_b else f.user_a end
    from friendships f
    where (select uid from me) in (f.user_a, f.user_b)
  ),
  anchor as (
    select c.id,
           case
             when exists (select 1 from rings_daily r where r.user_id = c.id
                            and r.visited and r.day = (select d from today))
               then (select d from today)
             when exists (select 1 from rings_daily r where r.user_id = c.id
                            and r.visited and r.day = (select d from today) - 1)
               then (select d from today) - 1
             else null
           end as a
    from circle c
  )
  select u.id,
         coalesce(nullif(u.full_name, ''), 'Arkadaş'),
         u.username,
         coalesce((select sum(r.score)::int from rings_daily r
                   where r.user_id = u.id
                     and r.day >= date_trunc('month', (select d from today))::date
                     and r.day <= (select d from today)), 0),
         case when an.a is null then 0
              else (select coalesce(min(g), 366)::int
                    from generate_series(0, 365) g
                    where not exists (select 1 from rings_daily r
                                      where r.user_id = u.id and r.visited
                                        and r.day = an.a - g))
         end,
         u.id = (select uid from me)
  from users u
  join circle c on c.id = u.id
  join anchor an on an.id = u.id
  order by 4 desc, 2;
$$;

-- ---------------------------------------------------------------------------
-- Challenge tabloları. Yazma yalnızca aşağıdaki RPC'lerle (insert/update
-- policy YOK); okuma üyelere açık.
create table if not exists public.challenges (
  id uuid primary key default gen_random_uuid(),
  creator uuid not null references public.users(id) on delete cascade,
  kind text not null check (kind in ('su', 'adim', 'egzersiz')),
  daily_target integer not null check (daily_target between 1 and 100000),
  start_day date not null,
  end_day date not null,
  title text not null,
  created_at timestamptz not null default now(),
  check (end_day >= start_day and end_day <= start_day + 30)
);

create table if not exists public.challenge_members (
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  status text not null default 'davetli'
    check (status in ('davetli', 'katildi', 'reddetti')),
  primary key (challenge_id, user_id)
);

alter table public.challenges enable row level security;
alter table public.challenge_members enable row level security;

-- Üyelik kontrolü: policy içinde challenge_members'a doğrudan bakmak RLS
-- özyinelemesine düşer; definer fonksiyon (tablo sahibi) RLS'i atlar.
create or replace function public.is_challenge_member(cid uuid)
returns boolean
language sql security definer set search_path = public as $$
  select exists (select 1 from challenge_members
                 where challenge_id = cid and user_id = auth.uid());
$$;

drop policy if exists challenges_select on public.challenges;
create policy challenges_select on public.challenges
  for select using (public.is_challenge_member(id));

drop policy if exists challenge_members_select on public.challenge_members;
create policy challenge_members_select on public.challenge_members
  for select using (public.is_challenge_member(challenge_id));

-- ---------------------------------------------------------------------------
-- Challenge kur: bugün başlar, yalnızca ARKADAŞLAR davet edilebilir,
-- kişi başı aynı anda en fazla 3 aktif katılım.
create or replace function public.create_challenge(
  p_kind text, p_target integer, p_days integer,
  p_title text, p_invitees uuid[]
)
returns json
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  d date := (now() at time zone 'Europe/Istanbul')::date;
  cid uuid;
  bad integer;
  active integer;
begin
  if uid is null then
    return json_build_object('ok', false, 'err', 'Oturum bulunamadı.');
  end if;
  if p_kind not in ('su', 'adim', 'egzersiz') then
    return json_build_object('ok', false, 'err', 'Geçersiz challenge türü.');
  end if;
  if p_target is null or p_target < 1 or p_target > 100000 then
    return json_build_object('ok', false, 'err', 'Geçersiz günlük hedef.');
  end if;
  if p_days is null or p_days < 3 or p_days > 30 then
    return json_build_object('ok', false, 'err', 'Süre 3-30 gün olmalı.');
  end if;
  if p_title is null or length(trim(p_title)) < 3 or length(p_title) > 60 then
    return json_build_object('ok', false, 'err', 'Geçersiz başlık.');
  end if;
  if p_invitees is null or array_length(p_invitees, 1) is null then
    return json_build_object('ok', false, 'err', 'En az bir arkadaşını davet et.');
  end if;

  select count(*) into bad from unnest(p_invitees) x
  where not exists (select 1 from friendships f
                    where (f.user_a = uid and f.user_b = x)
                       or (f.user_b = uid and f.user_a = x));
  if bad > 0 then
    return json_build_object('ok', false, 'err', 'Yalnızca arkadaşlarını davet edebilirsin.');
  end if;

  select count(*) into active
  from challenges c
  join challenge_members m on m.challenge_id = c.id
  where m.user_id = uid and m.status = 'katildi' and c.end_day >= d;
  if active >= 3 then
    return json_build_object('ok', false, 'err', 'Aynı anda en fazla 3 aktif challenge olabilir.');
  end if;

  insert into challenges (creator, kind, daily_target, start_day, end_day, title)
  values (uid, p_kind, p_target, d, d + p_days - 1, trim(p_title))
  returning id into cid;

  insert into challenge_members (challenge_id, user_id, status)
  values (cid, uid, 'katildi');
  insert into challenge_members (challenge_id, user_id, status)
  select cid, x, 'davetli' from unnest(p_invitees) x
  where x <> uid
  on conflict do nothing;

  return json_build_object('ok', true, 'id', cid);
end;
$$;

-- Davete yanıt (kabul/ret) — ret sonradan da verilebilir (ayrılma).
create or replace function public.respond_challenge(p_challenge uuid, p_accept boolean)
returns void
language sql security definer set search_path = public as $$
  update challenge_members
     set status = case when p_accept then 'katildi' else 'reddetti' end
   where challenge_id = p_challenge and user_id = auth.uid();
$$;

-- ---------------------------------------------------------------------------
-- Genel bakış: üyesi olduğum (reddetmediğim) challenge'lar; biten,
-- 7 gün daha sonuç ekranı olarak görünür. days_done = gün hedefinin
-- tutturulduğu gün sayısı, rings_daily'den türetilir.
create or replace function public.challenge_overview()
returns json
language sql security definer set search_path = public as $$
  with today as (select (now() at time zone 'Europe/Istanbul')::date as d)
  select coalesce(json_agg(json_build_object(
    'id', c.id,
    'title', c.title,
    'kind', c.kind,
    'daily_target', c.daily_target,
    'start_day', c.start_day,
    'end_day', c.end_day,
    'my_status', my.status,
    'members', (
      select json_agg(json_build_object(
        'user_id', m.user_id,
        'name', coalesce(nullif(u.full_name, ''), 'Arkadaş'),
        'username', u.username,
        'status', m.status,
        'is_me', m.user_id = auth.uid(),
        'days_done', (
          select count(*) from rings_daily r
          where r.user_id = m.user_id
            and r.day between c.start_day and least(c.end_day, (select d from today))
            and (case c.kind when 'su' then r.water_ml
                             when 'adim' then r.steps
                             else r.exercise_min end) >= c.daily_target
        )
      ) order by u.full_name)
      from challenge_members m
      join users u on u.id = m.user_id
      where m.challenge_id = c.id and m.status <> 'reddetti'
    )
  ) order by c.end_day), '[]'::json)
  from challenges c
  join challenge_members my on my.challenge_id = c.id and my.user_id = auth.uid()
  where my.status <> 'reddetti'
    and c.end_day >= (select d from today) - 7;
$$;
