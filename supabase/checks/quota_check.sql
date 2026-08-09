select public.ai_usage_today(u.id, 'plan_day') as bugunku_plan_cagrisi,
       (select count(*) from public.ai_usage_log where kind = 'plan_day') as toplam
from auth.users u where lower(u.email) = 'simgehelvaci@gmail.com';
