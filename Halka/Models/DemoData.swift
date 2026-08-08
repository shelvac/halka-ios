import Foundation

/// Demo content ported verbatim from the Claude Design prototype.
enum Demo {

    // MARK: Calendar / rings

    /// Fractions [exercise, water, sleep, nutrition] for past August days.
    static let history: [Int: [Double]] = [
        1: [0.55, 0.8, 0.9, 0.7],
        2: [1, 0.62, 0.78, 0.95],
        3: [0.42, 1, 0.82, 0.6],
        4: [0.15, 0.25, 0.45, 0.3]
    ]

    static let dayNamesShort = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
    static let dayNamesFull = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"]
    static let mealLabels = ["Sabah", "Öğle", "İkindi", "Akşam"]

    // MARK: Weekly menus (7 days × 4 meals)

    static let menus: [[String]] = [
        ["Yulaf + yoğurt + meyve", "Izgara tavuk + bulgur + salata", "Badem + 1 meyve", "Fırında somon + sebze"],
        ["Menemen + tam buğday ekmek", "Mercimek çorbası + köfte", "Yoğurt + ceviz", "Sebzeli tavuk sote"],
        ["Lor peyniri + yumurta + yeşillik", "Ton balıklı salata", "Meyve + fındık", "Fırın levrek + roka"],
        ["Yumurta + avokado", "Nohut salatası + peynir", "Kefir + tarçın", "Izgara hindi + sebze"],
        ["Yulaf + meyve", "Tavuk dürüm (tam buğday)", "Badem + kuru kayısı", "Sebze güveç + yoğurt"],
        ["Serbest kahvaltı", "Çorba + salata", "Yoğurt + meyve", "Izgara balık"],
        ["Yulaf pancake", "Aile öğünü (porsiyon kontrol)", "Ceviz + meyve", "Hafif: yoğurt + salata"]
    ]

    static let recipes: [String: Recipe] = [
        "Yulaf + yoğurt + meyve": Recipe(kcal: 320, ingredients: ["40 g yulaf ezmesi", "150 g süzme yoğurt", "1 küçük muz veya yarım elma", "1 tk bal", "Tarçın"], steps: ["Yulafı yoğurtla karıştır, 5 dk beklet", "Meyveyi doğrayıp üzerine ekle", "Bal ve tarçınla tatlandır"]),
        "Izgara tavuk + bulgur + salata": Recipe(kcal: 450, ingredients: ["150 g tavuk göğsü", "4 yk haşlanmış bulgur", "Domates, salatalık, maydanoz", "1 yk zeytinyağı", "Limon ve baharatlar"], steps: ["Tavuğu baharatla 10 dk marine et", "Izgarada veya tavada her yüzünü 5-6 dk pişir", "Bulguru haşlayıp dinlendir", "Salatayı doğra, zeytinyağı-limonla harmanla"]),
        "Badem + 1 meyve": Recipe(kcal: 150, ingredients: ["10-12 çiğ badem", "1 orta boy elma"], steps: ["Porsiyonla ve ara öğün olarak tüket"]),
        "Fırında somon + sebze": Recipe(kcal: 430, ingredients: ["150 g somon fileto", "Kabak, havuç, kırmızı biber", "1 yk zeytinyağı", "Limon ve dereotu"], steps: ["Fırını 200°C ısıt", "Somon ve doğranmış sebzeleri tepsiye yerleştir", "Zeytinyağı ve limon gezdir", "20-25 dk pişir, dereotuyla servis et"]),
        "Menemen + tam buğday ekmek": Recipe(kcal: 340, ingredients: ["2 yumurta", "2 domates, 1 sivri biber", "1 tk zeytinyağı", "1 dilim tam buğday ekmek"], steps: ["Biberi zeytinyağında 2 dk sotele", "Rendelenmiş domatesi ekle, suyunu çektir", "Yumurtaları kır, karıştırarak pişir"]),
        "Mercimek çorbası + köfte": Recipe(kcal: 460, ingredients: ["1 kase mercimek çorbası", "120 g yağsız kıyma", "Soğan, maydanoz, baharat", "Yanına yeşillik"], steps: ["Köfte harcını yoğur, 15 dk dinlendir", "Izgarada veya fırında pişir", "Çorbayı ısıt, birlikte servis et"]),
        "Ton balıklı salata": Recipe(kcal: 400, ingredients: ["1 kutu ton balığı (suda)", "Marul, roka, mısır", "5-6 zeytin", "1 yk zeytinyağı + limon"], steps: ["Yeşillikleri yıka ve doğra", "Süzülmüş tonu ve mısırı ekle", "Zeytinyağı-limon sosuyla karıştır"]),
        "Tavuk dürüm (tam buğday)": Recipe(kcal: 470, ingredients: ["1 tam buğday lavaş", "120 g tavuk göğsü", "Marul, domates, söğüş soğan", "1 yk yoğurtlu sos"], steps: ["Tavuğu julyen doğrayıp sotele", "Lavaşa sos sür, malzemeleri diz", "Sıkıca sar, ikiye kes"]),
        "Yoğurt + ceviz": Recipe(kcal: 160, ingredients: ["150 g yoğurt", "2 adet ceviz içi", "Tarçın"], steps: ["Cevizi kır, yoğurdun üzerine ekle", "Tarçın serp"]),
        "Kefir + tarçın": Recipe(kcal: 140, ingredients: ["1 bardak kefir", "Tarçın"], steps: ["Kefire tarçın ekleyip iç"]),
        "Fırın levrek + roka": Recipe(kcal: 420, ingredients: ["1 orta boy levrek", "Bir demet roka", "Limon, zeytinyağı", "Sarımsak, kekik"], steps: ["Fırını 190°C ısıt", "Levreği limon-sarımsakla ovala", "25 dk pişir, rokayla servis et"]),
        "Sebzeli tavuk sote": Recipe(kcal: 440, ingredients: ["150 g tavuk göğsü", "Kabak, biber, mantar", "1 yk zeytinyağı", "Soya sosu (az sodyumlu)"], steps: ["Tavuğu kuşbaşı doğra, sotele", "Sebzeleri ekle, 8-10 dk yüksek ateşte karıştır", "Soya sosuyla tatlandır"]),
        "Izgara hindi + sebze": Recipe(kcal: 430, ingredients: ["150 g hindi göğsü", "Brokoli, havuç", "1 yk zeytinyağı", "Baharatlar"], steps: ["Hindiyi baharatla marine et", "Izgarada pişir", "Sebzeleri buharda haşla, birlikte servis et"]),
        "Lor peyniri + yumurta + yeşillik": Recipe(kcal: 310, ingredients: ["3 yk lor peyniri", "1 haşlanmış yumurta", "Roka, maydanoz", "Tam buğday ekmek (1 dilim)"], steps: ["Yumurtayı 8 dk haşla", "Loru yeşillikle karıştır", "Ekmekle birlikte tabakla"]),
        "Yulaf pancake": Recipe(kcal: 330, ingredients: ["40 g yulaf", "1 yumurta", "Yarım muz", "Tarçın, 1 tk bal"], steps: ["Tüm malzemeyi blenderdan geçir", "Yağsız tavada iki yüzünü pişir", "Bal ve tarçınla servis et"]),
        "Meyve + fındık": Recipe(kcal: 150, ingredients: ["1 porsiyon mevsim meyvesi", "8-10 fındık"], steps: ["Porsiyonla ve ara öğün olarak tüket"])
    ]

    /// Fallback kcal per meal slot when a dish has no explicit recipe.
    static let fallbackKcal = [320, 450, 150, 430]

    /// Catalog: (group name, meal slot, dishes).
    static let catalog: [(String, Int, [String])] = [
        ("Kahvaltı", 0, ["Yulaf + yoğurt + meyve", "Menemen + tam buğday ekmek", "Lor peyniri + yumurta + yeşillik", "Yulaf pancake"]),
        ("Öğle", 1, ["Izgara tavuk + bulgur + salata", "Ton balıklı salata", "Mercimek çorbası + köfte", "Tavuk dürüm (tam buğday)"]),
        ("Ara öğün", 2, ["Badem + 1 meyve", "Yoğurt + ceviz", "Kefir + tarçın", "Meyve + fındık"]),
        ("Akşam", 3, ["Fırında somon + sebze", "Fırın levrek + roka", "Sebzeli tavuk sote", "Izgara hindi + sebze"])
    ]

    /// Rotating fake Vision AI estimates.

    // MARK: Health

    static let bodyMetrics: [BodyMetric] = [
        BodyMetric(name: "Yağ", value: "35.7", unit: "%", status: "Yüksek"),
        BodyMetric(name: "Vücut Yağ Ağırlığı", value: "25.8", unit: "kg", status: "Yüksek"),
        BodyMetric(name: "İskelet Kası", value: "36.2", unit: "%", status: "Mükemmel"),
        BodyMetric(name: "İskelet Kası Ağırlığı", value: "26.1", unit: "kg", status: "Mükemmel"),
        BodyMetric(name: "Kas", value: "59.8", unit: "%", status: "Mükemmel"),
        BodyMetric(name: "Kas Ağırlığı", value: "43.1", unit: "kg", status: "Mükemmel"),
        BodyMetric(name: "Viseral Yağ", value: "7.0", unit: "", status: "Sağlıklı"),
        BodyMetric(name: "Su", value: "47.0", unit: "%", status: "Düşük"),
        BodyMetric(name: "Vücut Sıvı Ağırlığı", value: "33.9", unit: "kg", status: "Düşük"),
        BodyMetric(name: "Metabolizma", value: "1420", unit: "kcal/gün", status: "Yüksek"),
        BodyMetric(name: "Obezite Derecesi", value: "25.3", unit: "%", status: "Hafif"),
        BodyMetric(name: "Kemik Kütlesi", value: "3.2", unit: "kg", status: "Mükemmel"),
        BodyMetric(name: "Protein", value: "12.8", unit: "%", status: "Düşük"),
        BodyMetric(name: "Yağsız Vücut Ağırlığı", value: "46.4", unit: "kg", status: "—")
    ]

    static let bloodGroups: [BloodGroup] = [
        BloodGroup(name: "Biyokimya", tests: [
            BloodTest(name: "Açlık kan şekeri (Glukoz)", value: 83, unit: "mg/dl", refLow: 74, refHigh: 105),
            BloodTest(name: "Total kolesterol", value: 185, unit: "mg/dL", refLow: 50, refHigh: 200),
            BloodTest(name: "LDL kolesterol", value: 92, unit: "mg/dL", refLow: 50, refHigh: 130),
            BloodTest(name: "HDL kolesterol", value: 65, unit: "mg/dL", refLow: 50, refHigh: 100),
            BloodTest(name: "Trigliserid", value: 56, unit: "mg/dL", refLow: 0, refHigh: 150),
            BloodTest(name: "Kreatinin", value: 0.61, unit: "mg/dL", refLow: 0.5, refHigh: 1.2),
            BloodTest(name: "Üre nitrojeni (BUN)", value: 34, unit: "mg/dL", refLow: 12.8, refHigh: 45),
            BloodTest(name: "Ürik asit", value: 3.9, unit: "mg/dL", refLow: 2.7, refHigh: 6.1)
        ]),
        BloodGroup(name: "Hormonlar", tests: [
            BloodTest(name: "TSH", value: 2.07, unit: "uIU/mL", refLow: 0.35, refHigh: 4.94),
            BloodTest(name: "Serbest T4 (FT4)", value: 0.97, unit: "ng/dL", refLow: 0.7, refHigh: 1.48)
        ]),
        BloodGroup(name: "Hemogram", tests: [
            BloodTest(name: "Hemoglobin (HGB)", value: 13.6, unit: "g/dL", refLow: 11.6, refHigh: 15),
            BloodTest(name: "Hematokrit (HCT)", value: 40.8, unit: "%", refLow: 37, refHigh: 47),
            BloodTest(name: "Lökosit (WBC)", value: 5.79, unit: "10³/uL", refLow: 4, refHigh: 10),
            BloodTest(name: "Eritrosit (RBC)", value: 4.61, unit: "10⁶/uL", refLow: 3.5, refHigh: 5),
            BloodTest(name: "Trombosit (PLT)", value: 176, unit: "10³/uL", refLow: 130, refHigh: 490),
            BloodTest(name: "MPV", value: 13.3, unit: "fL", refLow: 7.2, refHigh: 11.7)
        ])
    ]

    static let initialSupplements: [Supplement] = [
        Supplement(name: "Vitamin D3", dose: "2000 IU · günde 1", time: "09:30", notify: true, taken: true),
        Supplement(name: "B12", dose: "1000 mcg · günde 1", time: "09:30", notify: true, taken: false),
        Supplement(name: "Demir + Ferritin", dose: "1 tablet · aç karnına", time: "11:00", notify: true, taken: false),
        Supplement(name: "Omega-3", dose: "1000 mg · yemekle", time: "13:30", notify: false, taken: false),
        Supplement(name: "Magnezyum", dose: "300 mg · uyumadan önce", time: "22:00", notify: true, taken: false)
    ]

    // MARK: Workout

    static let exerciseLibrary: [Exercise] = [
        Exercise(name: "Plank", region: "Karın", reps: "2 x 30 sn"),
        Exercise(name: "Crunch", region: "Karın", reps: "12 x"),
        Exercise(name: "Russian Twist", region: "Karın", reps: "12 x"),
        Exercise(name: "Mountain Climber", region: "Karın", reps: "12 x"),
        Exercise(name: "Leg Raise", region: "Karın", reps: "12 x"),
        Exercise(name: "Shoulder Tap", region: "Karın", reps: "12 x"),
        Exercise(name: "Squat", region: "Ön Bacak", reps: "12 x"),
        Exercise(name: "Lunge", region: "Ön Bacak", reps: "10 x"),
        Exercise(name: "Machine Leg Extension", region: "Ön Bacak", reps: "12 x"),
        Exercise(name: "Machine Leg Curl", region: "Arka Bacak", reps: "12 x"),
        Exercise(name: "Romanian Deadlift", region: "Arka Bacak", reps: "10 x"),
        Exercise(name: "Glute Bridge", region: "Kalça", reps: "15 x"),
        Exercise(name: "Hip Thrust", region: "Kalça", reps: "12 x"),
        Exercise(name: "Machine Lat Pulldown", region: "Sırt", reps: "12 x"),
        Exercise(name: "Machine Seated Row", region: "Sırt", reps: "12 x"),
        Exercise(name: "Machine Chest Press", region: "Göğüs", reps: "12 x"),
        Exercise(name: "Push-up", region: "Göğüs", reps: "10 x"),
        Exercise(name: "Machine Pectoral Fly", region: "Göğüs", reps: "12 x"),
        Exercise(name: "Shoulder Press", region: "Omuz", reps: "12 x"),
        Exercise(name: "Biceps Curl", region: "Kol", reps: "12 x")
    ]

    static let regions = ["Tümü", "Karın", "Ön Bacak", "Arka Bacak", "Kalça", "Sırt", "Göğüs", "Omuz", "Kol"]
    static let levels = ["Başlangıç", "Orta", "İleri"]

    static func initialPrograms() -> [WorkoutProgram] {
        [WorkoutProgram(name: "Karın · Başlangıç", region: "Karın", level: "Başlangıç", items: [
            Exercise(name: "Plank", region: "Karın", reps: "2 x 30 sn"),
            Exercise(name: "Crunch", region: "Karın", reps: "12 x"),
            Exercise(name: "Russian Twist", region: "Karın", reps: "12 x"),
            Exercise(name: "Mountain Climber", region: "Karın", reps: "12 x"),
            Exercise(name: "Leg Raise", region: "Karın", reps: "12 x")
        ])]
    }

    // MARK: Social

    static func initialFriends() -> [Friend] {
        [Friend(name: "Elif", points: 940, streak: 15),
         Friend(name: "Merve", points: 820, streak: 9),
         Friend(name: "Can", points: 760, streak: 6),
         Friend(name: "Zeynep", points: 610, streak: 3)]
    }

    /// Challenge progress rows: (name, days completed of 7).
    static let challengeRows: [(String, Int)] = [("Elif", 6), ("Sen", 5), ("Merve", 4)]

    // MARK: Dietitian marketplace

    static let dietitians: [Dietitian] = [
        Dietitian(
            name: "Dyt. Elif Yılmaz", specialty: "Kilo yönetimi · 8 yıl",
            rating: "★ 4.9 · 127 değerlendirme", price: "₺4.800",
            bio: "Hacettepe Beslenme ve Diyetetik mezunu. 8 yıldır sürdürülebilir kilo yönetimi üzerine çalışıyor; yasak listeleri değil, alışkanlık değişimini temel alan programlar hazırlıyor. Danışanlarının halka ve tartı verilerini haftalık olarak birlikte değerlendiriyor.",
            stats: [("8 yıl", "DENEYİM"), ("340+", "DANIŞAN"), ("4.9", "PUAN")],
            reviews: [
                DietitianReview(name: "Merve T.", stars: 5, date: "2 hafta önce", text: "3 ayda 7 kilo verdim, hiç aç kalmadım. Haftalık program değişiklikleri ve mesajla ulaşabilmek çok iyi."),
                DietitianReview(name: "Burak S.", stars: 5, date: "1 ay önce", text: "Tartı ve halka verilerimi görüp programı ona göre güncelliyor. İlk kez bir diyeti bırakmadım."),
                DietitianReview(name: "Aylin K.", stars: 4, date: "2 ay önce", text: "Programlar çok pratik, market listesi süper. Bazen mesaj dönüşü ertesi günü bulabiliyor.")
            ]),
        Dietitian(
            name: "Dyt. Selin Demir", specialty: "Hormonal denge · Hashimoto",
            rating: "★ 5.0 · 89 değerlendirme", price: "₺5.600",
            bio: "Tiroid ve hormonal denge alanında uzman. Hashimoto, insülin direnci ve PCOS danışanlarıyla kan değerlerini takip ederek çalışıyor; programlarını 3 aylık tahlil döngüleriyle güncelliyor.",
            stats: [("11 yıl", "DENEYİM"), ("210+", "DANIŞAN"), ("5.0", "PUAN")],
            reviews: [
                DietitianReview(name: "Zeynep A.", stars: 5, date: "1 hafta önce", text: "Hashimoto tanımdan beri ilk kez kendimi enerjik hissediyorum. Kan değerlerimi tek tek açıklıyor."),
                DietitianReview(name: "Deniz Y.", stars: 5, date: "3 hafta önce", text: "İnsülin direncim 4 ayda normale döndü. Tahlil sonuçlarına göre program güncellemesi harika."),
                DietitianReview(name: "Ece M.", stars: 5, date: "1 ay önce", text: "Çok titiz ve bilimsel. Takviye önerileri için doktorumla da iletişim kurdu.")
            ]),
        Dietitian(
            name: "Dyt. Murat Aksoy", specialty: "Sporcu beslenmesi",
            rating: "★ 4.8 · 214 değerlendirme", price: "₺4.400",
            bio: "Performans ve vücut kompozisyonu odaklı çalışan spor diyetisyeni. Antrenman programına göre periyodize beslenme planları hazırlıyor; kas kütlesi ve yağ oranı hedeflerini aylık ölçümlerle takip ediyor.",
            stats: [("9 yıl", "DENEYİM"), ("520+", "DANIŞAN"), ("4.8", "PUAN")],
            reviews: [
                DietitianReview(name: "Can B.", stars: 5, date: "5 gün önce", text: "Antrenman günlerime göre karbonhidrat ayarlıyor, performansım gözle görülür arttı."),
                DietitianReview(name: "Selin O.", stars: 5, date: "2 hafta önce", text: "Yağ oranım %6 düştü, kas kaybı sıfır. Ölçüm takibi çok düzenli."),
                DietitianReview(name: "Emre D.", stars: 4, date: "1 ay önce", text: "Program çok iyi ama yoğunluktan seans saatleri bazen kayabiliyor.")
            ])
    ]

    static let packageIncludes = [
        "8 birebir görüntülü seans",
        "Haftalık kişisel diyet programı",
        "Halka, tartı ve kan değeri takibi",
        "Mesajla sınırsız soru (hafta içi)"
    ]

    /// (date, note) rows shown on the "my dietitian" page.
    static let dietitianNotes: [(String, String)] = [
        ("05.08", "Su tüketimin hâlâ hedefin altında — güne 500 ml ile başla, öğünlerden önce 1 bardak."),
        ("01.08", "Protein hedefi 90 g/gün. Ara öğünlere yoğurt + badem ekledim, tok tutacak."),
        ("28.07", "Tebrikler, 2 haftada -1,4 kg. Kas kaybı yok, tartı verilerin çok iyi.")
    ]

    // MARK: Dietitian panel

    static func initialClients() -> [Client] {
        [Client(name: "Ayşe Kaya", weight: 68.4, delta: -1.2, compliance: 82,
                lastMeal: "Öğle · Ton balıklı salata",
                allergies: ["Fındık", "Laktoz intoleransı"],
                note: "Hashimoto tanısı var — TSH 3 ayda bir takip. Glutensiz tercih ediyor."),
         Client(name: "Mehmet Toprak", weight: 91.0, delta: -0.4, compliance: 64,
                lastMeal: "Kahvaltı · Menemen",
                allergies: ["Deniz ürünleri"],
                note: "Tip 2 diyabet öncesi (açlık glukozu sınırda). Akşam geç yeme alışkanlığı."),
         Client(name: "Zeynep Arslan", weight: 57.8, delta: 0.3, compliance: 91,
                lastMeal: "Ara öğün · Yoğurt + ceviz",
                allergies: [],
                note: "Demir eksikliği anemisi — C vitamini ile demir takviyesi birlikte.")]
    }

    /// Allergen keyword expansion for conflict detection.
    static let allergenKeys: [String: [String]] = [
        "fındık": ["fındık"],
        "laktoz": ["süt", "yoğurt", "peynir", "kefir", "laktoz", "ayran"],
        "deniz": ["balık", "ton", "somon", "karides", "midye", "levrek", "hamsi", "deniz"],
        "gluten": ["buğday", "ekmek", "bulgur", "makarna", "yulaf", "un", "gluten"],
        "yumurta": ["yumurta", "menemen", "omlet", "pancake"],
        "ceviz": ["ceviz"],
        "badem": ["badem"],
        "fıstık": ["fıstık"]
    ]

    /// Client meals shown on the "Genel" tab.
    static let clientMeals: [(String, String, String)] = [
        ("09:10", "Yulaf + yoğurt + meyve", "320 kcal"),
        ("13:40", "Ton balıklı salata", "400 kcal"),
        ("16:30", "Badem + 1 meyve", "150 kcal")
    ]

    /// Client supplements: (name, dose, time, compliance %).
    static let clientSupplements: [(String, String, String, Int)] = [
        ("Vitamin D3", "2000 IU · günde 1", "09:00", 86),
        ("Omega-3", "1000 mg · yemekle", "13:00", 71),
        ("Demir", "1 tablet · aç karnına", "11:00", 64),
        ("Magnezyum", "300 mg · gece", "22:00", 78)
    ]

    // MARK: Coach

    static func initialMessages() -> [CoachMessage] {
        [CoachMessage(role: .coach, text: "Günaydın Simge! Dün 6.5 saat uyudun ve su hedefinin %63'ündesin. Bu sabahki tartımına göre protein oranın düşük (%12.8) — bugüne protein ağırlıklı bir plan hazırladım."),
         CoachMessage(role: .plan, title: "Bugünün planı", planRows: [
            PlanRow(title: "Kahvaltı · ~320 kcal", detail: "2 yumurta + lor peyniri + yeşillik"),
            PlanRow(title: "Öğle öncesi · 30 dk", detail: "Tempolu yürüyüş — egzersiz halkanı kapatır"),
            PlanRow(title: "Gün boyu · +750 ml", detail: "Su oranın %47, hedefin altında")
         ])]
    }

    /// Weekly workout plans keyed by training days: day index → (title, duration).
    static let workoutPlans: [Int: [Int: (String, String)]] = [
        3: [0: ("Tempolu yürüyüş", "30 dk"), 2: ("Pilates + core", "20 dk"), 5: ("Yüzme", "45 dk")],
        4: [0: ("Tempolu yürüyüş", "30 dk"), 1: ("Pilates + core", "20 dk"), 3: ("Kuvvet (tüm vücut)", "30 dk"), 5: ("Yüzme", "45 dk")],
        5: [0: ("Tempolu yürüyüş", "30 dk"), 1: ("Pilates + core", "20 dk"), 2: ("Kuvvet (alt vücut)", "30 dk"), 4: ("Kuvvet (üst vücut)", "30 dk"), 5: ("Yüzme veya yoga", "45 dk")]
    ]
}
