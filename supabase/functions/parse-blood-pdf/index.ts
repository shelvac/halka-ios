// Kan tahlili PDF'inden değer ayrıştırma (US-025 devamı).
//
// "Değerlerimi neden liste hâlinde görmüyorum?" — PDF Belgelerim'e
// kaydolurken Gemini test değerlerini okur, `blood_tests` tablosuna yazar;
// uygulama gerçek listeyi gösterir. Kalori/porsiyon işlerindeki ilkelerle
// aynı: anahtar sunucuda, kota sunucuda, PDF SAKLANMAZ (dosyanın kendisi
// zaten kullanıcının Belgelerim klasöründe — buraya yalnızca işlenmek
// için gelir, işlenir, atılır).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const MODEL = Deno.env.get("MEAL_AI_MODEL") ?? "gemini-3.5-flash";
const DAILY_QUOTA = Number(Deno.env.get("BLOOD_PDF_DAILY_QUOTA") ?? "5");

function bad(status: number, error: string): Response {
  return new Response(JSON.stringify({ error }), {
    status, headers: { ...CORS, "Content-Type": "application/json" },
  });
}

interface AiTest {
  grup?: string; ad?: string; deger?: number; birim?: string;
  ref_alt?: number; ref_ust?: number;
}
interface AiReport { tarih?: string; lab?: string; testler?: AiTest[] }

async function geminiParse(pdfB64: string): Promise<AiReport> {
  const key = Deno.env.get("GEMINI_API_KEY");
  if (!key) throw new Error("GEMINI_API_KEY tanımlı değil");
  const prompt =
    `Bu bir laboratuvar tahlil raporu PDF'i. İçindeki TÜM test sonuçlarını çıkar ve ` +
    `SADECE şu JSON'u dön:\n` +
    `{"tarih":"YYYY-AA-GG veya null","lab":"laboratuvar/hastane adı veya null",` +
    `"testler":[{"grup":"Hemogram|Biyokimya|Hormonlar|Vitaminler|Lipid|Diğer",` +
    `"ad":"test adı","deger":sayı,"birim":"birim","ref_alt":sayı|null,"ref_ust":sayı|null}]}\n` +
    `Kurallar: yalnızca sayısal sonucu olan testleri al; yüzde ve mutlak değer ayrı ` +
    `satırlarsa ikisini de al; referans aralığı "3.5-5.1" biçimindeyse ref_alt/ref_ust'a ` +
    `böl; tek yönlü referanslar (<200 gibi) için bilinmeyen ucu null bırak; test adlarını ` +
    `raporda yazıldığı gibi koru. Rapor tahlil raporu değilse boş "testler" dön.`;
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
    {
      method: "POST",
      headers: { "x-goog-api-key": key, "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{
          parts: [
            { inline_data: { mime_type: "application/pdf", data: pdfB64 } },
            { text: prompt },
          ],
        }],
        generationConfig: {
          temperature: 0,
          responseMimeType: "application/json",
          maxOutputTokens: 16384,
          thinkingConfig: { thinkingBudget: 1024 },
        },
      }),
    },
  );
  if (!res.ok) throw new Error(`Gemini ${res.status}`);
  const data = await res.json();
  const cand = data?.candidates?.[0];
  if (cand?.finishReason && cand.finishReason !== "STOP") {
    throw new Error(`Model cevabı tamamlanmadı: ${cand.finishReason}`);
  }
  return JSON.parse(cand?.content?.parts?.at(-1)?.text ?? "{}") as AiReport;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const auth = req.headers.get("Authorization") ?? "";
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { data: userData } = await admin.auth.getUser(auth.replace("Bearer ", ""));
    const user = userData?.user;
    if (!user) return bad(401, "Oturum bulunamadı.");

    const body = await req.json().catch(() => ({}));
    const pdf = String(body.pdf ?? "");
    const pdfPath = String(body.pdf_path ?? "");
    if (!pdf) return bad(400, "PDF verisi eksik.");
    if (pdf.length > 14_000_000) return bad(400, "PDF 10 MB'dan büyük.");

    // Kota sunucuda — bir hata döngüsü Gemini bütçesini yakamaz.
    const today = new Date().toISOString().slice(0, 10);
    const { count } = await admin.from("ai_usage_log")
      .select("id", { count: "exact", head: true })
      .eq("user_id", user.id).eq("kind", "blood_pdf")
      .gte("created_at", `${today}T00:00:00Z`);
    if ((count ?? 0) >= DAILY_QUOTA) {
      return bad(429, "Bugünlük tahlil okuma hakkın doldu — yarın tekrar dene.");
    }
    await admin.from("ai_usage_log").insert({ user_id: user.id, kind: "blood_pdf" });

    const report = await geminiParse(pdf);
    const tests = (report.testler ?? []).filter((t) =>
      t.ad && typeof t.deger === "number" && isFinite(t.deger));
    if (!tests.length) {
      return bad(422, "Bu PDF'te okunabilir test değeri bulunamadı. Dosya yine de Belgelerim'de.");
    }

    const takenAt = /^\d{4}-\d{2}-\d{2}$/.test(report.tarih ?? "")
      ? report.tarih! : today;

    // Aynı tarihli rapor yeniden yüklenirse çiftlenmesin: önce temizle.
    await admin.from("blood_tests").delete()
      .eq("user_id", user.id).eq("taken_at", takenAt);

    const rows = tests.slice(0, 120).map((t) => ({
      user_id: user.id,
      taken_at: takenAt,
      lab: report.lab ?? null,
      group_name: t.grup ?? "Diğer",
      name: String(t.ad).slice(0, 80),
      value: t.deger,
      unit: String(t.birim ?? "").slice(0, 20),
      ref_low: typeof t.ref_alt === "number" ? t.ref_alt : null,
      ref_high: typeof t.ref_ust === "number" ? t.ref_ust : null,
      pdf_path: pdfPath || null,
    }));
    const { error } = await admin.from("blood_tests").insert(rows);
    if (error) return bad(500, "Değerler kaydedilemedi — tekrar dene.");

    return new Response(JSON.stringify({
      count: rows.length, taken_at: takenAt, lab: report.lab ?? null,
    }), { headers: { ...CORS, "Content-Type": "application/json" } });
  } catch (e) {
    return bad(500, `Okunamadı: ${e instanceof Error ? e.message : e}`);
  }
});
