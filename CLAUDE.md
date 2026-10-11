# Volume Mixer (macOS)

Menu-bar app with per-app volume and mute, like the Windows Volume Mixer. Swift only, SwiftUI
interface, Core Audio process taps (macOS 14.2+). Read `README.md` for an overview and
`docs/DEVELOPMENT.md` for architecture and rules.

## Build

- Only the Command Line Tools are installed (no Xcode): use SwiftPM, not `xcodebuild`.
- Compile check: `swift build`
- Runnable app: `./scripts/build-app.sh`, then `open "build/Volume Mixer.app"`
- Never use `swift run` to test audio: without the bundle's Info.plist, the permission
  prompt can't appear and the app is killed.

## Rules

- `AppAudioTap.render` runs on the real-time audio thread: no allocation, locks, logging or
  Objective-C calls inside it.
- `MixerModel` is `@MainActor`. Core Audio listeners deliver on `.main` and use
  `MainActor.assumeIsolated`.
- Swift 5 language mode (set in `Package.swift`). Don't switch to Swift 6 strict concurrency
  without fixing the audio-pointer sharing first.
- Keep the C Core Audio API behind `CA` / `SystemVolume` in `CoreAudioHelpers.swift`.

## Team (save credits)

- Hard Core Audio work: main session on Opus.
- Interface work: the `ui-dev` agent (Sonnet).
- Building and reading errors: the `builder` agent (Haiku). Report errors only, never full logs.
- Before committing: the `reviewer` agent (Sonnet).
