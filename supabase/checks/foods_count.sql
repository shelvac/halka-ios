-- Salt okunur kontrol: katalog tohumu yerinde mi?
select
  (select count(*) from public.foods)                             as yemek_sayisi,
  (select count(distinct category) from public.foods)             as kategori_sayisi,
  (select count(*) from public.foods where kcal_100g <= 0)        as hatali_kalori,
  (select name from public.foods where search_key = 'izgara kofte') as ornek_kofte,
  (select name from public.foods where search_key = 'mercimek corbasi') as ornek_corba,
  (select to_jsonb(f) from public.foods f where f.search_key = 'bulgur pilavi') as ornek_kayit;
