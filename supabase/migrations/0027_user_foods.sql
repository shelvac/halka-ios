-- Kullanıcı tanımlı yiyecekler + eksik yaygın yiyecekler (0027).
--
-- "AI hindi fümeyi tanımadı ve listede bulamadım": (1) hindi füme gibi
-- yaygın diyet yiyecekleri kataloğa eklendi; (2) katalogda olmayan bir
-- şeyi kullanıcı kendisi tanımlayabilir — kaydı YALNIZCA kendisi görür
-- (created_by), sonraki aramalarda ve fotoğraf eşleşmesinde bulunur.

alter table public.foods
  add column if not exists created_by uuid references auth.users(id) on delete cascade;

-- Küresel benzersizlik kullanıcı yemekleriyle çakışırdı: iki kullanıcı
-- aynı adı tanımlayabilmeli; küratörlü katalog (created_by null) kendi
-- içinde benzersiz kalmalı.
drop index if exists foods_name_idx;
create unique index if not exists foods_search_scope_idx
  on public.foods (search_key, coalesce(created_by, '00000000-0000-0000-0000-000000000000'::uuid));

-- Okuma: küratörlü katalog + kullanıcının kendi ekledikleri.
drop policy if exists foods_read_all on public.foods;
create policy foods_read_all on public.foods
  for select to authenticated
  using (created_by is null or created_by = auth.uid());

-- Yazma: kullanıcı yalnızca kendi adına ekleyebilir/silebilir;
-- küratörlü kataloğa (created_by null) istemciden yazılamaz.
drop policy if exists foods_insert_own on public.foods;
create policy foods_insert_own on public.foods
  for insert to authenticated
  with check (created_by = auth.uid());

drop policy if exists foods_delete_own on public.foods;
create policy foods_delete_own on public.foods
  for delete to authenticated
  using (created_by = auth.uid());

-- Eksik yaygın yiyecekler (diyetisyen planlarının gediklileri).
insert into public.foods
  (name, search_key, category, kcal_100g, protein_100g, carb_100g, fat_100g, portion_g, portion_name, tags, role)
values
('Hindi füme','hindi fume','et',104,17.0,1.5,3.5,30,'dilim',ARRAY['et','beyaz_et']::text[],'kahvalti_yan'),
('Tavuk jambon','tavuk jambon','et',110,15.0,2.0,4.5,30,'dilim',ARRAY['et','beyaz_et']::text[],'kahvalti_yan'),
('Füme somon','fume somon','balik',117,18.0,0.0,4.5,50,'porsiyon',ARRAY['balik']::text[],'kahvalti_yan'),
('Ton balığı (konserve, suda)','ton baligi (konserve, suda)','balik',116,26.0,0.0,1.0,80,'porsiyon',ARRAY['balik']::text[],'ana'),
('Hindi ızgara','hindi izgara','et',135,29.0,0.0,1.5,150,'porsiyon',ARRAY['et','beyaz_et']::text[],'ana'),
('Keçi peyniri','keci peyniri','sut',290,18.0,2.5,23.0,30,'porsiyon',ARRAY['sut','vejetaryen']::text[],'kahvalti_protein'),
('Chia tohumu','chia tohumu','kuruyemis',486,17.0,42.0,31.0,15,'yemek kaşığı',ARRAY['vegan','vejetaryen']::text[],'kuruyemis'),
('Yulaf kepeği','yulaf kepegi','tahil',246,17.0,66.0,7.0,30,'porsiyon',ARRAY['gluten','vegan','vejetaryen']::text[],'kahvalti_yan'),
('Pirinç keki','pirinc keki','atistirmalik',387,8.0,82.0,3.0,9,'adet',ARRAY['vegan','vejetaryen']::text[],'keyfi')
on conflict do nothing;
