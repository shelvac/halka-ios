-- E7 · İsimle arama + arkadaşlık istekleri (0032).
--
-- "Kullanıcı adını yazınca bulmak istiyorum" — isimle bulmada kodun
-- taşıdığı örtük rıza yok: sessiz ekleme, habersiz izleme olurdu. Bu
-- yüzden isimle bulunan kişiye İSTEK gönderilir; kabul edince arkadaş
-- olunur. Kodla ekleme anında kalır (kodu paylaşan rızasını göstermiştir).
-- Karşılıklı istek otomatik eşleşir.

create table if not exists public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  from_user uuid not null references public.users(id) on delete cascade,
  to_user   uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (from_user, to_user),
  check (from_user <> to_user)
);

alter table public.friend_requests enable row level security;

drop policy if exists friend_requests_select on public.friend_requests;
create policy friend_requests_select on public.friend_requests
  for select using (auth.uid() in (from_user, to_user));

-- insert/delete yalnızca RPC'lerden (security definer).

-- İsimle kullanıcı arama: yalnızca ad ve arkadaşlık durumu döner.
create or replace function public.search_users(p_query text)
returns table (user_id uuid, name text, status text)
language sql security definer set search_path = public as $$
  select u.id,
         coalesce(nullif(u.full_name, ''), 'İsimsiz kullanıcı'),
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
    and length(trim(p_query)) >= 3
    and u.full_name ilike '%' || trim(p_query) || '%'
  order by u.full_name
  limit 10;
$$;

create or replace function public.send_friend_request(p_to uuid)
returns json language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if me is null or p_to is null or p_to = me then
    return json_build_object('ok', false, 'err', 'Geçersiz istek.');
  end if;
  if exists (select 1 from public.friendships
             where user_a = least(me, p_to) and user_b = greatest(me, p_to)) then
    return json_build_object('ok', false, 'err', 'Zaten arkadaşsınız.');
  end if;
  -- Karşı taraf zaten bana istek gönderdiyse: otomatik eşleş.
  if exists (select 1 from public.friend_requests
             where from_user = p_to and to_user = me) then
    delete from public.friend_requests
      where (from_user = p_to and to_user = me)
         or (from_user = me and to_user = p_to);
    insert into public.friendships (user_a, user_b)
      values (least(me, p_to), greatest(me, p_to))
      on conflict do nothing;
    return json_build_object('ok', true, 'matched', true);
  end if;
  insert into public.friend_requests (from_user, to_user)
    values (me, p_to) on conflict do nothing;
  return json_build_object('ok', true, 'matched', false);
end $$;

create or replace function public.respond_friend_request(p_from uuid, p_accept boolean)
returns void language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  delete from public.friend_requests
    where from_user = p_from and to_user = me;
  if p_accept then
    insert into public.friendships (user_a, user_b)
      values (least(me, p_from), greatest(me, p_from))
      on conflict do nothing;
  end if;
end $$;

-- Bana gelen istekler (ad + kimden).
create or replace function public.incoming_friend_requests()
returns table (from_id uuid, name text)
language sql security definer set search_path = public as $$
  select r.from_user, coalesce(nullif(u.full_name, ''), 'İsimsiz kullanıcı')
  from public.friend_requests r
  join public.users u on u.id = r.from_user
  where r.to_user = auth.uid()
  order by r.created_at desc;
$$;
