# Agents

## How to Work With the User
- Present options and be opinionated. Lead with your recommendation, explain trade-offs briefly, let the user decide.
- Zero external dependencies. Do not introduce third-party packages.
- One class/protocol/struct per file.

## Architecture
- Punt is a macOS browser picker — it registers as an HTTP/HTTPS handler, intercepts link clicks, and shows a picker UI to choose which browser opens the URL.
- NSPanel-based floating picker (borderless, non-activating, vibrancy backdrop).
- SwiftUI views hosted in NSHostingView inside the NSPanel.
- ObservableObject (not @Observable) for macOS 13 compatibility.
- URL events handled via NSAppleEventManager in applicationWillFinishLaunching.
- UserDefaults for config storage (JSON-encoded).
- Browser discovery via LSCopyAllHandlersForURLScheme + Chromium profile parsing.

## Constants & Magic Numbers
- Extract behavioral constants (timing, limits) as `static let` on the owning type — no global Constants.swift.
- Leave UI styling (font sizes, padding, opacity) inline in SwiftUI views.
- Define key codes as a `UInt16` raw-value enum.

## Don'ts
- Do NOT use `swift run` — this is a macOS GUI app that requires the `.app` bundle.
- Do NOT start GitHub macOS runners / re-add macOS CI without explicit approval — releases are local.
- Do NOT hand-edit release version fields — `scripts/release.sh` updates `Info.plist` and casks.
- Do NOT use @Observable — requires macOS 14+, we target macOS 13+.

## Build & Run
- `make build` compiles + assembles the `.app` bundle.
- `make run` builds + launches the app.
- `make install` builds + copies to /Applications.
- `make clean` removes artifacts.

## Release (local only)
- No GitHub Actions macOS jobs. Ship from a signed-in Mac:
  `scripts/release.sh X.Y.Z`
- Flow: changelog → version bump → universal build → codesign → notarytool → staple → zip → commit/tag/push → `gh release` → Homebrew tap.
- Notary: `export NOTARY_PROFILE=…` (from `xcrun notarytool store-credentials`) or `NOTARIZE_APPLE_ID` + `NOTARIZE_PASSWORD` + `NOTARIZE_TEAM_ID`.
- Optional: `SKIP_PUSH=1` (artifacts only), `SKIP_HOMEBREW=1`.
