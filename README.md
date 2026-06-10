# BizCore Mobile

The shop owner is never at their desk when stock runs out. Their phone is always with them. iOS can put that alert on their lock screen. Desktop can't. That's why this app exists.

BizCore Mobile is a lightweight iOS inventory companion for [BizCore Desktop](#connection-to-bizcore-desktop) — a full ERP already running live in a real client's business. The client asked for low-stock alerts on their phone. I learned iOS to build it.

---

## Screenshots

Captured on the iPhone 15 Pro simulator in Demo mode (Al-Nour Boutique sample data).

|                     Dashboard                      |                Product Detail                |                    Alerts                    |
| :------------------------------------------------: | :------------------------------------------: | :------------------------------------------: |
| ![Dashboard](screenshots/screenshot-dashboard.png) | ![Detail](screenshots/screenshot-detail.png) | ![Alerts](screenshots/screenshot-alerts.png) |
|       Critical · Low · In Stock at a glance        |      Stock level bar + one-tap restock       |     Notification settings · quiet hours      |

A delivered low-stock alert — the one thing the app exists to do:

![Low-stock alert](screenshots/screenshot-notification.png)

---

## What It Does

- **Live inventory dashboard** — products grouped by category, filterable by status (Critical / Low / All), full-text search
- **SwiftData offline cache** — inventory available without a connection; syncs on pull-to-refresh
- **Local low-stock alerts** — `UNUserNotificationCenter` notifications when a product drops below its reorder level. They fire instantly on every in-app check (open, refresh, restock) and on a best-effort background schedule via `BGAppRefreshTask` (see [How Notifications Work](#how-notifications-work))
- **One-tap restock** — writes quantity back to the shared Supabase database, with rollback if the write fails so local and server never diverge
- **Demo mode** — Al-Nour Boutique fictional inventory loads on first launch, no credentials needed

---

## How Notifications Work

Being honest about the delivery model, because it matters:

- **In-app checks (instant).** Opening the app, pull-to-refresh, and confirming a restock each run a low-stock check immediately. Any matching product fires a local notification right away — and because the app sets a `UNUserNotificationCenterDelegate`, the banner shows even while the app is open.
- **Background checks (best-effort).** `BGAppRefreshTask` re-checks inventory on a schedule driven by the **Check Frequency** setting. iOS decides the exact run time based on usage, battery, and network — this is the standard behaviour for any background-refresh app, not a guaranteed delivery moment.
- **Quiet hours and alert-type toggles** are respected on every path.

These are **local** notifications scheduled on-device. For guaranteed delivery the instant stock changes on the server — independent of when the app last opened — the next milestone is a Supabase Edge Function calling **APNs** for true server push. The on-device paths above are what ships today; server push is the documented roadmap.

---

## Connection to BizCore Desktop

BizCore Mobile shares the same Supabase backend as **BizCore Desktop**, a full Electron + React + SQLite ERP built for the same client (Al-Khattaf). The desktop app handles purchase orders, bookkeeping, and reporting. The mobile app adds the one thing desktop can't: alerts on the owner's phone.

```
┌─────────────────────┐        ┌──────────────────────┐
│   BizCore Desktop   │        │   BizCore Mobile     │
│  Electron · React   │◄──────►│  SwiftUI · SwiftData │
│  SQLite · Supabase  │        │  UNUserNotification  │
│                     │        │                      │
│  Full ERP — orders, │        │  Low-stock alerts    │
│  reports, invoices  │        │  wherever owner is   │
└─────────────────────┘        └──────────────────────┘
             │                           │
             └───────────┬───────────────┘
                   Supabase (shared)
                   products · inventory
```

BizCore Desktop is a private repo (client work). Available on request.

---

## Tech Stack

![Swift](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-iOS%2017%2B-0071e3?logo=apple&logoColor=white)
![SwiftData](https://img.shields.io/badge/SwiftData-offline%20cache-34C759)
![Supabase](https://img.shields.io/badge/Supabase-REST%20API-3ECF8E?logo=supabase&logoColor=white)
![Architecture](https://img.shields.io/badge/Architecture-MVVM-blueviolet)

Concurrency: `actor`-isolated `NotificationService` / `SupabaseService`, with a `Sendable` snapshot type crossing the actor boundary so SwiftData models never leave the main actor.

---

## Setup

<details>
<summary><strong>Run with real data (Supabase credentials required)</strong></summary>

1. Clone the repo
2. Create `Sources/BizCoreMobile/Config.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>SUPABASE_URL</key>
    <string>https://YOUR_PROJECT.supabase.co</string>
    <key>SUPABASE_KEY</key>
    <string>YOUR_ANON_KEY</string>
</dict>
</plist>
```

3. Open in Xcode 15+, target iOS 17 simulator or device
4. Tap **Demo OFF** in the top-left toolbar to switch to live data

`Config.plist` is in `.gitignore` — never committed.

</details>

<details>
<summary><strong>Run with demo data (no credentials needed)</strong></summary>

1. Clone the repo
2. Generate the app target: `brew install xcodegen && xcodegen generate` (details in `MAC_SETUP.md`)
3. Open in Xcode 15+, target iOS 17 simulator
4. Build and run — demo mode is **on by default**

The app opens with Al-Nour Boutique fictional inventory. Toggle demo mode at any time using the **Demo ON / Demo OFF** button in the top-left toolbar — no code change needed.

</details>

---

## Project Context

This is my first iOS app. I built it in ~2 weeks on a Windows machine (VS Code + borrowed Mac for Xcode compilation) because my client specifically asked for low-stock alerts on their phone, and iOS was the way to give them that.

The learning order: Swift structs and value semantics → `@Observable` + `@State` ownership model → SwiftData persistence → `UNUserNotificationCenter` → `actor`-based concurrency and `BGAppRefreshTask`. The desktop ERP already existed and worked. The mobile app was built to solve one specific gap the client identified.

---

## Author

**Eyas Mohammed** · Full-stack developer · Electrical Engineering student, Nusa Putra University  
[github.com/Eyasdm](https://github.com/Eyasdm)
