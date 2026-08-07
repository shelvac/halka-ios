-- US-021 — Hesabı sil (KVKK md. 7 / GDPR "unutulma hakkı").
--
-- Kullanıcı kendi hesabını silebilmeli. `auth.users` tablosuna istemciden
-- doğrudan yazılamaz (yalnızca service_role yetkilidir; o anahtar da asla
-- uygulamaya gömülmez). Bu yüzden silme işlemi SECURITY DEFINER bir fonksiyona
-- devrediliyor: fonksiyon yalnızca ÇAĞIRANIN KENDİ kaydını siler.
--
-- Veri temizliği: public.users → auth.users zincirinde `on delete cascade`
-- tanımlı; ölçümler, öğünler, antrenmanlar, tahliller, mesajlar, satın almalar
-- ve diyetisyen kaydı bu tek silmeyle birlikte gider (0001_init.sql).

create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Oturum bulunamadı' using errcode = '28000';
  end if;

  -- Yalnızca çağıranın kendi kaydı; cascade gerisini halleder.
  delete from auth.users where id = uid;
end;
$$;

comment on function public.delete_account() is
  'Oturumdaki kullanıcının hesabını ve tüm verisini siler (KVKK md. 7).';

-- Yalnızca oturum açmış kullanıcı çağırabilir.
revoke all on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;
