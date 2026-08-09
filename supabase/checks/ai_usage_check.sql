select
  (select count(*) from public.ai_usage_log where kind = 'plan_day')  as plan_cagrisi,
  (select max(created_at) from public.ai_usage_log where kind = 'plan_day') as son_cagri,
  (select count(*) from public.meal_photo_log)                        as foto_cagrisi;
