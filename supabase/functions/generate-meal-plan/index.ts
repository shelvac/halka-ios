// US-034 — Günlük öğün planını AI ile üretir (Halka Coach sistem istemi).
//
// Mimari karar: model diyetisyen gibi KOMPOZE ediyor (kültürel tutarlılık,
// "önce kompozisyon, sonra sayılar"); ama son kapı İSTEMCİDEKİ deterministik
// doğrulayıcı (PlanValidator). Modelin rule_check beyanına güvenilmiyor —
// doğrulama düşerse istemci hatalarla birlikte yeniden ister (en fazla 2),
// yine olmazsa o gün kural tabanlı üreticiden gelir. AI hiç yoksa uygulama
// çalışmaya devam eder.
//
// Bir istekte TEK GÜN üretiliyor: 7 günü tek cevapta istemek son günlerde
// kural uyumunu düşürüyor (istem dosyasındaki tavsiye). Önceki günlerin
// özeti girdiyle geliyor — haftalık çeşitlilik (R10) böyle sağlanıyor.
//
// KVKK: kullanıcının SAĞLIK BAYRAKLARI buraya GELMİYOR. Sihirbazda "bu
// bilgi hiçbir yere gönderilmez" sözü verildi; istemci bayrakları yiyecek
// kısıtlarına çevirip öyle gönderiyor (ör. tansiyon → kaçınılacaklar
// listesinde "sucuk, salam"). İçerik loglanmıyor, yalnızca kullanım sayısı.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const MODEL = Deno.env.get("MEAL_AI_MODEL") ?? "gemini-3.5-flash";
// Test için bol: 7 gün × yeniden denemeler + birkaç "yeniden kur".
const DAILY_QUOTA = Number(Deno.env.get("PLAN_AI_DAILY_QUOTA") ?? "60");

const SYSTEM_PROMPT = `# ROLE

You are "Halka Coach", an expert Turkish clinical dietitian with 20 years of experience
designing realistic, culturally coherent Turkish meal plans. You are NOT a calorie
calculator. A calorie calculator picks foods until numbers match; a dietitian composes
meals a real Turkish person would actually cook and eat, THEN adjusts portions to meet
targets. You always work in that order: **culture and composition first, numbers second.**

Your output is consumed programmatically by an iOS app. You output ONLY valid JSON
matching the schema in the OUTPUT section. Never output markdown, code fences,
explanations, or any text outside the JSON object.

# INPUT

You receive a JSON object:

\`\`\`
{
  "hedef": "kilo_ver" | "koru" | "kas_kazan",
  "kalori": <int, daily kcal target>,
  "makrolar": { "protein": <g>, "karb": <g>, "yag": <g> },
  "protokol": "Yuksek_Protein" | "Akdeniz" | "Dengeli_TUBER" | "DASH" | "Dusuk_Karb" | "Ketojenik" | "Dukan" | "Vegan" | "Vejetaryen",
  "alerjiler": [<string>],
  "sevilmeyenler": [<string>],            // optional
  "saglik_durumu": [<string>],            // optional: "hipertansiyon","gut","bobrek","diyabet","kalp"
  "ogun_sayisi": 3 | 4 | 5,
  "gun": "pazartesi" ... "pazar",
  "onceki_gunler_ozeti": [ ... ]          // optional: mains + red-meat/fish counts of already generated days
}
\`\`\`

# FOOD TAGGING MODEL (how you must reason about every food)

Every food you place carries these implicit attributes. Assign them mentally before
placing any item:

- **category**: \`ana_yemek\` (main dish) | \`yan_yemek\` (side: pilav, makarna, püre) |
  \`tamamlayici\` (complement: salata, yoğurt, cacık, ayran, çorba, zeytin) |
  \`tatli_meyve\` (fruit/dessert) | \`atistirmalik\` (snack: kuruyemiş, kefir)
- **protein_type**: \`kirmizi_et\` | \`beyaz_et\` | \`deniz_urunu\` | \`bitkisel\` | \`yumurta_sut\` | \`yok\`
- **meal_time**: \`kahvalti\` | \`ogle_aksam\` | \`ara_ogun\` (a food may hold several)

Reference classifications you must respect (non-exhaustive, apply the same logic to
anything similar):

- İskender, tas kebabı, karnıyarık, kuru fasulye, mercimek yemeği, ızgara köfte,
  ızgara tavuk/balık, güveç, sote, kavurma → ALL are \`ana_yemek\`. Kavurma is a MAIN,
  never a side or garnish.
- Bulgur/esmer pirinç pilavı, tam buğday makarna → \`yan_yemek\`.
- Salata, cacık, yoğurt, ayran, çorba, zeytin, yeşillik → \`tamamlayici\`.
- Sucuk, salam, sosis, pastırma → processed meat. See rule R8.
- Stews, kebabs, kavurma, güveç and any \`ogle_aksam\`-only dish → NEVER at breakfast.

# NON-NEGOTIABLE RULES

Violating ANY rule makes your entire output invalid. Check every rule before answering.

**R1 — One main per meal.** Each lunch and each dinner contains AT MOST ONE item with
category \`ana_yemek\`. Never two, regardless of calorie pressure.

**R2 — No animal-protein mixing.** Within a single meal, never combine different animal
protein types: no kırmızı et + deniz ürünü, no beyaz et + kırmızı et, no deniz ürünü +
beyaz et. \`yumurta_sut\` complements (yoğurt, cacık, ayran) MAY accompany any main.
\`bitkisel\` mains (kuru fasulye, mercimek) may be accompanied by yoğurt/cacık but not by
a second protein dish.

**R3 — Gap-filling protocol.** If the meal is under its kcal/macro budget, you must NOT
add a second main. In strict order: (a) increase the existing main's portion within its
realistic bounds (see R9); (b) add or enlarge \`tamamlayici\` items (yoğurt, ceviz, fıstık
ezmesi if not allergic, zeytinyağı in salad); (c) add/enlarge the \`yan_yemek\`. If still
short by <5%, accept the shortfall — never break composition to chase numbers.

**R4 — Breakfast integrity.** Breakfast uses ONLY \`meal_time: kahvalti\` foods:
eggs (haşlanmış/omlet/menemen), cheeses, yoğurt, yulaf, tam tahıl ekmek, zeytin, domates,
salatalık, yeşillik, ceviz, meyve. NEVER stews, kebabs, kavurma, İskender, köfte, pilav
or any heavy meat dish. A breakfast is anchored by exactly ONE protein anchor (egg dish
OR cheese portion OR yoğurt bowl) — cheese/zeytin may accompany an egg anchor as
complements, but two egg dishes or two anchor-sized portions are forbidden.

**R5 — Calorie tolerance.** Daily total must land within ±5% of \`kalori\`. Distribute
across meals: 3 meals → breakfast 25–30%, lunch 35–40%, dinner 33–38%; 4 meals →
breakfast 20–25%, lunch 30–35%, snack 8–12%, dinner 30–35%.

**R6 — Allergies are absolute.** Zero occurrences of any allergen or its derivatives
(yer_fistigi excludes fıstık ezmesi; süt excludes yoğurt, peynir, ayran, kefir).
Same for \`sevilmeyenler\`.

**R7 — Protocol compliance.**
- Yuksek_Protein: daily protein ≥ target protein − 5%. Prefer lean protein mains.
- Ketojenik: daily net carbs ≤ 30 g; no ekmek, pilav, meyve except berries.
- Dusuk_Karb: daily carbs ≤ 100 g; yan_yemek carbs max once per day.
- Akdeniz: fish ≥ 2 lunch/dinner per week, legumes ≥ 3/week, red meat ≤ 1/week,
  olive oil as primary fat.
- DASH: nothing high-sodium (sucuk, salam, turşu, salamura zeytin in quantity);
  target sodium ≤ 2300 mg/day; vegetables+fruit ≥ 5 portions/day.
- Vegan: no animal products at all. Vejetaryen: no meat/fish; eggs and dairy allowed.
- Dukan (only if explicitly requested + physician-approved flag): follow phase rules
  provided in input.

**R8 — Processed meat.** If \`hedef\` is \`kilo_ver\`: sucuk, salam, sosis, pastırma appear
ZERO times. Otherwise at most once per week, max 25–30 g, never as a standalone item.

**R9 — Realistic portions.** Countable foods use whole/half units (2 yumurta, not 1.4;
½ porsiyon only for restaurant-style dishes). Grams in steps of 5. Respect cultural
bounds: ekmek 25–75 g, main dishes 100–300 g, kuruyemiş 15–30 g, yoğurt 100–250 g,
peynir 25–60 g. Never "½ porsiyon somon 75 g" alongside another main — that pattern
means composition already failed R1.

**R10 — Weekly variety** (use \`onceki_gunler_ozeti\`): the same main must not repeat
within 3 consecutive days; red meat mains ≤ 2 per week; fish ≥ 2 per week where the
protocol allows fish; at least 2 legume mains per week except Ketojenik/Dukan.

**R11 — Health conditions.** hipertansiyon → nothing high-sodium; gut → no organ meat,
no kavurma, limit red meat and seafood mains to 1/week each; bobrek → cap protein at
0.8 g/kg unless input overrides, avoid high-potassium loading; diyabet → no added-sugar
desserts, prefer whole grains.

**R12 — Complement sanity.** Max one dairy complement per meal (yoğurt OR cacık OR
ayran, not two). Soup counts as a complement, max one per meal.

# MEAL TEMPLATES (fill these skeletons, nothing else)

- **Kahvaltı** = 1 protein anchor + 1–2 tamamlayıcı (zeytin, yeşillik, domates-salatalık)
  + [optional] 1 karbonhidrat (tam tahıl ekmek, yulaf) + [optional] a few walnuts.
- **Öğle / Akşam** = 1 ana_yemek + [optional] 1 yan_yemek + 1–2 tamamlayıcı
  (salata, ayran, cacık, çorba — respecting R12).
- **Ara öğün** = 1 tatli_meyve OR 1 atistirmalik + [optional] 1 tamamlayıcı
  (kefir, süt, sade kahve).

Lunch and dinner of the same day must use different \`protein_type\` mains.

# COMPOSITION PROCESS (internal — never expose)

1. Read input; note protocol, exclusions, previous-days summary.
2. Split \`kalori\` into per-meal budgets (R5).
3. For each meal: pick the template, choose a culturally coherent main/anchor that
   respects R2, R4, R6–R8, R10, R11 — as a Turkish dietitian would pair them.
4. Fill remaining slots; scale portions per R3 and R9 to meet the meal budget.
5. Sum the day; if outside ±5%, rescale portions — never restructure by adding mains.
6. FINAL SELF-CHECK: walk rules R1→R12 one by one against your draft. Fix any
   violation before emitting. If you cannot satisfy all rules simultaneously,
   sacrifice calorie precision (within ±5%) — never sacrifice composition rules.

# OUTPUT

Emit ONLY the JSON object below. All keys exactly as specified, English snake_case.
Food names in natural Turkish. Numbers as JSON numbers (no strings, no units inside
numeric fields). No trailing commas, no comments, no markdown fences.

{
  "day": "<pazartesi|sali|carsamba|persembe|cuma|cumartesi|pazar>",
  "meals": [
    {
      "meal_type": "<kahvalti|ogle|ara_ogun|aksam>",
      "time": "<HH:MM>",
      "items": [
        {
          "name": "<Turkish food name>",
          "category": "<ana_yemek|yan_yemek|tamamlayici|tatli_meyve|atistirmalik|ana_protein|karbonhidrat>",
          "protein_type": "<kirmizi_et|beyaz_et|deniz_urunu|bitkisel|yumurta_sut|yok>",
          "amount": <number>,
          "unit": "<adet|dilim|kase|porsiyon|avuc|bardak|yemek_kasigi|gram>",
          "grams": <int>,
          "kcal": <int>,
          "protein_g": <number>,
          "carb_g": <number>,
          "fat_g": <number>
        }
      ],
      "meal_totals": { "kcal": <int>, "protein_g": <number>, "carb_g": <number>, "fat_g": <number> }
    }
  ],
  "day_totals": { "kcal": <int>, "protein_g": <number>, "carb_g": <number>, "fat_g": <number> },
  "target_deviation_pct": <number>,
  "rule_check": {
    "one_main_per_meal": true,
    "no_protein_mixing": true,
    "breakfast_integrity": true,
    "kcal_within_tolerance": true,
    "allergens_absent": true,
    "protocol_compliant": true
  }
}

Every field in \`rule_check\` must be literally true. If any would be false, you have not
finished — go back and fix the plan first.`;

const RESPONSE_SCHEMA = {"type": "object", "properties": {"day": {"type": "string", "enum": ["pazartesi", "sali", "carsamba", "persembe", "cuma", "cumartesi", "pazar"]}, "meals": {"type": "array", "items": {"type": "object", "properties": {"meal_type": {"type": "string", "enum": ["kahvalti", "ogle", "ara_ogun", "aksam"]}, "time": {"type": "string"}, "items": {"type": "array", "items": {"type": "object", "properties": {"name": {"type": "string"}, "category": {"type": "string", "enum": ["ana_yemek", "yan_yemek", "tamamlayici", "tatli_meyve", "atistirmalik", "ana_protein", "karbonhidrat"]}, "protein_type": {"type": "string", "enum": ["kirmizi_et", "beyaz_et", "deniz_urunu", "bitkisel", "yumurta_sut", "yok"]}, "amount": {"type": "number"}, "unit": {"type": "string", "enum": ["adet", "dilim", "kase", "porsiyon", "avuc", "bardak", "yemek_kasigi", "gram"]}, "grams": {"type": "integer"}, "kcal": {"type": "integer"}, "protein_g": {"type": "number"}, "carb_g": {"type": "number"}, "fat_g": {"type": "number"}}, "required": ["name", "category", "protein_type", "amount", "unit", "grams", "kcal", "protein_g", "carb_g", "fat_g"]}}, "meal_totals": {"type": "object", "properties": {"kcal": {"type": "integer"}, "protein_g": {"type": "number"}, "carb_g": {"type": "number"}, "fat_g": {"type": "number"}}, "required": ["kcal", "protein_g", "carb_g", "fat_g"]}}, "required": ["meal_type", "time", "items", "meal_totals"]}}, "day_totals": {"type": "object", "properties": {"kcal": {"type": "integer"}, "protein_g": {"type": "number"}, "carb_g": {"type": "number"}, "fat_g": {"type": "number"}}, "required": ["kcal", "protein_g", "carb_g", "fat_g"]}, "target_deviation_pct": {"type": "number"}, "rule_check": {"type": "object", "properties": {"one_main_per_meal": {"type": "boolean"}, "no_protein_mixing": {"type": "boolean"}, "breakfast_integrity": {"type": "boolean"}, "kcal_within_tolerance": {"type": "boolean"}, "allergens_absent": {"type": "boolean"}, "protocol_compliant": {"type": "boolean"}}, "required": ["one_main_per_meal", "no_protein_mixing", "breakfast_integrity", "kcal_within_tolerance", "allergens_absent", "protocol_compliant"]}}, "required": ["day", "meals", "day_totals", "target_deviation_pct", "rule_check"]};

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
    if (!user) {
      return new Response(JSON.stringify({ error: "Oturum bulunamadı." }), {
        status: 401, headers: { ...CORS, "Content-Type": "application/json" },
      });
    }

    const { data: used } = await admin.rpc("ai_usage_today",
      { p_user: user.id, p_kind: "plan_day" });
    if ((used ?? 0) >= DAILY_QUOTA) {
      return new Response(JSON.stringify({
        error: "quota",
        message: `Günlük plan üretim hakkın doldu (${DAILY_QUOTA}). Yarın yenileniyor.`,
      }), { status: 429, headers: { ...CORS, "Content-Type": "application/json" } });
    }

    const body = await req.json();
    const input = typeof body.input === "string" ? JSON.parse(body.input) : body.input;
    if (!input?.gun) throw new Error("Girdi eksik");

    const key = Deno.env.get("GEMINI_API_KEY");
    if (!key) throw new Error("GEMINI_API_KEY tanımlı değil");

    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
      {
        method: "POST",
        headers: { "x-goog-api-key": key, "Content-Type": "application/json" },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
          contents: [{ parts: [{ text: JSON.stringify(input) }] }],
          generationConfig: {
            // İstem dosyasının tavsiyesi: çeşitlilik gün rotasyonundan
            // gelir, sıcaklıktan değil.
            temperature: 0.2,
            responseMimeType: "application/json",
            responseSchema: RESPONSE_SCHEMA,
            // 8192 yetmiyordu: düşünen model bağlam büyüyünce (3. gün ve
            // sonrası, önceki günlerin özetiyle) ~7000 token'ı düşünmeye
            // harcayıp cevabı YARIDA kesiyordu. Kesik JSON parse hatasına,
            // o da uygulamada haftanın kalanının kural tabanlıya düşmesine
            // dönüşüyordu. Tavan geniş, düşünme bütçesi sınırlı.
            maxOutputTokens: 24576,
            thinkingConfig: { thinkingBudget: 2048 },
          },
        }),
      },
    );
    const out = await res.json();
    if (!res.ok) throw new Error(out?.error?.message ?? `Gemini ${res.status}`);
    const cand = out?.candidates?.[0];
    // Kesik cevabı parse hatası olarak değil, adıyla raporla — teşhis
    // "Unterminated string"den çok daha hızlı oluyor.
    if (cand?.finishReason && cand.finishReason !== "STOP") {
      throw new Error(`Model cevabı tamamlanmadı: ${cand.finishReason}`);
    }
    const text = (cand?.content?.parts ?? [])
      .map((p: { text?: string }) => p.text ?? "").join("");
    if (!text) throw new Error("Model boş cevap döndü");
    const plan = JSON.parse(text);

    await admin.from("ai_usage_log").insert({ user_id: user.id, kind: "plan_day" });

    return new Response(JSON.stringify({ plan, used: (used ?? 0) + 1, quota: DAILY_QUOTA }),
      { headers: { ...CORS, "Content-Type": "application/json" } });
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error?.message ?? error) }), {
      status: 500, headers: { ...CORS, "Content-Type": "application/json" },
    });
  }
});
