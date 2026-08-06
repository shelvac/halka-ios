# E-posta şablonları

Bu klasördeki HTML dosyaları Supabase Auth e-postalarının gövdesidir.
`.github/workflows/supabase-smtp.yml` çalıştırıldığında dosyalar okunur ve
Supabase'e yüklenir — yani şablonu değiştirmek için sadece dosyayı düzenleyip
workflow'u yeniden çalıştırmak yeterli.

| Dosya | Ne zaman gider | Supabase alanı |
| --- | --- | --- |
| `confirmation.html` | Kayıt sonrası e-posta doğrulama | `mailer_templates_confirmation_content` |
| `recovery.html` | Şifremi unuttum | `mailer_templates_recovery_content` |
| `magic_link.html` | Şifresiz giriş bağlantısı (ileride) | `mailer_templates_magic_link_content` |
| `email_change.html` | E-posta adresi değiştirme | `mailer_templates_email_change_content` |

## Kullanılabilir değişkenler

- `{{ .ConfirmationURL }}` — eyleme özel bağlantı (uygulamayı `halka://` ile açar)
- `{{ .Token }}` — 6 haneli kod (OTP akışı eklenirse)
- `{{ .Email }}` / `{{ .NewEmail }}` — adresler
- `{{ .SiteURL }}` — site adresi

## Tasarım kuralları

- **Tablo tabanlı düzen** — Gmail/Outlook flexbox ve grid'i desteklemez
- **Inline stiller** — `<style>` blokları çoğu istemcide silinir
- Marka renkleri: mercan `#E45C49`, mürekkep `#26221B`, kum `#F7F4EF`, ikincil `#96907F`
- Logo, `border-radius` ile çizilen iç içe halkalardır (görsel barındırmaya gerek yok)
- Her şablonda gizli **preheader** metni vardır (gelen kutusu önizlemesi)
- Düğme çalışmazsa diye bağlantının düz metin hâli de yer alır
