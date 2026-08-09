-- Teşhis: 0023 uygulanmış mı — kebap ailesi gerçekten 'keyfi' mi?
select json_build_object(
  'kebap_ailesi', (
    select json_agg(json_build_object('ad', name, 'rol', role) order by name)
    from public.foods
    where search_key in ('adana kebap','urfa kebap','beyti kebap','iskender kebap',
                         'tas kebabi','kuru kofte','lahmacun',
                         'pide (kiymali)','pide (kasarli)',
                         'borek (peynirli)','borek (kiymali)','gozleme','tost',
                         'hunkar begendi')
  ),
  'hala_ana_rolunde_kebap', (
    select count(*) from public.foods
    where role in ('ana','kahvalti_protein')
      and (lower(name) like '%kebap%' or lower(name) like '%kebab%'
        or lower(name) like '%döner%' or lower(name) like '%lahmacun%'
        or lower(name) like '%pide%'  or lower(name) like '%börek%')
  )
) as rapor;
