# Mac Session — Build & Screenshot Setup

The repo is a Swift package for tooling, but Xcode cannot run a `.library`
product as an iOS app. Generate a runnable app target with XcodeGen.

## 1. Generate the Xcode project

```bash
brew install xcodegen        # one time only
cd bizcore-mobile
xcodegen generate            # reads project.yml → BizCoreMobile.xcodeproj
open BizCoreMobile.xcodeproj
```

`BizCoreMobile.xcodeproj` is intentionally gitignored — it is regenerated
from the committed `project.yml` on each machine.

## 2. Build & run

1. Select the **iPhone 15 Pro** simulator (iOS 17).
2. Press **⌘R**. The app launches with **Demo mode ON** — no `Config.plist`
   needed (Al-Nour Boutique sample data loads automatically).

## 3. Screenshots (Demo mode ON)

Capture with **⌘S** in the simulator, then drop into `screenshots/`:

| Screen          | File                          |
| --------------- | ----------------------------- |
| Dashboard       | `screenshot-dashboard.png`    |
| Product Detail  | `screenshot-detail.png`       |
| Alerts          | `screenshot-alerts.png`       |

The README already references these three paths.

## Notes

- No `Config.plist` is required to build or demo — Supabase calls are skipped
  while Demo mode is on. Add `Config.plist` (gitignored) only to test live sync.
- If you prefer not to install XcodeGen, you can instead create a new iOS App
  project in Xcode manually and add `Sources/BizCoreMobile/**` to its target.
