-- Beslenme protokolleri (0018).
--
-- Kanıt düzeyi ayrı bir sütun: Dukan ile Akdeniz aynı güvenle sunulamaz.
-- Kullanıcı neyin neye dayandığını görmeli — "zayıf" etiketi saklanmıyor.
-- `contraindications` sihirbazın sağlık taramasıyla eşleşiyor; uygun
-- olmayan protokol kullanıcıya HİÇ gösterilmiyor.

insert into public.diet_protocols
  (key, name, summary, evidence, evidence_note, source_url,
   carb_pct_min, carb_pct_max, fat_pct_min, fat_pct_max,
   protein_pct_min, protein_pct_max, protein_g_per_kg,
   favor_categories, limit_categories, avoid_categories, avoid_tags,
   contraindications, needs_doctor, warning, phases, sort_order)
values
('akdeniz','Akdeniz Diyeti','Sebze, baklagil, balık ve zeytinyağı ağırlıklı. Kalp sağlığı ve uzun vadeli sürdürülebilirlik açısından en güçlü kanıta sahip beslenme düzeni.','güçlü','PREDIMED gibi büyük randomize çalışmalarla desteklenmiş.','https://link.springer.com/article/10.1186/s12967-025-07109-7',35,45,35,45,15,20,null,ARRAY['sebze','salata','balik','baklagil','meyve','kuruyemis','corba']::text[],ARRAY['et','tatli','hamur']::text[],ARRAY['fastfood']::text[],'{}','{}',false,null,null,10),
('dengeli','Dengeli Beslenme','Türkiye Beslenme Rehberi''ne (TÜBER) dayanan, hiçbir besin grubunu dışlamayan denge düzeni.','güçlü','Sağlık Bakanlığı resmî rehberi.',null,45,55,25,35,15,20,null,ARRAY['sebze','salata','corba','baklagil','meyve','sut']::text[],ARRAY['tatli','atistirmalik']::text[],ARRAY['fastfood']::text[],'{}','{}',false,null,null,20),
('yuksek_protein','Yüksek Proteinli','Kalori açığındayken kas kütlesini korumaya odaklı. Kuvvet antrenmanıyla birlikte anlamlı.','güçlü','Açıkta yağsız kütle korunumu için 1,2–1,6 g/kg protein; antrenmanlı kişilerde kazanım 1,6 g/kg''da platoya ulaşıyor.','https://pmc.ncbi.nlm.nih.gov/articles/PMC5867436/',30,40,25,35,null,null,1.6,ARRAY['et','balik','yumurta','sut','baklagil']::text[],ARRAY['tatli','hamur','atistirmalik']::text[],ARRAY['fastfood']::text[],'{}',ARRAY['bobrek','gut','karaciger']::text[],false,null,null,30),
('dash','DASH (Tansiyon)','Tansiyonu düşürmek için geliştirilen düzen: düşük sodyum, yüksek potasyum, bol sebze ve süt ürünü.','güçlü','Hipertansiyonda randomize çalışmalarla desteklenmiş.',null,50,55,25,30,17,20,null,ARRAY['sebze','salata','meyve','sut','baklagil','balik']::text[],ARRAY['et','tatli']::text[],ARRAY['fastfood','atistirmalik']::text[],'{}','{}',false,null,null,40),
('dusuk_karb','Düşük Karbonhidrat','Karbonhidrat kısıtlı, protein ve yağ ağırlıklı. Kısa vadede kilo kaybı ve kan şekeri kontrolünde etkili.','orta','Kısa vadeli etkisi gösterilmiş; uzun vadede diğer kalori kısıtlı düzenlerden üstünlüğü net değil.',null,20,30,40,50,25,30,null,ARRAY['et','balik','yumurta','sebze','salata','sut']::text[],ARRAY['meyve','baklagil']::text[],ARRAY['pilav','makarna','ekmek','hamur','tatli','tahil','fastfood']::text[],'{}',ARRAY['yeme_bozuklugu']::text[],false,'Diyabet ilacı kullanıyorsan doz ayarı gerekebilir; hekimine danış.',null,50),
('ketojenik','Ketojenik','Karbonhidrat çok düşük (%5–10), yağ çok yüksek. Vücudu keton metabolizmasına geçirir.','orta','Kısa vadeli kilo kaybı ve bazı metabolik göstergelerde iyileşme gösterilmiş; uzun vadeli güvenlik verisi sınırlı.',null,5,10,65,75,20,25,null,ARRAY['et','balik','yumurta','sebze','salata','kuruyemis']::text[],ARRAY['sut']::text[],ARRAY['pilav','makarna','ekmek','hamur','tatli','tahil','meyve','baklagil','atistirmalik','fastfood']::text[],'{}',ARRAY['bobrek','karaciger','yeme_bozuklugu','gebelik','emzirme']::text[],true,'İlk günlerde halsizlik ve baş ağrısı olabilir. Hekim gözetimi olmadan uzun süre uygulanmamalı.',null,60),
('aralikli_oruc','Aralıklı Oruç (16:8)','Günün 8 saatlik penceresinde yemek, 16 saat aç kalmak. Ne yediğini değil, ne zaman yediğini düzenler.','orta','Kilo kaybında kalori kısıtlamasıyla benzer sonuç veriyor; ek bir üstünlüğü net değil.',null,40,50,30,35,18,25,null,ARRAY['sebze','salata','balik','et','yumurta','baklagil']::text[],ARRAY['tatli','atistirmalik']::text[],ARRAY['fastfood']::text[],'{}',ARRAY['gebelik','emzirme','diyabet_ilac','yeme_bozuklugu']::text[],false,'Öğün penceresi dışında yalnızca su, sade çay ve sade kahve.',null,70),
('lipodem','Lipödem Beslenmesi','Lipödemde araştırılan anti-enflamatuar ve düşük karbonhidratlı yaklaşım. Ödem ve ağrı şikâyetlerinde iyileşme bildiren çalışmalar var.','gelişmekte','2024 Alman S2k kılavuzu: beslenme çok bileşenli tedavinin bir PARÇASI, tedavinin kendisi değil. Uzun vadeli güvenlik verisi yok.','https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12106162/',15,25,50,60,20,25,null,ARRAY['sebze','salata','balik','yumurta','kuruyemis','et']::text[],ARRAY['meyve','sut']::text[],ARRAY['pilav','makarna','ekmek','hamur','tatli','tahil','fastfood','atistirmalik']::text[],'{}',ARRAY['gebelik','emzirme','yeme_bozuklugu']::text[],true,'Bu bir tedavi değildir. Lipödem tanısı ve tedavisi hekim işidir; bu düzen yalnızca hekiminin onayıyla denenmeli.',null,80),
('dukan','Dukan','Dört evreli, çok yüksek proteinli düzen. İlk evrede yalnızca yağsız protein tüketilir.','zayıf','Yayımlanmış çalışmalar küçük ve kısa vadeli. İlk evredeki hızlı kayıp büyük ölçüde SU kaybıdır, yağ değil. Uzun vadede diğer kalori kısıtlı düzenlerden üstün olduğuna dair kanıt yok.','https://health.clevelandclinic.org/dukan-diet',5,15,15,25,null,null,2.0,ARRAY['et','balik','yumurta','sut']::text[],ARRAY['sebze','salata']::text[],ARRAY['pilav','makarna','ekmek','hamur','tatli','tahil','meyve','baklagil','kuruyemis','atistirmalik','fastfood']::text[],'{}',ARRAY['bobrek','gut','karaciger','gebelik','emzirme','yeme_bozuklugu']::text[],true,'Kanıt düzeyi zayıf. Beslenme dengesizliği ve sürdürülebilirlik açısından eleştiriliyor; uzun süre uygulanması önerilmez.','[{"ad": "Atak", "sure": "2–7 gün", "aciklama": "Yalnızca yağsız protein + 1,5 yemek kaşığı yulaf kepeği"}, {"ad": "Seyir", "sure": "hedefe göre", "aciklama": "Belirli sebzeler gün aşırı eklenir"}, {"ad": "Pekiştirme", "sure": "verilen kilo başına 5 gün", "aciklama": "Peynir, ekmek ve meyve kademeli eklenir"}, {"ad": "Kalıcılık", "sure": "süresiz", "aciklama": "Haftada 1 gün saf protein, günlük 3 kaşık yulaf kepeği, 20 dk yürüyüş"}]'::jsonb,90)
on conflict (key) do update set
  name = excluded.name, summary = excluded.summary, evidence = excluded.evidence,
  evidence_note = excluded.evidence_note, source_url = excluded.source_url,
  carb_pct_min = excluded.carb_pct_min, carb_pct_max = excluded.carb_pct_max,
  fat_pct_min = excluded.fat_pct_min, fat_pct_max = excluded.fat_pct_max,
  protein_pct_min = excluded.protein_pct_min, protein_pct_max = excluded.protein_pct_max,
  protein_g_per_kg = excluded.protein_g_per_kg,
  favor_categories = excluded.favor_categories,
  limit_categories = excluded.limit_categories,
  avoid_categories = excluded.avoid_categories,
  avoid_tags = excluded.avoid_tags,
  contraindications = excluded.contraindications,
  needs_doctor = excluded.needs_doctor, warning = excluded.warning,
  phases = excluded.phases, sort_order = excluded.sort_order;
