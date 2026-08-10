// Kullanıcı tanımlı yiyecek — sunucu denetimli ekleme (US-029 devamı).
//
// Katalog ORTAK (0028): denetimsiz giriş herkesi etkiler. Bu yüzden ekleme
// doğrudan tabloya değil buradan yapılır (0029 istemci insert'ini kapattı):
//   1. Temel doğrulama (uzunluk, sayısal aralıklar).
//   2. Küfür/hakaret filtresi (kelime listesi — anında, ücretsiz).
//   3. Gemini kısa kontrolü: gerçek bir yiyecek adı mı, kalori porsiyona
//      göre makul mü, ad düzgün yazımla nasıl olur? (AI erişilemezse temel
//      denetimlerle devam edilir — fail-open; küfür filtresi her durumda.)
//   4. Günlük kota sunucuda sayılır (ai_usage_log, kind='food_check').

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const MODEL = Deno.env.get("MEAL_AI_MODEL") ?? "gemini-3.5-flash";
const DAILY_QUOTA = Number(Deno.env.get("FOOD_CREATE_DAILY_QUOTA") ?? "20");

// Yaygın Türkçe küfür/hakaret kökleri — AI'a hiç gitmeden reddedilir.
// Ad sadeleştirilmiş biçimde (searchKey) tarandığı için büyük/küçük harf
// ve Türkçe karakter oyunları işe yaramaz.
//
// İki liste: SÖZCÜK BAŞI eşleşenler ek alabilir ("sikerim"); ama masum
// kelimelerin İÇİNE denk gelmemeli ("fıstık" → "fistik" içinde "sik" var,
// kelime başında değil). TAM SÖZCÜK olanlar masum kelimelerin öneki
// olabilir ("mal" → "malzeme"), yalnız tek başına geçince yakalanır.
const BANNED_PREFIXES = [
  "sik", "yarra", "yarak", "orospu", "pic", "amcik", "ibne", "pezevenk",
  "kahpe", "kaltak", "surtuk", "salak", "aptal", "gerizekal", "sicti", "sictim",
];
const BANNED_WORDS = ["amk", "aq", "mal", "got", "bok", "am"];

function searchKey(text: string): string {
  const map: Record<string, string> = {
    "İ": "i", "I": "i", "ı": "i", "Ş": "s", "ş": "s", "Ğ": "g", "ğ": "g",
    "Ü": "u", "ü": "u", "Ö": "o", "ö": "o", "Ç": "c", "ç": "c", "Â": "a", "â": "a",
  };
  return [...text].map((c) => map[c] ?? c).join("").toLowerCase().trim();
}

function bad(status: number, error: string): Response {
  return new Response(JSON.stringify({ error }), {
    status, headers: { ...CORS, "Content-Type": "application/json" },
  });
}

interface AiVerdict { gecerli: boolean; sebep?: string; ad?: string }

async function geminiCheck(name: string, portionName: string,
                           grams: number, kcal: number): Promise<AiVerdict | null> {
  const key = Deno.env.get("GEMINI_API_KEY");
  if (!key) return null;
  const prompt =
    `Bir sağlık uygulamasının ortak yemek kataloğuna kullanıcı şu kaydı eklemek istiyor:\n` +
    `ad: "${name}" · porsiyon: 1 ${portionName} = ${grams} g · ${kcal} kcal\n\n` +
    `Değerlendir ve SADECE JSON dön: {"gecerli": bool, "sebep": "kısa Türkçe açıklama", "ad": "düzgün yazımla ad"}\n` +
    `Kurallar: gerçek bir yiyecek/içecek adı olmalı (yemek olmayan şey, küfür, hakaret, ` +
    `rastgele harfler, kişi adı, şaka reddedilir). Kalori yoğunluğu kabaca 0-9 kcal/g ` +
    `aralığında makul olmalı (su/çay 0 olabilir; saf yağ ~9). "ad" alanında adı doğru ` +
    `Türkçe yazımla, baş harfi büyük döndür (örn "hindi fume" → "Hindi füme").`;
  try {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
      {
        method: "POST",
        headers: { "x-goog-api-key": key, "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0,
            responseMimeType: "application/json",
            maxOutputTokens: 1024,
            thinkingConfig: { thinkingBudget: 256 },
          },
        }),
      },
    );
    if (!res.ok) return null;
    const data = await res.json();
    const cand = data?.candidates?.[0];
    if (cand?.finishReason && cand.finishReason !== "STOP") return null;
    const text = cand?.content?.parts?.at(-1)?.text ?? "";
    return JSON.parse(text) as AiVerdict;
  } catch {
    return null;   // AI erişilemedi — temel denetimlerle devam (fail-open)
  }
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
    const name = String(body.name ?? "").trim();
    const portionName = String(body.portion_name ?? "porsiyon").trim() || "porsiyon";
    const grams = Math.round(Number(body.portion_g) || 0);
    const kcal = Math.round(Number(body.portion_kcal) || 0);

    // 1 · Temel doğrulama.
    if (name.length < 2 || name.length > 60) return bad(400, "Ad 2-60 karakter olmalı.");
    if (portionName.length > 20) return bad(400, "Porsiyon adı çok uzun.");
    if (grams < 1 || grams > 2000) return bad(400, "Porsiyon gramı 1-2000 aralığında olmalı.");
    if (kcal < 0 || kcal > 2000) return bad(400, "Porsiyon kalorisi 0-2000 aralığında olmalı.");
    const density = kcal / grams;
    if (density > 9.5) return bad(400, "Kalori porsiyona göre gerçekçi değil (gram başına 9 kcal'yi aşıyor).");

    // 2 · Küfür filtresi — sadeleştirilmiş ad üzerinde.
    const key = searchKey(name);
    const padded = ` ${key} `;
    const profane = BANNED_PREFIXES.some((f) => padded.includes(` ${f}`))
      || BANNED_WORDS.some((f) => padded.includes(` ${f} `));
    if (profane) return bad(400, "Bu ad kataloğa uygun değil.");

    // 3 · Kota (sunucuda — istemciden aşılamaz).
    const today = new Date().toISOString().slice(0, 10);
    const { count } = await admin.from("ai_usage_log")
      .select("id", { count: "exact", head: true })
      .eq("user_id", user.id).eq("kind", "food_check")
      .gte("created_at", `${today}T00:00:00Z`);
    if ((count ?? 0) >= DAILY_QUOTA) {
      return bad(429, "Bugünlük yeni yiyecek ekleme hakkın doldu — yarın tekrar dene.");
    }

    // 4 · AI kontrolü.
    const verdict = await geminiCheck(name, portionName, grams, kcal);
    if (verdict && !verdict.gecerli) {
      return bad(400, verdict.sebep || "Bu kayıt kataloğa uygun görünmüyor.");
    }
    const finalName = (verdict?.ad ?? "").trim() || name;
    const finalKey = searchKey(finalName);

    await admin.from("ai_usage_log").insert({ user_id: user.id, kind: "food_check" });

    // 5 · Ekle — aynı ad varsa mevcut kaydı dön (katalog ortak).
    const kcal100 = Math.round((kcal * 100) / grams);
    const columns = "id,name,kcal_100g,portion_g,portion_name";
    const { data: existing } = await admin.from("foods")
      .select(columns).eq("search_key", finalKey).limit(1);
    if (existing?.length) {
      return new Response(JSON.stringify({ food: existing[0], existed: true }), {
        headers: { ...CORS, "Content-Type": "application/json" },
      });
    }
    const { data: inserted, error } = await admin.from("foods").insert({
      name: finalName, search_key: finalKey, category: "diger",
      kcal_100g: kcal100, portion_g: grams, portion_name: portionName,
      created_by: user.id,
    }).select(columns).single();
    if (error) return bad(500, "Kaydedilemedi — tekrar dene.");

    return new Response(JSON.stringify({ food: inserted, existed: false }), {
      headers: { ...CORS, "Content-Type": "application/json" },
    });
  } catch (e) {
    return bad(500, `Beklenmeyen hata: ${e instanceof Error ? e.message : e}`);
  }
});
