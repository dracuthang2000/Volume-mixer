# Security Policy

## Supported versions

Only the latest release receives fixes.

## Reporting a vulnerability

Please **don't** open a public issue for security problems.

Report them privately through GitHub:
**Security** tab → **Report a vulnerability** on
[this repository](https://github.com/dracuthang2000/Volume-mixer/security/advisories/new).

Please include what an attacker could do, the steps to reproduce it, and your macOS version.
You should get a reply within 7 days.

## What the app accesses

Volume Mixer asks for the macOS **System Audio Recording** permission so it can route each
app's sound through itself and change its volume. Audio is processed in memory as it plays.
It is **never recorded, saved, or sent anywhere**, and the app makes no network connections.
