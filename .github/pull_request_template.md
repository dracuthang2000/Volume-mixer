## What does this change?

<!-- A short description, and "Fixes #123" if it closes an issue. -->

## How was it tested?

<!-- macOS version, output device, which apps you tried. -->

## Checklist

- [ ] `swift build` succeeds with no warnings
- [ ] Tested with the bundled app (`./scripts/build-app.sh`), not `swift run`
- [ ] No allocation, locks or logging added inside `AppAudioTap.render`
- [ ] Added a line under **Unreleased** in `CHANGELOG.md`
