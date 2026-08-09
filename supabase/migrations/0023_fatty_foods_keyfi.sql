-- Yağlı hazır yemekler plandan çıkıyor (0023).
--
-- Simge'nin sözüyle: "yemek önerilerine kebap gibi yağlı şeyleri eklemesi
-- doğru değil". Adana/Urfa/Beyti kebap, lahmacun, kıymalı/kaşarlı pide,
-- kuru köfte (yağda kızarır) ve tas kebabı 0021'de `ana` rolündeydi —
-- kural tabanlı üretici bunları öğle/akşam ana yemeği olarak planlıyordu.
-- Hiçbir diyet protokolünde yerleri yok; `keyfi` role alınıyor: kullanıcı
-- elle günlüğüne ekleyebilir, biz ÖNERMİYORUZ. (AI tarafında aynı liste
-- artık her hedefte yasak anahtar olarak gidiyor — AppModel.fattyDishBans.)

update public.foods f
set role = v.role
from (values
('adana kebap','keyfi'),
('urfa kebap','keyfi'),
('beyti kebap','keyfi'),
('tas kebabi','keyfi'),
('kuru kofte','keyfi'),
('lahmacun','keyfi'),
('pide (kiymali)','keyfi'),
('pide (kasarli)','keyfi'),
-- Aynı mantıkla: tereyağlı/kremalı ve hamur işi "ana yemekler" de
-- diyetisyen planına girmez. Börek öğle ana yemeği olamaz.
('hunkar begendi','keyfi'),
('borek (peynirli)','keyfi'),
('borek (kiymali)','keyfi'),
('gozleme','keyfi'),
('tost','keyfi')
) as v(search_key, role)
where f.search_key = v.search_key;

-- 0019'daki etiket hatası: lahmacun ve kıymalı pide "vegan/vejetaryen"
-- işaretlenmişti — ikisi de kıymalı. Kaşarlı pide vejetaryen ama vegan
-- değil, süt içerir. Arama/alerji filtreleri doğru çalışsın.
update public.foods f
set tags = v.tags
from (values
('lahmacun',ARRAY['gluten','et','kirmizi_et']::text[]),
('pide (kiymali)',ARRAY['gluten','et','kirmizi_et']::text[]),
('pide (kasarli)',ARRAY['gluten','sut','vejetaryen']::text[])
) as v(search_key, tags)
where f.search_key = v.search_key;
