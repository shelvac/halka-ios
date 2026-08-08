// US-029 — Yemek fotoğrafından öğün tahmini.
//
// Neden Edge Function:
//   1. Sağlayıcı API anahtarı asla uygulamaya gömülmez — binary'den çıkarılır.
//   2. Günlük kota SUNUCUDA sayılır; uygulamada hata olsa bile aşılamaz ve
//      bir döngü sağlayıcı faturasını patlatamaz.
//   3. Sağlayıcı değişimi tek ortam değişkeni; uygulama kodu bilmiyor.
//
// Kalori AI'dan DEĞİL, kendi `foods` tablomuzdan geliyor. AI yalnızca "ne
// yendi" ve "kaç gram" sorusunu cevaplıyor: aynı yemeğe her çağrıda farklı
// kalori vermesi tutarsızlık üretirdi. Eşleşme bulunamazsa AI'ın kendi
// tahmini kullanılıyor ve bu kullanıcıya `matched: false` ile bildiriliyor.
//
// Fotoğraf SAKLANMIYOR (KVKK): işlenir, cevap döner, atılır. Arka planda
// yüz, ev, başka kişiler olabilir. Öğrenme için yalnızca metin çifti
// (AI tahmini ↔ kullanıcı düzeltmesi) `meal_photo_log`'da tutuluyor.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const PROVIDER = Deno.env.get("MEAL_AI_PROVIDER") ?? "gemini";
const MODEL = Deno.env.get("MEAL_AI_MODEL") ?? "gemini-3.5-flash";
const DAILY_QUOTA = Number(Deno.env.get("MEAL_AI_DAILY_QUOTA") ?? "3");

const PROMPT = `Bu bir yemek fotoğrafı. Türkiye'de yaygın yemekleri tanıyorsun.

Görevin: tabaktaki her ayrı yiyeceği ve içeceği tespit et, her biri için
gerçekçi bir gram miktarı tahmin et.

Kurallar:
- Yemek adlarını TÜRKÇE ve yaygın kullanılan hâliyle yaz ("bulgur pilavı",
  "ızgara köfte", "cacık"). Marka adı yazma.
- Karışık tabağı bileşenlerine ayır: "pilav üstü tavuk" yerine ayrı ayrı
  "pirinç pilavı" ve "tavuk sote" gibi.
- Gram tahmininde tabak, çatal, bardak gibi referansları kullan. Emin
  değilsen Türkiye'deki tipik porsiyonu esas al.
- Görselde yemek yoksa items boş dizi dönsün.
- confidence: 0-1 arası, tanımadaki güvenin.
- kcal_estimate: yalnızca yedek olarak kullanılacak, o miktar için toplam
  kalori tahminin.
- Uydurma. Göremediğin bir şeyi ekleme.`;

const SCHEMA = {
  type: "object",
  properties: {
    items: {
      type: "array",
      items: {
        type: "object",
        properties: {
          name: { type: "string" },
          grams: { type: "number" },
          kcal_estimate: { type: "number" },
          confidence: { type: "number" },
        },
        required: ["name", "grams", "kcal_estimate", "confidence"],
      },
    },
    note: { type: "string" },
  },
  required: ["items"],
};

type AiItem = { name: string; grams: number; kcal_estimate: number; confidence: number };

/// Türkçe'ye özel sadeleştirme. `toLowerCase()` yetmiyor: "İ" harfi
/// "i" + birleşik nokta üretiyor ve hiçbir kayda eşleşmiyor.
function searchKey(text: string): string {
  const map: Record<string, string> = {
    "İ": "i", "I": "i", "ı": "i", "Ş": "s", "ş": "s", "Ğ": "g", "ğ": "g",
    "Ü": "u", "ü": "u", "Ö": "o", "ö": "o", "Ç": "c", "ç": "c", "Â": "a", "â": "a",
  };
  return [...text].map((c) => map[c] ?? c).join("").toLowerCase().trim();
}

async function callGemini(imageB64: string, mime: string): Promise<{ items: AiItem[]; note?: string }> {
  const key = Deno.env.get("GEMINI_API_KEY");
  if (!key) throw new Error("GEMINI_API_KEY tanımlı değil");
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
    {
      method: "POST",
      headers: { "x-goog-api-key": key, "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{
          parts: [{ text: PROMPT }, { inline_data: { mime_type: mime, data: imageB64 } }],
        }],
        generationConfig: {
          responseMimeType: "application/json",
          responseSchema: SCHEMA,
          // Düşünen modeller bütçenin bir kısmını akıl yürütmeye harcıyor;
          // dar bir sınır cevabı yarıda kesiyordu.
          maxOutputTokens: 4096,
        },
      }),
    },
  );
  const body = await res.json();
  if (!res.ok) throw new Error(body?.error?.message ?? `Gemini ${res.status}`);
  const text = (body?.candidates?.[0]?.content?.parts ?? [])
    .map((p: { text?: string }) => p.text ?? "").join("");
  if (!text) throw new Error("Model boş cevap döndü");
  return JSON.parse(text);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  const started = Date.now();

  try {
    const auth = req.headers.get("Authorization") ?? "";
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { data: userData } = await admin.auth.getUser(auth.replace("Bearer ", ""));
    const user = userData?.user;
    if (!user) {
      return new Response(JSON.stringify({ error: "Oturum bulunamadı." }), {
        status: 401, headers: { ...CORS, "Content-Type": "application/json" },
      });
    }

    // Kota — uygulamaya güvenilmez, burada sayılır.
    const { data: used } = await admin.rpc("meal_photo_quota_used", { p_user: user.id });
    if ((used ?? 0) >= DAILY_QUOTA) {
      return new Response(JSON.stringify({
        error: "quota",
        message: `Günlük fotoğraf hakkın doldu (${DAILY_QUOTA}). Yarın yenileniyor.`,
        used, quota: DAILY_QUOTA,
      }), { status: 429, headers: { ...CORS, "Content-Type": "application/json" } });
    }

    const { image, mime } = await req.json();
    if (!image) throw new Error("Fotoğraf yok");

    const ai = await callGemini(image, mime ?? "image/jpeg");
    const aiItems: AiItem[] = Array.isArray(ai.items) ? ai.items : [];

    // Kataloğa bağla: kalori bizim tablomuzdan gelsin.
    const items = [];
    for (const item of aiItems) {
      const key = searchKey(String(item.name ?? ""));
      if (!key) continue;
      const grams = Math.max(1, Math.round(Number(item.grams) || 0));

      let { data: rows } = await admin.from("foods")
        .select("id,name,kcal_100g,protein_100g,carb_100g,fat_100g,portion_g,portion_name")
        .eq("search_key", key).limit(1);
      if (!rows?.length) {
        // Tam eşleşme yoksa içeren kayıt ("izgara kofte" → "kofte").
        const r = await admin.from("foods")
          .select("id,name,kcal_100g,protein_100g,carb_100g,fat_100g,portion_g,portion_name")
          .ilike("search_key", `%${key}%`).limit(1);
        rows = r.data ?? [];
      }
      const food = rows?.[0];
      const fallbackKcal = Math.max(0, Math.round(Number(item.kcal_estimate) || 0));
      items.push({
        name: food?.name ?? item.name,
        matched: !!food,
        food_id: food?.id ?? null,
        grams,
        // Eşleşme varsa katalogdan, yoksa AI'ın kendi tahmini.
        kcal: food ? Math.round((food.kcal_100g * grams) / 100) : fallbackKcal,
        // Porsiyon değiştiğinde kaloriyi uygulama yeniden hesaplayabilsin
        // diye 100 g başına değer de gönderiliyor. Eşleşme yoksa AI'ın
        // tahmininden geriye doğru türetiliyor.
        kcal_100g: food
          ? food.kcal_100g
          : (grams > 0 ? Math.round((fallbackKcal * 100) / grams) : 0),
        protein_100g: food?.protein_100g ?? null,
        carb_100g: food?.carb_100g ?? null,
        fat_100g: food?.fat_100g ?? null,
        portion_g: food?.portion_g ?? grams,
        portion_name: food?.portion_name ?? "porsiyon",
        confidence: Math.min(1, Math.max(0, Number(item.confidence) || 0)),
      });
    }

    const latency = Date.now() - started;
    const { data: logged } = await admin.from("meal_photo_log").insert({
      user_id: user.id, provider: PROVIDER, model: MODEL,
      ai_items: aiItems, final_items: items, latency_ms: latency,
    }).select("id").single();

    return new Response(JSON.stringify({
      log_id: logged?.id ?? null,
      items, note: ai.note ?? null,
      used: (used ?? 0) + 1, quota: DAILY_QUOTA, latency_ms: latency,
    }), { headers: { ...CORS, "Content-Type": "application/json" } });
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error?.message ?? error) }), {
      status: 500, headers: { ...CORS, "Content-Type": "application/json" },
    });
  }
});
