# Shotlist

A native iOS app for film and video production shot lists. Paste a raw shot list, get an organized checklist, framing suggestions, and an optimized walking route for location shoots.

## Features

### Shot list
- **Paste & parse** — Checkbox (`☐`), bullet (`-`), and numbered formats. Categories preserved exactly (e.g. `NORDIS – MAAN TASALTA`).
- **Project brief** — Intro paragraphs saved and shown at the top of the list.
- **Shot metadata** — Auto-detected shot size (WS/MS/CU), camera angle, and location.
- **Variant grouping** — `Medium` / `Close / detail` lines group under the previous shot.
- **Progress tracking** — Checkboxes, search, filter incomplete shots.

### Walk route (new)
- **Location clustering** — Shots grouped by Töölö landmarks (Töölöntori, Nordis, Mannerheimintie, etc.).
- **Optimized walk order** — Nearest-neighbor routing to minimize backtracking.
- **Time management** — Per-shot time estimates, walk time between stops, start time picker, ETA finish.
- **Map view** — MapKit map with numbered stops and walking path.
- **Apple Maps navigation** — One-tap "Navigate" opens walking directions to each stop.
- **Shoot order** — Wide shots before mediums/closes at each location.

### Framing generator
- Camera body, lens (manual or auto), **frame rate** (24/25/30/50/60 fps with 180° shutter), **aspect ratio**
- Time of day and weather exposure suggestions
- Visual framing diagram with correct aspect ratio letterboxing
- Auto-selects DJI Mini 4 Pro for DRONE category shots
- Per-shot framing settings saved

### Export
- PDF call sheet with route summary and full shot list

## Requirements

- iOS 17.0+
- Xcode 15.0+

## Getting Started

1. Open `Shotlist/Shotlist.xcodeproj` in Xcode.
2. Set your development team in Signing & Capabilities.
3. Build and run (⌘R).

## Usage

1. **Import** → Load Sample (HIFK Töölö) or paste your list → Create Shot List
2. **Route** → Review map, set start time and start location, follow numbered stops
3. **Shots** → Check off completed shots; tap for framing details
4. **Gear** → Set default camera, 25fps, 16:9, etc.

## Route planning

The route planner uses known coordinates for Töölö/Helsinki locations:

| Location | Area |
|----------|------|
| Töölöntori | Runeberginkatu / Topeliuksenkatu |
| Nordis | Helsingin jäähalli |
| Mannerheimintie | Yliopiston Apteekki corner |
| Nordenskiöldinkatu | Urheilukatu area |
| Reijolankatu | Reijolankatu corner |
| Olympiastadion | Stadium tower shots |
| Kisahalli | Kisahalli exterior |

Time estimates: wide 5m, medium 4m, CU 3m, detail 2m, drone 12m, traffic lights 10m. Walk pace ~5 km/h.

## Tests

```bash
xcodebuild test -project Shotlist/Shotlist.xcodeproj -scheme Shotlist \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

## License

MIT
