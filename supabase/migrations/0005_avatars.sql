-- US-016 — Profil fotoğrafı.
--
-- Bucket ÖZEL (public = false): profil fotoğrafı kişisel veridir; herkese açık
-- bir bucket'ta URL'i bilen herkes görebilir. Uygulama dosyayı imzalı erişimle
-- indirip yerelde gösterir.
--
-- Dosya yolu: "<user_id>/avatar.jpg" — RLS politikaları klasör adının
-- kullanıcının kendi id'si olmasını şart koşuyor, böylece kimse başkasının
-- fotoğrafına dokunamaz.

alter table public.users
  add column if not exists avatar_path text;

comment on column public.users.avatar_path is
  'avatars bucket''ındaki dosya yolu (<user_id>/avatar.jpg). Boşsa baş harf gösterilir.';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', false, 5242880,
        array['image/jpeg', 'image/png', 'image/heic', 'image/webp'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Politikalar: yalnızca kendi klasörüne yazar, yalnızca kendi dosyasını okur.
drop policy if exists "avatar_select_own" on storage.objects;
create policy "avatar_select_own" on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "avatar_insert_own" on storage.objects;
create policy "avatar_insert_own" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "avatar_update_own" on storage.objects;
create policy "avatar_update_own" on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "avatar_delete_own" on storage.objects;
create policy "avatar_delete_own" on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
