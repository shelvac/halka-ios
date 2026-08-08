select
  (select count(*) from public.foods where tags <> '{}')            as etiketli,
  (select count(*) from public.foods where 'vegan' = any(tags))     as vegan,
  (select count(*) from public.foods where 'vejetaryen' = any(tags)) as vejetaryen,
  (select count(*) from public.foods where 'gluten' = any(tags))    as glutenli,
  (select tags from public.foods where search_key = 'izgara kofte') as ornek_kofte,
  (select tags from public.foods where search_key = 'beyaz peynir') as ornek_peynir,
  (select tags from public.foods where search_key = 'mercimek corbasi') as ornek_corba;
