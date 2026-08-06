-- ============================================================================
-- account_status — bir e-postanın kayıtlı olup olmadığını ve hangi yöntemle
-- açıldığını istemciye söyler (US-013 iyileştirmesi).
--
-- ⚠️ GÜVENLİK NOTU: Bu fonksiyon bilinçli olarak "e-posta sayımı"na
-- (email enumeration) izin verir — yani biri, bir adresin sistemde kayıtlı
-- olup olmadığını öğrenebilir. Ürün kararı olarak kullanıcıya net geri
-- bildirim vermek tercih edildi. Kötüye kullanımı sınırlamak için:
--   - yalnızca varlık/sağlayıcı bilgisi döner, kişisel veri dönmez
--   - Supabase'in anon anahtarı için geçerli olan istek limitleri geçerlidir
-- Gizlilik önceliğe dönerse bu fonksiyonun grant'i kaldırılıp istemci
-- tarafında tek tip onay mesajına geri dönülebilir.
-- ============================================================================

create or replace function public.account_status(p_email text)
returns json
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(
    (
      select json_build_object(
        'exists', true,
        'has_password', (u.encrypted_password is not null and u.encrypted_password <> ''),
        'providers', coalesce(
          (select string_agg(distinct i.provider, ',')
             from auth.identities i
            where i.user_id = u.id),
          '')
      )
      from auth.users u
      where lower(u.email) = lower(trim(p_email))
      limit 1
    ),
    json_build_object('exists', false, 'has_password', false, 'providers', '')
  );
$$;

grant execute on function public.account_status(text) to anon, authenticated;
