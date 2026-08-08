-- Genel yemek adları (0013).
--
-- Sorun: AI "yoğurt" dediğinde katalogda düz "Yoğurt" kaydı yoktu; eşleşme
-- `%yogurt%` içeren kayıtlara düşüyor ve "Yoğurt çorbası"nı seçebiliyordu.
-- Bir kase sade yoğurt çorba olarak kaydediliyordu.
--
-- Genel adlar aynı zamanda AI'a verilen sözlüğün tabanı: model tam
-- karşılığını bulamadığında en yakın genel kayda düşebilsin.

insert into public.foods
  (name, search_key, category, kcal_100g, protein_100g, carb_100g, fat_100g, portion_g, portion_name)
values
('Yoğurt','yogurt','sut',61,3.5,4.7,3.3,200,'kase'),
('Peynir','peynir','sut',290,20.0,2.0,22.0,30,'dilim'),
('Ekmek','ekmek','ekmek',265,8.5,49.0,3.2,50,'dilim'),
('Salata','salata','salata',33,1.1,4.8,1.1,200,'porsiyon'),
('Çorba','corba','corba',65,3.0,9.0,1.9,250,'kase'),
('Tavuk','tavuk','et',150,28.0,0.0,3.6,150,'porsiyon'),
('Et','et','et',215,21.0,0.0,14.0,150,'porsiyon'),
('Balık','balik','balik',145,22.0,0.0,6.0,150,'porsiyon'),
('Pilav','pilav','pilav',145,3.0,28.0,2.5,150,'porsiyon'),
('Makarna','makarna','makarna',140,4.5,26.0,2.6,200,'porsiyon'),
('Köfte','kofte','et',215,18.0,4.5,13.5,150,'porsiyon'),
('Börek','borek','hamur',290,9.0,28.0,16.0,150,'porsiyon'),
('Meyve','meyve','meyve',52,0.6,13.0,0.3,150,'porsiyon'),
('Kuruyemiş','kuruyemis','kuruyemis',600,17.0,20.0,55.0,30,'porsiyon'),
('Tatlı','tatli','tatli',330,4.5,48.0,13.0,100,'porsiyon'),
('Kahve','kahve','icecek',2,0.1,0.3,0.0,200,'fincan'),
('Çay','cay','icecek',1,0.0,0.2,0.0,120,'bardak'),
('Sebze yemeği','sebze yemegi','sebze',80,2.5,9.0,4.0,200,'porsiyon'),
('Yumurta','yumurta','yumurta',155,13.0,1.1,11.0,50,'adet'),
('Zeytinyağlı sebze','zeytinyagli sebze','sebze',78,2.0,8.5,4.0,200,'porsiyon')
on conflict (search_key) do update set
  kcal_100g = excluded.kcal_100g,
  protein_100g = excluded.protein_100g,
  carb_100g = excluded.carb_100g,
  fat_100g = excluded.fat_100g,
  portion_g = excluded.portion_g,
  portion_name = excluded.portion_name;
