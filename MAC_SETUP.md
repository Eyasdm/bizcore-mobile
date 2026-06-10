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

> **Run `xcodegen generate` fresh this session.** `project.yml` changed: it now
> points at an explicit committed `Info.plist` (instead of auto-generating one)
> so the background-refresh keys can be declared. No extra steps — XcodeGen still
> just reads `project.yml` — but a stale `.xcodeproj` from a previous run will
> miss the new Info.plist wiring, so delete it first if one exists.

## 2. Build & run

1. Select the **iPhone 15 Pro** simulator (iOS 17).
2. Press **⌘R**. The app launches with **Demo mode ON** — no `Config.plist`
   needed (Al-Nour Boutique sample data loads automatically).

If the build fails on the Info.plist step, the fallback is to create a new iOS
App project in Xcode manually, add `Sources/BizCoreMobile/**` to its target, and
enable **Background Modes → Background fetch** plus a permitted task identifier
`com.bizcore.refresh` in the target's Info settings. (XcodeGen does this for you.)

## 3. Verify the headline feature (do this before screenshots)

The whole pitch is "the alert reaches the owner." Prove it works:

1. Open the **Alerts** tab → tap **Enable** and grant notification permission.
2. Tap **Send Test Notification**. A banner should drop down **while the app is
   open** — that confirms the foreground delegate is wired correctly.
3. Open a **Critical** product → **Mark Restocked** → set it in stock. When the
   sheet closes, the app re-checks inventory and notifies the *other* low items.
   That is the real restock-triggered alert path, not just the test button.

## 4. Screenshots (Demo mode ON)

Capture with **⌘S** in the simulator, then drop into `screenshots/`:

| Screen                  | File                            |
| ----------------------- | ------------------------------- |
| Dashboard               | `screenshot-dashboard.png`      |
| Product Detail          | `screenshot-detail.png`         |
| Alerts                  | `screenshot-alerts.png`         |
| Delivered alert banner  | `screenshot-notification.png`   |

The README references all four paths. For the banner shot, trigger the test
notification (step 3) and screenshot the banner as it appears, or capture it from
the lock screen / Notification Center.

## 5. (Optional) Verify background refresh

Background tasks don't fire on their own quickly, but you can force the
registered task to run for a demo. With the app running and the debugger
attached, **pause** execution and run this in the LLDB console:

```
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.bizcore.refresh"]
```

Then **resume**. The background check runs against the current inventory (demo
data in demo mode) and fires notifications for low items — proving the
`BGAppRefreshTask` path end-to-end. This is a debug-only technique; it is not
shipping code.

## Notes

- No `Config.plist` is required to build or demo — Supabase calls are skipped
  while Demo mode is on. Add `Config.plist` (gitignored) only to test live sync.
- The default system accent (blue) is used for tint. If you want a branded look,
  add an `AccentColor` color set to the asset catalog — optional polish, not
  required for the build or screenshots.
