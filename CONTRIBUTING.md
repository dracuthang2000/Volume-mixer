# Contributing to Volume Mixer

Thanks for helping! Bug reports, ideas and pull requests are all welcome.

## Reporting bugs and ideas

- **Bug:** open an issue with the *Bug report* form. Include your macOS version, your output
  device, and the app whose volume misbehaves.
- **Idea:** open an issue with the *Feature request* form. Check the roadmap in
  [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) first, it may already be planned.
- **Security problem:** please don't open a public issue; see [SECURITY.md](SECURITY.md).

## Development setup

You need macOS 14.2 or later and either Xcode 16+ or the Command Line Tools
(`xcode-select --install`).

```bash
git clone https://github.com/dracuthang2000/Volume-mixer.git
cd Volume-mixer
./scripts/build-app.sh debug
open "build/Volume Mixer.app"
```

Use `swift build` for a quick compile check. Always test audio with the bundled app,
not `swift run` (see the README for why).

Read [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) before changing audio code. It explains the
architecture and the rules for the real-time audio thread.

## Pull requests

1. Fork the repo and create a branch from `main` (for example `fix/airpods-switch`).
2. Keep each pull request focused on one change.
3. Make sure `swift build` succeeds with **no warnings**. CI checks this.
4. Run through the manual test checklist in `docs/DEVELOPMENT.md` for anything touching audio.
5. Add a line under **Unreleased** in [CHANGELOG.md](CHANGELOG.md).
6. Open the pull request and fill in the template.

### Code style

- Follow the style of the surrounding code: Swift API Design Guidelines, 4-space indent.
- Keep raw Core Audio C calls inside `CoreAudioHelpers.swift` (`CA`, `SystemVolume`).
- Inside `AppAudioTap.render`, don't allocate, lock, log, or call Objective-C.
- Interface code goes in `MixerView.swift`; state and logic in `MixerModel.swift`.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
