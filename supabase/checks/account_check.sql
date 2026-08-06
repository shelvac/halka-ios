-- Teşhis: account_status fonksiyonu çalışıyor mu + sistemdeki hesaplar
select json_build_object(
  'fonksiyon_kayitli_adres', public.account_status('simgehelvaci@gmail.com'),
  'fonksiyon_olmayan_adres', public.account_status('yok-boyle-bir-adres@example.com'),
  'toplam_kullanici', (select count(*) from auth.users),
  'hesaplar', (
    select json_agg(json_build_object(
      'email', u.email,
      'sifreli', (u.encrypted_password is not null and u.encrypted_password <> ''),
      'dogrulanmis', u.email_confirmed_at is not null,
      'saglayicilar', (select string_agg(distinct i.provider, ',') from auth.identities i where i.user_id = u.id)
    ))
    from auth.users u
  )
) as rapor;
