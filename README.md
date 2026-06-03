# BizCore Mobile

iOS inventory companion for BizCore — a desktop ERP running live in a real business.

> ⚠️ **Active development** — build started June 3, 2026. Screenshots and demo coming June 13.

---

## The Problem

The shop owner needed to know the moment any product ran critically low — without being at their desktop. iOS is the right platform because only mobile can deliver that notification reliably, wherever the owner is.

---

## What It Does

- 📦 Live inventory dashboard with In Stock / Low / Critical status
- 🔄 Real-time Supabase sync with SwiftData offline cache
- 🔔 Push notifications when products cross low-stock threshold
- ✅ One-tap restock action writes back to the shared database
- 🎭 Demo mode with fictional data for portfolio screenshots

---

## Tech Stack

`SwiftUI` · `SwiftData` · `Supabase REST API` · `UNUserNotificationCenter` · `MVVM` · `iOS 17+`

---

## Connection To BizCore Desktop

This app shares the same Supabase backend as **BizCore** — a full desktop ERP (Electron + React + SQLite) built for the same client. The mobile app adds the one capability the desktop cannot provide: real-time alerts wherever the owner is.

→ BizCore desktop is a private repo (client work)

---

## Setup

1. Clone this repo
2. Create `Sources/BizCoreMobile/Config.plist` with:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>SUPABASE_URL</key>
    <string>https://YOUR_PROJECT.supabase.co</string>
    <key>SUPABASE_KEY</key>
    <string>YOUR_ANON_KEY</string>
</dict>
</plist>
```
3. Open in Xcode 15+ and run on iOS 17 simulator
4. Or enable Demo Mode in `DemoData.swift` to run without credentials

---

## Demo Mode

Set `DemoMode.isEnabled = true` in `DemoData.swift` to load fictional Al-Nour Boutique inventory. All screenshots in this README use Demo Mode — no real client data is ever shown.

---

## Screenshots

*Coming June 13, 2026*

---

## Author

Eyas Mohammed · [github.com/Eyasdm](https://github.com/Eyasdm)
