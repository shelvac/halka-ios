-- Teşhis: çeviri kalitesi örneği — bilinen hareketler + rastgele 15.
select json_build_object(
  'bilinenler', (
    select json_agg(json_build_object('en', name, 'tr', name_tr))
    from public.exercises
    where name in ('Barbell Squat','Pushups','Plank','Barbell Deadlift',
                   'Dumbbell Bicep Curl','Bench Press - Powerlifting',
                   'Standing Calf Raises','Jumping rope','Spider Crawl')
  ),
  'rastgele', (
    select json_agg(json_build_object('en', name, 'tr', name_tr))
    from (select name, name_tr from public.exercises order by md5(name) limit 15) t
  ),
  'bos_kalan', (select count(*) from public.exercises where name_tr is null or name_tr = '')
) as rapor;
