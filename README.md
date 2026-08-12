# Shotlist

A native iOS app for film and video production shot lists. Paste a raw shot list, get an organized checklist, framing suggestions, and an optimized walking route for location shoots.

## Features

### Shot list
- **Paste & parse** — `☐`, Markdown `[ ]`/`[x]`, bullets, and numbered lists. Categories preserved exactly (e.g. `NORDIS – MAAN TASALTA`).
- **Project brief** — Intro paragraphs saved and shown at the top of the list.
- **Shot metadata** — Auto-detected shot size (WS/MS/CU), camera angle, and location — editable per shot.
- **Variant grouping** — `Medium` / `Close / detail` nest under the parent with their own checkboxes.
- **Progress tracking** — Accurate counts, search, incomplete filter, multi-project switcher.
- **Unmapped shots** — Flagged until you assign a location in Shot Detail.

### Walk route
- **Location clustering** — Töölö landmarks (Töölöntori, Nordis, Mannerheimintie, etc.).
- **Optimized walk order** — Nearest-neighbor routing; drag to reorder stops manually.
- **Time management** — Per-shot estimates, walk time, start time, ETA finish.
- **Map view** — Numbered stops + dashed path (straight-line estimate at ~5 km/h).
- **Apple Maps navigation** — Walking directions per stop.
- **Coverage order** — Wide → medium → close at each location.

### Framing generator
- Camera, lens (manual or auto), frame rate (24–60 fps / 180° shutter), aspect ratio
- Time of day + weather exposure (fps-aware ND/ISO notes)
- Visual framing diagram with correct aspect letterboxing
- DRONE category suggests DJI Mini 4 Pro (override sticks once saved)

### Export
- PDF call sheet with wrapped text, route ETAs, notes, and locations
- Share from Shots or Route tab

## Requirements

- iOS 17.0+
- Xcode 15.0+

## Getting Started

1. Open `Shotlist/Shotlist.xcodeproj` in Xcode.
2. Set your development team in Signing & Capabilities.
3. Build and run (⌘R).

## Usage

1. **Import** → Load Sample (HIFK Töölö) or paste → Preview → Create (jumps to Shots)
2. **Route** → Set start time → reorder stops if needed → Navigate
3. **Shots** → Check off roots and variants; edit location/size on detail
4. **Gear** — Defaults autosave when changed

## Tests

```bash
xcodebuild test -project Shotlist/Shotlist.xcodeproj -scheme Shotlist \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

## License

MIT
