-- Teşhis: profil verisi sunucuda duruyor mu?
-- "Çıkış/giriş sonrası profilim uçtu" — kaydetme mi düşüyor, yükleme mi?
select json_agg(json_build_object(
  'email', a.email,
  'ad', u.full_name,
  'dogum', u.birth_date,
  'cinsiyet', u.sex,
  'boy', u.height_cm,
  'kilo', u.weight_kg,
  'hedef_kilo', u.target_weight_kg,
  'aktivite', u.activity_level,
  'profil_tamamlandi', u.profile_completed_at,
  'avatar', u.avatar_path is not null,
  'olusturulma', u.created_at
)) as rapor
from public.users u
join auth.users a on a.id = u.id;
