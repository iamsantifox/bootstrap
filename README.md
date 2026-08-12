# Shotlist

A native iOS app for film and video production shot lists. Paste a raw shot list and turn it into an organized, checkable list with framing suggestions based on your camera gear and shooting conditions.

## Features

- **Paste & parse** — Import shot lists from notes, email, or production docs. Supports checkbox (`☐`), bullet (`-`), and numbered formats. ALL CAPS lines become categories.
- **Organized shot list** — Collapsible categories, progress tracking, search, and per-shot completion checkboxes.
- **Framing generator** — For each shot, generate example framing guidance based on:
  - Camera body (Sony FX3, Canon R5 C, RED Komodo, DJI Mini 4 Pro, iPhone 15 Pro, etc.)
  - Lens (14mm–200mm, drone/phone equivalents)
  - Time of day (golden hour, blue hour, midday, night, etc.)
  - Weather (sunny, overcast, rain, snow, fog)
- **Visual framing diagram** — Rule-of-thirds grid with subject placement, horizon line, and framing style overlay.
- **Exposure suggestions** — Aperture, shutter speed, ISO, and ND filter recommendations.
- **Persistence** — Projects and gear settings saved locally.

## Requirements

- iOS 17.0+
- Xcode 15.0+
- iPhone or iPad

## Getting Started

1. Open `Shotlist/Shotlist.xcodeproj` in Xcode.
2. Select your development team in Signing & Capabilities.
3. Build and run on a simulator or device (⌘R).

## Usage

### Import a shot list

1. Go to the **Import** tab.
2. Paste your shot list (or tap **Load Sample** for the included HIFK Töölö b-roll example).
3. Optionally set a project title.
4. Tap **Preview Parse** to verify, then **Create Shot List**.

### Format example

```
DRONE
☐ Töölöntori – suoraan ylhäältä / lintuperspektiivi
☐ Liikenne risteyksessä ylhäältä

NORDIS – MAAN TASALTA
☐ Halli edestä
☐ Halli sivusta
```

### Generate framing

1. Tap any shot in the list.
2. Choose camera, lens, time of day, and weather.
3. Tap **Generate Framing** to see the visual diagram and suggested settings.

### Default gear

Set your default camera and conditions in the **Gear** tab. These apply to all new framing suggestions.

## Project Structure

```
Shotlist/
├── Shotlist/
│   ├── Models/          # Shot, category, camera gear enums
│   ├── Services/        # Parser, framing generator, data store
│   ├── Views/           # SwiftUI screens
│   └── SampleData.swift # HIFK Töölö example shot list
└── ShotlistTests/       # Unit tests for parser and framing logic
```

## Tests

Run unit tests in Xcode with ⌘U, or:

```bash
xcodebuild test -project Shotlist/Shotlist.xcodeproj -scheme Shotlist -destination 'platform=iOS Simulator,name=iPhone 15'
```

## License

MIT
