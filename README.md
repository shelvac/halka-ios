# halka — native iOS app (SwiftUI)

Native SwiftUI implementation of the **Sağlık App** design exported from Claude Design
(prototype: `Saglik App.dc.html`).

## Requirements

- Xcode 16 or newer (the project uses folder-synchronized groups, `objectVersion 77`)
- iOS 17.0+ deployment target, iPhone only

## Run

1. Open `Halka.xcodeproj` in Xcode.
2. Select your team under *Signing & Capabilities* (bundle id `com.simgehelvaci.halka`).
3. Build & run on an iPhone simulator or device.

> Fallback: if your Xcode version can't open the project file, create a fresh iOS App
> project named `Halka` (SwiftUI, Swift) and add the `Halka/Halka` folder as a
> folder reference — every source file is self-contained under that directory.

## What's implemented (full design scope)

| Area | Screens / flows |
| --- | --- |
| Auth | Splash (auto-advance 2.6 s, tap-through) → Login with Kullanıcı/Diyetisyen role toggle → Register with KVKK consent → Premium paywall (₺1.190/yıl · ₺149/ay) |
| Özet | 4 nested rings (Egzersiz/Su/Uyku/Beslenme), +250 ml su with 6 s **Geri al**, Öğün ekle → photo flow, Egzersiz shortcut, goal cards, weekly ring strip, 12-day streak card |
| Takvim | August 2026 ring history grid (Mon-first, future days disabled), per-day detail with % chips |
| Arkadaşlar | 2L Su · 7 Gün challenge card, leaderboard (halka puanı, own row highlighted), add friend, new-challenge placeholder |
| Diyetisyen | Marketplace (3 experts) → profile with bio/stats/starred reviews → checkout (order summary, saved card, processing → done) → active dietitian page (package, sessions left, next appointment, notes, today's plan) → "Diyetisyeni değiştir" |
| AI Koç | Chat with typing indicator; weekly workout flow (3/4/5 days), weekly meal flow (goal → meal times → 7-day menu that also updates the Yemek tab's meal times); motivation/weight/topic replies; quick chips |
| Yemek | Day chips, plan rows with eaten check (strikethrough + ring update), meal detail (recipe, market list, steps), catalog with "Bugünün menüsüne yaz", photo → Vision-AI estimate → save with timestamp → deletable, calorie log (plan + photo sources), day market list with checkboxes |
| Egzersiz | Program builder (name/region/level), exercise library (search + region filter, pick mode), program detail, live workout (stopwatch via `TimelineView`, per-exercise checks), finish → history + exercise ring minutes |
| Sağlık | Vücut (weight card, BMI band with marker, 14 metrics with status chips, PDF upload simulation), Değerlerim (16 blood tests with reference-position dots, counts, AI Koç note, PDF upload), Takviyeler (taken checks, **real local notifications** on the bell toggle), profile (Apple Health card + screenshot-fallback AI import crediting the exercise ring, settings, logout) |
| Diyetisyen paneli | Client roster with quick-add + stats; client detail with weight-trend bars and 5 tabs — Genel (allergy chips ±, health note), Vücut, Değerler (+ commentary), Takviye (compliance %), Diyet (weekly editor with **live allergy-conflict warnings** per field + week-wide summary, kcal target, "Diyet Programını Gönder") |

All demo data (menus, recipes, blood panel from the 29.11.2025 Medicana report, body
metrics, dietitians, reviews, clients, allergen keyword map) is ported 1:1 from the
prototype into `Models/DemoData.swift`.

## Architecture notes

- **State**: one `@MainActor @Observable` `AppModel` (`Models/AppModel.swift`) split into
  domain extensions (`+Coach`, `+Meals`, `+Workout`, `+Health`, `+Dietitian`). All state
  is in-memory demo data, mirroring the prototype. Swap in Supabase/HealthKit per the
  roadmap (`project/iOS Yol Haritasi.dc.html`) behind the same model API.
- **Design tokens**: `Support/Theme.swift` carries the prototype's exact hex palette and
  shared components (cards, chips, avatars, checks, spinners). The prototype's Manrope
  is mapped to the SF system font at equivalent weights (800→heavy, 700→bold,
  600→semibold); drop Manrope TTFs + `UIAppFonts` into the target to match exactly.
- **Rings**: `Views/Home/RingViews.swift` reproduces the 92/72/52/32-radius geometry;
  empty days render tracks only (no colored dots on empty days — a fix called out in the
  design chats).
- **Images**: the prototype uses drag-and-drop `<image-slot>` placeholders for food and
  exercise photos; here they are `ImagePlaceholder` views — replace with bundled assets
  or remote URLs later.
- **Simulated services** (marked in code): PDF parsing, Vision AI calorie estimates,
  Health-screenshot parsing, and payment are timed animations, matching the prototype's
  behavior. Supplement reminders, however, schedule real `UNUserNotificationCenter`
  daily notifications.
