-- Hızlı ekle sayaçları (0025).
--
-- "Kahve gibi şeyleri fotoğrafsız tek dokunuşla eklemek istiyorum" —
-- katalogdan eklenen her yemek için ad → adet sayacı. Şerit en sık
-- eklenenleri öne alır. Haftalık öğün durumunun aksine SIFIRLANMAZ:
-- alışkanlık haftayla değişmez.

alter table public.meal_state
  add column if not exists quick_counts jsonb not null default '{}'::jsonb;
