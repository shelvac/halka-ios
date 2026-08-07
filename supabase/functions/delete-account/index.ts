// US-021 — Hesabı sil + veda e-postası.
//
// Neden Edge Function:
//   1. `auth.users` yalnızca service_role ile silinebilir; o anahtar asla
//      uygulamaya gömülmez. Burada Supabase tarafından ortam değişkeni olarak
//      sağlanır, dışarı çıkmaz.
//   2. Hesap silindikten sonra Supabase hiçbir bildirim göndermez — veda
//      e-postasını bizim göndermemiz gerekir; SMTP şifresi de yine yalnızca
//      sunucuda durur.
//
// Sıra önemli: e-posta ÖNCE gönderilir (silindikten sonra adresi okuyamayız),
// gönderim başarısız olsa bile silme işlemi yapılır — kullanıcının silme hakkı
// e-posta altyapısına bağlı olmamalı.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";
import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function goodbyeHtml(name: string): string {
  const merhaba = name ? `Merhaba ${name},` : "Merhaba,";
  return `<!DOCTYPE html>
<html lang="tr">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light"><title>halka</title></head>
<body style="margin:0;padding:0;background:#F7F4EF;">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;">Hesabın silindi. İyi ki geldin.&#8203;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#F7F4EF;padding:32px 12px;">
<tr><td align="center">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:480px;">
    <tr><td align="center" style="padding-bottom:22px;">
      <table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>
        <td style="vertical-align:middle;padding-right:10px;">
          <div style="width:40px;height:40px;border:5px solid #E45C49;border-radius:50%;box-sizing:border-box;padding:4px;">
            <div style="width:100%;height:100%;border:4px solid #3E9BD6;border-radius:50%;box-sizing:border-box;padding:3px;">
              <div style="width:100%;height:100%;background:#45A46F;border-radius:50%;"></div>
            </div>
          </div>
        </td>
        <td style="vertical-align:middle;">
          <div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:26px;font-weight:800;color:#26221B;letter-spacing:-1px;line-height:1;">halka</div>
          <div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:11px;font-weight:700;color:#96907F;letter-spacing:.2px;padding-top:3px;">Her gün %1 daha iyi</div>
        </td>
      </tr></table>
    </td></tr>
    <tr><td style="background:#ffffff;border-radius:22px;padding:34px 30px;">
      <div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;display:inline-block;font-size:11px;font-weight:800;color:#7A6FA8;background:#EFECF8;padding:6px 12px;border-radius:999px;letter-spacing:.3px;">HESAP SİLİNDİ</div>
      <div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:22px;font-weight:800;color:#26221B;letter-spacing:-.5px;padding:16px 0 0;">Görüşmek üzere 👋</div>
      <div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:14.5px;font-weight:500;color:#4A453B;line-height:1.65;padding:12px 0 0;">${merhaba}<br><br>halka hesabın ve tüm verilerin kalıcı olarak silindi: ölçümlerin, öğünlerin, antrenmanların, tahlillerin ve mesajların. Sunucularımızda hiçbir kaydın kalmadı.</div>
      <div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:14.5px;font-weight:500;color:#4A453B;line-height:1.65;padding:18px 0 0;">Aramızdan ayrıldığın için üzgünüz. Bir gün dönmek istersen kapımız açık — aynı e-posta adresiyle yeniden kayıt olabilirsin.</div>
      <div style="border-top:1px solid #F3EEE5;margin:24px 0 0;"></div>
      <div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:12px;font-weight:600;color:#B4AC9C;line-height:1.65;padding:18px 0 0;">Bu silme işlemini sen yapmadıysan lütfen bize ulaş.</div>
    </td></tr>
    <tr><td align="center" style="padding:22px 10px 0;">
      <div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:11px;font-weight:600;color:#B4AC9C;line-height:1.7;">
        halka · beslenme, egzersiz ve sağlık takibi<br>
        Bu e-posta hesap işlemlerinle ilgilidir; pazarlama içeriği barındırmaz.
      </div>
    </td></tr>
  </table>
</td></tr>
</table>
</body>
</html>`;
}

async function sendGoodbye(to: string, name: string): Promise<string> {
  const user = Deno.env.get("GMAIL_ADDRESS");
  const pass = Deno.env.get("GMAIL_APP_PASSWORD");
  if (!user || !pass) return "smtp-yapilandirilmamis";

  const client = new SMTPClient({
    connection: { hostname: "smtp.gmail.com", port: 465, tls: true, auth: { username: user, password: pass } },
  });
  try {
    await client.send({
      from: `halka <${user}>`,
      to,
      subject: "halka — hesabın silindi",
      html: goodbyeHtml(name),
    });
    return "gonderildi";
  } finally {
    await client.close();
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...CORS, "Content-Type": "application/json" },
    });

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Oturum bulunamadı" }, 401);

  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // 1) Çağıranın kimliğini KENDİ token'ıyla doğrula — başkasının hesabı silinemesin.
  const caller = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await caller.auth.getUser();
  if (userErr || !userData?.user) return json({ error: "Geçersiz oturum" }, 401);

  const user = userData.user;
  const email = user.email ?? "";
  const name = (user.user_metadata?.full_name as string | undefined)?.split(" ")[0] ?? "";

  // 2) Veda e-postası — silmeden ÖNCE, adres hâlâ elimizdeyken.
  let mail = "atlandi";
  if (email) {
    try {
      mail = await sendGoodbye(email, name);
    } catch (e) {
      mail = `hata: ${e instanceof Error ? e.message : String(e)}`;
    }
  }

  // 3) Silme — e-posta başarısız olsa bile yapılır.
  const admin = createClient(url, serviceKey);
  const { error: delErr } = await admin.auth.admin.deleteUser(user.id);
  if (delErr) return json({ error: delErr.message, mail }, 500);

  return json({ ok: true, mail });
});
