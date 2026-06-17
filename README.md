# AS2P — AnimatedSprite to AnimationPlayer

[![Godot](https://img.shields.io/badge/Godot-4.x-478cbf?logo=godot-engine)](https://godotengine.org/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

A Godot 4 editor plugin that converts **AnimatedSprite2D/3D** SpriteFrames animations to **AnimationPlayer** tracks — with selective import so you never overwrite manually tuned work.

---

## Why this exists

AnimatedSprite2D is great for slicing up spritesheets and previewing frame-by-frame pixel art. But it can't do what AnimationPlayer can — precise timeline control, property blending, method calls, and integration with AnimationTree blend spaces.

The original [AS2P](https://github.com/poohcom1/godot-as2p) solved the conversion problem, but it was all-or-nothing. Every import overwrote **all** animations in the AnimationLibrary, destroying any manual timing adjustments or custom tracks you'd added.

**This fork adds selective import.** Check a box. Import only that animation. Keep the rest untouched.

---

## What's new in this fork

| Feature | Original AS2P | This fork |
|---|---|---|
| Import mode | All animations at once | Checkbox-based, per animation |
| Overwrite protection | None — always overwrites | Marks existing animations `(exists)`, unchecked by choice |
| Batch selection | None | Select All / Deselect All buttons |
| Animation list | No preview | Scrollable list showing all SpriteFrames animations |
| Node switching | Manual refresh | Auto-refreshes list when switching sprite nodes |

---

## Installation

1. Copy the `addons/AS2P` folder to your project's `addons/` directory.
2. Open Godot. Go to **Project → Project Settings → Plugins**.
3. Find **"Animated Sprite to AnimationPlayer"** and check **Enable**.

```
your-project/
└── addons/
    └── AS2P/
        ├── plugin.cfg
        ├── plugin.gd
        ├── InspectorConvertor.gd
        └── NodeSelectorProperty.gd
```

---

## Usage

### Quick start

1. Select an **AnimationPlayer** node in the scene tree.
2. Look at the **Inspector** panel — you'll see a new section: **"Import AnimatedSprite2D/3D"**.
3. Pick your AnimatedSprite2D/3D node from the dropdown.
4. A scrollable checkbox list appears with every animation defined in the SpriteFrames.
5. Check the animations you want. Click **Import**.

### Understanding the UI

```
┌─ Import AnimatedSprite2D/3D ──────────────────────────┐
│                                                        │
│  AnimatedSprite2D/3D Node: [▼ AnimatedSprite2D      ]  │
│                                                        │
│  [Select All]  [Deselect All]                          │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ ☑ idle_down                                      │  │
│  │ ☑ idle_left                                      │  │
│  │ ☑ idle_right (exists)                            │  │
│  │ ☑ move_up                                        │  │
│  │ ☐ move_down (exists)                             │  │
│  │ ☐ ...                                            │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  [ Import ]                                            │
│                                                        │
└────────────────────────────────────────────────────────┘
```

**Dropdown** — Switch between AnimatedSprite2D/3D nodes in the scene. Changing the selection automatically refreshes the animation list below.

**Select All / Deselect All** — Quickly check or uncheck every animation in the list.

**Animation list** — Each row is one SpriteFrames animation:
- `☑ idle_down` — checked by default, ready to import.
- `☑ idle_right (exists)` — this animation already lives in the AnimationLibrary. Importing it will **overwrite** the existing version. Uncheck it if you've manually tuned it.
- `☐ move_down (exists)` — exists but you've unchecked it. Won't be imported.

**Import button** — Converts every checked animation into AnimationPlayer tracks.

### What happens when you import

Each checked animation becomes:
- A **frame track** — keys at each frame boundary, setting the frame index of the AnimatedSprite2D.
- An **animation track** — a single key at time 0 that sets the animation name.
- Placed in the **global AnimationLibrary** (the unnamed `""` library on the AnimationPlayer).

The conversion preserves:
- **Frame timing** (from SpriteFrames frame durations)
- **Animation speed** (FPS setting)
- **Loop mode** (linear looping on/off)

### Common workflows

**Adding new animations to an existing AnimationTree**

Your blend spaces are already set up with `idle_*` and `move_*` animations. Now you've added `idle_hold_*` frames to the spritesheet.

1. Create the new animations in the SpriteFrames resource.
2. Open the plugin UI on the AnimationPlayer.
3. The new animations appear in the list without `(exists)`.
4. Uncheck everything except the 8 new `idle_hold_*` animations.
5. Click Import. Only the new ones are added.

**Overwriting a specific animation you want to re-import**

1. Check only that animation.
2. Click Import. The existing track is replaced with fresh timing.

**Full re-import (like the original plugin)**

1. Click **Select All**.
2. Click **Import**. Every animation is regenerated.

---

## How it works

The plugin registers an `EditorInspectorPlugin` that adds custom controls to the AnimationPlayer inspector. When you click Import:

1. It reads each checked animation from the selected AnimatedSprite2D's `SpriteFrames`.
2. Calculates keyframe timing based on frame durations and animation speed.
3. Creates or updates `Animation` resources in the AnimationPlayer's global library.
4. Each `Animation` gets two tracks: `:frame` (which frame to show) and `:animation` (which SpriteFrames animation to use).
5. The editor selection is briefly deselected and reselected to force the Animation panel to refresh.

---

## Compatibility

- **Godot 4.x** — tested on 4.6
- **AnimatedSprite2D** and **AnimatedSprite3D**
- Works alongside **AnimationTree** blend spaces

---

## License

MIT — see [LICENSE](LICENSE).

Original plugin by [poohcom1](https://github.com/poohcom1). Fork and enhancements by Christian J.
