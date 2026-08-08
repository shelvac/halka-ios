select
  (select count(*) from public.exercises)                                   as toplam,
  (select count(*) from public.exercises where needs = 'none')              as ekipmansiz,
  (select count(*) from public.exercises where needs = 'home')              as ev,
  (select count(*) from public.exercises where needs = 'gym')               as salon,
  (select count(*) from public.exercises where name_tr is not null)         as turkce_adli,
  (select jsonb_object_agg(region, n) from
     (select region, count(*) n from public.exercises group by region) t)   as bolgeler;
