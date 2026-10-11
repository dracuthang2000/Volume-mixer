# Developer notes

## Build commands

| Task | Command |
|---|---|
| Compile only (fast check) | `swift build` |
| Build the runnable app | `./scripts/build-app.sh` (release) or `./scripts/build-app.sh debug` |
| Run | `open "build/Volume Mixer.app"` |
| Quit a running copy | `pkill -x VolumeMixer` |
| Live logs | `log stream --predicate 'process == "VolumeMixer"'` |

No Xcode project is needed. To use Xcode anyway, open `Package.swift`, but run the app
through `build-app.sh` so it has its `Info.plist`.

## Data flow

```
Timer (1 s) ─► MixerModel.refresh()
                 ├─ CA.processObjectList()            every process using Core Audio
                 ├─ AppIdentityCache.identity(pid)    → app key, name, icon (grouping)
                 ├─ syncTaps()                        create / remove AppAudioTap per app
                 └─ publish `apps`                    → SwiftUI re-renders MixerView

Slider ─► MixerModel.setVolume(id) ─► AppSettings (saved)
                                   └► AppAudioTap.gain   (read by the audio thread)

Default output device changes ─► listener ─► remove all taps ─► refresh() recreates them
```

## Rules for the audio thread (`AppAudioTap.render`)

The IO callback runs on a real-time thread. Inside it, **never**:

- allocate memory (no Swift `Array`, `String`, or class instances created there)
- take locks, use `DispatchQueue.sync`, or `await`
- call Objective-C or Swift runtime-heavy APIs, or print/log

The gain is shared through an `UnsafeMutablePointer<Float32>`: the main thread writes it and
the audio thread reads it. Keep it that way, or switch to `Synchronization.Atomic` if the
minimum macOS version is raised to 15.

## Tap lifecycle

A tap exists for an app only when **all** of these are true:

1. Its saved volume is below 100% **or** it is muted.
2. It played audio within the last 20 seconds (`idleGrace`).
3. Its set of processes hasn't changed. If a new helper process starts, the tap is rebuilt.

If creating a tap fails, the model waits 10 seconds (`retryDelay`) before trying again, and
shows the error in the interface.

## Testing checklist (manual)

1. Play audio in two apps (for example Music and a YouTube tab in Chrome).
2. Both appear with a green dot.
3. Lower Chrome to 30%: on first use the permission prompt appears. Allow it, and Chrome gets
   quieter while Music doesn't change.
4. Mute Music: silence. Unmute: it comes back.
5. Drag Chrome back to 100%: its tap is removed and nothing is audible as a glitch.
6. Switch output to headphones or AirPods: the levels you set are still applied.
7. Quit and reopen Volume Mixer: settings are restored when the apps play again.
8. Change the **System** slider and compare with the volume keys on the keyboard.

## Roadmap ideas

- Boost above 100% (with a limiter to avoid clipping).
- Per-app output device selection (send Spotify to headphones, a game to speakers).
- Live level meters (peak per buffer, published to the interface at about 20 Hz).
- Keyboard shortcuts and "launch at login" via `SMAppService`.
- Proper Developer ID signing and notarization, so the permission survives rebuilds.

## Key Apple APIs

| API | Used for |
|---|---|
| `kAudioHardwarePropertyProcessObjectList` | List of processes using audio |
| `kAudioProcessPropertyPID`, `…BundleID`, `…IsRunningOutput` | Who the process is and whether it is playing |
| `CATapDescription`, `AudioHardwareCreateProcessTap` | Capturing one app's audio |
| `AudioHardwareCreateAggregateDevice` | Combining the tap with the speakers |
| `AudioDeviceCreateIOProcIDWithBlock`, `AudioDeviceStart` | The real-time copy-with-gain callback |
| `kAudioHardwareServiceDeviceProperty_VirtualMainVolume` | System (master) volume |
| `NSAudioCaptureUsageDescription` (Info.plist) | The permission prompt text |

## Repository rules (maintainer)

The GitHub rulesets live in `.github/rulesets/` so they are versioned with the code. GitHub
doesn't apply them from the repo automatically; import each file once in
**Settings → Rules → Rulesets → New ruleset → Import a ruleset**.

| Ruleset | What it enforces |
|---|---|
| `protect-main.json` | `main` can't be deleted or force-pushed. Changes need a pull request that passes the **Build** check. Repository admins can bypass (so the maintainer can still push directly). |
| `protect-release-tags.json` | Only admins can create `v*` tags (each one publishes a release). Existing release tags can't be moved or deleted. |

After changing a ruleset in the GitHub settings, export it (**⋯ → Export ruleset**) and
commit the JSON here so the two stay in sync.
