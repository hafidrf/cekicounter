# Ceki Counter

**Ceki Counter** is a Flutter app for live scorekeeping and season standings in multiplayer table games. Set up players, track rounds, finish a match, and see the league table update — with local backup and restore so your history travels with you.

Designed for card and party games where you need a clear score pad, flexible win rules, and a standing board across many sessions.

- **Live scoring:** add players, enter round scores, finish when ready
- **Flexible rules:** lowest or highest score wins; optional target score and max rounds
- **Season standings:** points and score differential across completed matches
- **History:** review past sessions; ignore or delete entries from standings when needed
- **Backup & restore:** export/import JSON; optional sample standings bundled for first-run demos
- **Themes:** light and dark Material 3 UI

Data stays on the device (Shared Preferences / local storage). No account required.

---

## Download Android APK

Install the latest release APK without building from source:

1. Open the [latest release](https://github.com/hafidrf/cekicounter/releases/latest)
2. Download **`cekicounter-v1.0.0.apk`**
3. On your phone, allow install from unknown sources / this browser if prompted
4. Open the APK and install

Direct download (v1.0.0):

https://github.com/hafidrf/cekicounter/releases/download/v1.0.0/cekicounter-v1.0.0.apk

> Note: this build is signed with the debug keystore (fine for personal / internal install). Android may show a warning because it is not from Play Store.

---

## Features

| Area | Description |
|------|-------------|
| **Setup** | Player presets, session name, win-mode rules |
| **Game** | Round-by-round score entry until finish |
| **Standings** | Season table built from finished matches (+ optional baseline) |
| **History** | Past sessions with standings include/exclude |
| **Backup** | Share or import a full JSON snapshot |

---

## Stack

- Flutter / Dart 3.5+
- Riverpod for state
- go_router for navigation
- Shared Preferences + path_provider for persistence
- fl_chart, google_fonts, share_plus, file_picker, csv

---

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel recommended)
- A device or emulator (Android, iOS, Windows, macOS, Linux, or Chrome)

---

## Setup

```bash
cd cekicounter
flutter pub get
```

---

## Run

```bash
flutter run
```

Target a specific platform if needed:

```bash
flutter run -d windows
flutter run -d chrome
flutter run -d android
```

---

## Build release APK

```bash
flutter build apk --release
```

Output:

`build/app/outputs/flutter-apk/app-release.apk`

---

## Typical workflow

1. Open **Home** and start a new match (or continue an active session)
2. On **Setup**, choose players and rules, then begin
3. Enter scores each round on the **Game** screen; finish when the match ends
4. Check **Standings** for the current season table
5. Use the cloud icon on Home for **backup** or **restore** (JSON)

### Sample standings restore

A demo backup lives at `assets/restore/restore_klasmen_terakhir.json`.

1. Home → backup / restore → **Import backup (JSON)**, or use the bundled sample restore action if available
2. Open **Standings** — you should see a sample season baseline
3. Finished matches after that add points on top of the baseline

---

## Project layout

```
cekicounter/
├── lib/
│   ├── main.dart
│   └── src/
│       ├── app.dart              # MaterialApp + theme
│       ├── router.dart           # Routes
│       ├── models/               # Game & standings models
│       ├── services/             # Local storage
│       ├── state/                # Riverpod controllers
│       ├── ui/                   # Screens
│       └── util/                 # Backup export helpers
├── assets/restore/               # Sample JSON restore
├── android/ ios/ web/ windows/ … # Platform runners
└── pubspec.yaml
```

---

## Backup format

Exports are JSON (`schemaVersion` 2) containing history, active session, manual standings baselines, player presets, and theme preference. Treat backups as personal data — do not commit real league exports to a public repository.

---

## Licence

Private / internal use unless you add an explicit licence file.
