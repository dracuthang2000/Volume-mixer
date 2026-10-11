# Changelog

All notable changes to this project are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.1] - 2026-10-11

### Fixed

- Release builds are now universal: they run on both Apple silicon and Intel Macs
  (0.1.0 ran on Apple silicon only).
- Install steps for macOS 15+ ("Open Anyway" in Privacy & Security).

### Added

- Homebrew install: `brew install --cask dracuthang2000/tap/volume-mixer`.
- Social preview image for the GitHub repository.

## [0.1.0] - 2026-10-11

### Added

- Menu-bar mixer with a volume slider and mute button for each app that plays audio.
- System row for the output device's own volume and mute.
- Helper processes (browser tabs, WebKit, Electron helpers) grouped under their app.
- Per-app volume and mute remembered between launches.
- Automatic handling of output device changes (for example switching to AirPods).
- Highlight on the hovered and actively adjusted row, and on the footer buttons.
- App icon.
