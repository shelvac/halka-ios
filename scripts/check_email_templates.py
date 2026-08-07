#!/usr/bin/env python3
"""E-posta şablonlarını statik olarak doğrular.

Gerçek teslimatı test edemez (o Bölüm 1'deki manuel testlerin işi) ama şablon
bozulmalarının büyük çoğunluğunu yakalar: eksik Supabase değişkeni (mail gider,
düğme hiçbir yere gitmez), bozuk HTML, kaybolan marka öğeleri, dış kaynaklı
görsel (çoğu istemci engeller → tasarım dağılır).

Kullanım:  python3 scripts/check_email_templates.py
Çıkış kodu 0 = temiz, 1 = en az bir hata.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
EMAILS = ROOT / "supabase" / "emails"

# Bağlantılı şablonlar Supabase'in URL değişkenini İÇERMEK ZORUNDA.
NEEDS_URL = {
    "confirmation.html",
    "recovery.html",
    "magic_link.html",
    "email_change.html",
}
# Bildirim şablonlarında bağlantı yok — yalnızca haber verirler.
NOTIFICATIONS = {
    "password_changed.html",
    "email_changed_notification.html",
    "identity_linked.html",
    "identity_unlinked.html",
}

BRAND_COLOR = "#E45C49"
FOOTER_HINT = "beslenme, egzersiz ve sağlık takibi"


def check(path: pathlib.Path) -> list[str]:
    html = path.read_text(encoding="utf-8")
    name = path.name
    errs: list[str] = []

    if name in NEEDS_URL and "{{ .ConfirmationURL }}" not in html:
        errs.append("`{{ .ConfirmationURL }}` yok — düğme hiçbir yere gitmez")

    if name in NOTIFICATIONS and "{{" in html:
        errs.append("bildirim şablonunda değişken var — Supabase bunu doldurmaz")

    # Kapanmayan etiket = bazı istemcilerde boş mail
    for tag in ("html", "body", "table"):
        if html.count(f"<{tag}") != html.count(f"</{tag}>"):
            errs.append(f"<{tag}> etiketleri dengesiz")

    if 'lang="tr"' not in html:
        errs.append('lang="tr" yok — ekran okuyucular yanlış dilde okur')

    if BRAND_COLOR not in html:
        errs.append(f"marka rengi {BRAND_COLOR} yok")

    if FOOTER_HINT not in html:
        errs.append("alt bilgi metni eksik")

    # Dış kaynaklı görsel: çoğu istemci varsayılan olarak engeller
    for src in re.findall(r'src="([^"]+)"', html):
        if src.startswith("http"):
            errs.append(f"dış görsel: {src} — istemciler engelleyebilir")

    if "{{ .Token }}" in html and name != "reauthentication.html":
        errs.append("beklenmeyen `{{ .Token }}` değişkeni")

    return errs


def main() -> int:
    files = sorted(EMAILS.glob("*.html"))
    if not files:
        print("❌ supabase/emails altında şablon bulunamadı")
        return 1

    expected = NEEDS_URL | NOTIFICATIONS
    found = {f.name for f in files}
    missing = expected - found
    failed = False

    for f in files:
        errs = check(f)
        if errs:
            failed = True
            print(f"❌ {f.name}")
            for e in errs:
                print(f"   · {e}")
        else:
            print(f"✅ {f.name}")

    for m in sorted(missing):
        failed = True
        print(f"❌ {m} — dosya eksik")

    print()
    print("Sonuç:", "HATALI" if failed else f"{len(files)} şablon temiz")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
