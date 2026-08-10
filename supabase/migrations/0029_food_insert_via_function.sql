-- Yiyecek ekleme yalnızca denetimli fonksiyondan (0029).
--
-- Katalog ortak (0028) olunca denetimsiz giriş kabul edilemez: küfür
-- filtresi + AI kontrolü `create-food` edge function'ında. İstemcinin
-- tabloya doğrudan yazma yolu kapatılır ki denetim aşılamaz olsun
-- (fonksiyon service_role ile yazar, RLS'e takılmaz).

drop policy if exists foods_insert_own on public.foods;
