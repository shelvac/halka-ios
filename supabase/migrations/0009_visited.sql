-- Seri (streak) — uygulamanın üst üste kaç gün açıldığı.
--
-- Neden ayrı bir sütun: seriyi "veri olan gün" üzerinden hesaplamak yanıltıcı
-- olurdu, çünkü Apple Health geçmişi son 90 günü otomatik dolduruyor. Kullanıcı
-- uygulamayı hiç açmadığı günler de seriye sayılırdı. `visited` yalnızca
-- uygulama gerçekten açıldığında işaretlenir.

alter table public.rings_daily
  add column if not exists visited boolean not null default false;

comment on column public.rings_daily.visited is
  'Uygulama o gün açıldı mı? Seri hesabı buna bakar; Health aktarımı bunu yazmaz.';
