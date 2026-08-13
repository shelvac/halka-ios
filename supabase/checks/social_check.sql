-- Arkadaş istatistikleri teşhisi: bugün (Europe/Istanbul) kimin rings_daily
-- satırı var, arkadaşlıklar/istekler ne durumda? (E-posta gibi kimlik verisi
-- seçilmez; yalnızca kullanıcı adı + günlük metrikler.)
select json_build_object(
  'today', (now() at time zone 'Europe/Istanbul')::date,
  'users', (
    select json_agg(json_build_object(
      'username', u.username,
      'name', u.full_name,
      'exercise_min', r.exercise_min,
      'water_ml', r.water_ml,
      'steps', r.steps,
      'nutrition_kcal', r.nutrition_kcal,
      'visited', r.visited
    ) order by u.username nulls last)
    from public.users u
    left join public.rings_daily r
      on r.user_id = u.id
     and r.day = (now() at time zone 'Europe/Istanbul')::date
  ),
  'friendships', (
    select coalesce(json_agg(json_build_object('a', ua.username, 'b', ub.username)), '[]'::json)
    from public.friendships f
    join public.users ua on ua.id = f.user_a
    join public.users ub on ub.id = f.user_b
  ),
  'pending_requests', (select count(*) from public.friend_requests)
);
