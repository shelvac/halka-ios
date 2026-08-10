-- Kullanıcı tanımlı yiyecekler ORTAK kataloğa (0028).
--
-- Simge'nin kararı: "gizliliğe gerek yok, tüm katalogda güncellensin".
-- 0027'deki kişiye özel görünürlük kaldırıldı — eklenen yiyecek herkese
-- görünür ve herkesin aramasında/fotoğraf eşleşmesinde bulunur.
-- created_by sütunu kalır (kimin eklediği izlenebilir); ekleme yine
-- kimlikli, silme yalnızca kendi kaydında.

-- Aynı ada sahip yinelenen kayıtlar küresel benzersizliği engellemesin:
-- küratörlü kayıt tercih edilir, değilse en eski kalır.
delete from public.foods f
using public.foods g
where f.search_key = g.search_key
  and f.id <> g.id
  and f.created_by is not null
  and (g.created_by is null
       or g.created_at < f.created_at
       or (g.created_at = f.created_at and g.id < f.id));

drop index if exists foods_search_scope_idx;
create unique index if not exists foods_name_idx on public.foods (search_key);

drop policy if exists foods_read_all on public.foods;
create policy foods_read_all on public.foods
  for select to authenticated using (true);
