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
- Do NOT manually update `Info.plist` version or `Casks/punt.rb` — CI handles these.
- Do NOT use @Observable — requires macOS 14+, we target macOS 13+.

## Build & Run
- `make build` compiles + assembles the `.app` bundle.
- `make run` builds + launches the app.
- `make install` builds + copies to /Applications.
- `make clean` removes artifacts.
