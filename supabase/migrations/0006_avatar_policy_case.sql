-- US-016 düzeltmesi — avatar yükleme RLS'e takılıyordu.
--
-- Sebep: Swift'in `UUID.uuidString`i BÜYÜK harf üretir
-- ("9450A366-..."), Postgres'in `auth.uid()::text`i küçük harf döner
-- ("9450a366-..."). `users` tablosundaki karşılaştırmalar uuid tipine
-- çevrildiği için sorun çıkmıyordu; storage politikaları ise düz METİN
-- karşılaştırması yapıyor ve harf duyarlı olduğu için hep false dönüyordu.
--
-- Uygulama tarafı artık küçük harfli yol yazıyor; buradaki politikalar da
-- iki tarafı da küçülterek eski (büyük harfli) kayıtları da kapsıyor.

drop policy if exists "avatar_select_own" on storage.objects;
create policy "avatar_select_own" on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars'
         and lower((storage.foldername(name))[1]) = lower(auth.uid()::text));

drop policy if exists "avatar_insert_own" on storage.objects;
create policy "avatar_insert_own" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars'
              and lower((storage.foldername(name))[1]) = lower(auth.uid()::text));

drop policy if exists "avatar_update_own" on storage.objects;
create policy "avatar_update_own" on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars'
         and lower((storage.foldername(name))[1]) = lower(auth.uid()::text));

drop policy if exists "avatar_delete_own" on storage.objects;
create policy "avatar_delete_own" on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars'
         and lower((storage.foldername(name))[1]) = lower(auth.uid()::text));
