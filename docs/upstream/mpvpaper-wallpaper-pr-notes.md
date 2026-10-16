# Notes for an upstream PR: live video wallpapers via mpvpaper (niri)

**Status:** working notes for a future PR against [StatIndet/quickshell](https://github.com/StatIndet/quickshell) (Clavis).  
**Not a PR body yet.** Docs-only branch until the change set is rebased onto upstream **`main`** and scoped for upstream.

**Fork reference (do not paste wholesale into the upstream PR):** `robert-flo/quickshell` `personal`, [PR #19](https://github.com/robert-flo/quickshell/pull/19), tip `0c46e5d`.

---

## Problem

Clavis wallpaper sources were images / solids / palettes. On niri, static `Image` layers cannot play video. Live wallpapers require leaving Clavis or running `mpvpaper` by hand, with no integration into wallpaper scan, picker, theme generation, or backend switching.

## Goal

Treat local video files (`.mp4`, `.webm`, `.mkv`, `.mov`) as first-class wallpaper sources when the desktop backend can host them:

1. Appear in the wallpaper folder scan and Spotlight / Account pickers.
2. On apply: run `mpvpaper` for the video; hide Clavis’s own wallpaper surface while it is active.
3. On apply / clear: Matugen / theme generation always receive the JPEG thumb path, never the video path.
4. Picker previews: show a still frame for videos, not a blank tile.

Non-goals for a first upstream PR:

- Shipping or bundling `mpvpaper` / `ffmpeg` packages.
- Hyprland-specific wiring (this change targets niri layer-shell + backdrop rules).
- Awww backend support for video (awww remains image-only).

## Approach

| Layer | Choice |
|---|---|
| Playback | External `mpvpaper` process (not Qt Multimedia in-process). |
| Control script | `scripts/system/clavis-mpvpaper.sh`: `apply` / `thumb` / `clear`. Override with `CLAVIS_MPVPAPER_SCRIPT`. |
| QML service | Singleton `MpvpaperWallpaperService` (`Process` + `StdioCollector`). Must `import Quickshell` (provides `Singleton`); `import Quickshell.Io` alone is not enough. |
| Integration | `WallpaperService` routes video paths to that service; clears mpvpaper when switching back to image/solid/palette. |
| Thumb warm-up | After a successful wallpaper scan, `WallpaperService.ensureVideoPreviews(unique)` enqueues `thumb` for every video path. Picker tiles also call `previewUrl` → `ensurePreview` if still missing. Failures leave the tile blank until retry; they do not fail the scan. |
| Desktop surface | `DesktopWallpaper.qml` hides Quickshell wallpaper content while `MpvpaperWallpaperService.active`. |
| Scene | `WallpaperSceneService` treats `MpvpaperWallpaperService.active` like an external backend (same as awww): disable panorama / parallax drivers while video is up. |
| niri | `niri_config.py` emits `layer-rule { match namespace="^mpvpaper$"; place-within-backdrop true; }` (same pattern as overview wallpaper). |
| Source kind | `WallpaperSource.js`: `video` kind; `supported(path, backend)` allows video only when backend is not `awww`. |

## Preview strategy (picker)

Qt `Image` cannot decode video URLs. Resolution order:

1. **Freedesktop thumbnail cache** via `DesktopFiles.thumbnail(url)` (`Clavis.Files` / `FileMetadata::thumbnail`). Read-only against `~/.cache/thumbnails/{normal,large,x-large}/`; does not generate.
2. **Clavis cache** `~/.cache/clavis/mpvpaper/<md5(absolute-path)>.jpg` from `clavis-mpvpaper.sh thumb` (`ffmpeg`, one frame at `00:00:01`).
3. Async queue in `MpvpaperWallpaperService`; `previewRevision` increments so Spotlight / Account grids refresh when a thumb appears.

Shared entry point: `WallpaperService.previewUrl(path)` used by `SpotlightWallpaperProvider`, `SpotlightSearchProvider`, `SpotlightResultsPanel`, `AccountPage`.

## Script contract

```text
clavis-mpvpaper.sh apply <video-path>   # stop previous mpvpaper, ensure thumb, start mpvpaper, print THUMB_PATH=
clavis-mpvpaper.sh thumb <video-path>   # ensure thumb only, print THUMB_PATH=
clavis-mpvpaper.sh clear                # stop mpvpaper
```

- `apply` / `thumb`: non-zero if file missing or `ffmpeg` cannot write a JPEG.
- `apply`: also requires `mpvpaper` on `PATH`.
- `ffmpeg` temp outputs must end in `.jpg` or the encoder rejects the path.

## Files in the change set

```text
Common/functions/WallpaperSource.js
Modules/ControlCenter/AccountPage.qml
Modules/Launcher/SpotlightResultsPanel.qml
Modules/Launcher/SpotlightSearchProvider.qml
Modules/Launcher/SpotlightWallpaperProvider.qml
Modules/Wallpaper/DesktopWallpaper.qml
Services/MpvpaperWallpaperService.qml          (new)
Services/WallpaperSceneService.qml
Services/WallpaperService.qml
scripts/system/clavis-mpvpaper.sh              (new)
scripts/system/niri_config.py
tests/qml/tst_WallpaperSource.qml
```

## Dependencies (runtime, not vendored)

- `mpvpaper` — optional soft dependency; without it, `apply` fails cleanly. Document as a known-issue link in deps docs ([GhostNaN/mpvpaper#132](https://github.com/GhostNaN/mpvpaper/pull/132) / [#127](https://github.com/GhostNaN/mpvpaper/issues/127)); do not pin a package version in Clavis.
- `ffmpeg` — frame extract for thumbs / Matugen.
- Optional: any freedesktop video thumbnailer (e.g. `ffmpegthumbnailer`) so preview step 1 can hit without waiting on Clavis’s cache.

List them beside other optional tools (`awww`, `matugen`) in dependency docs.

## Design decisions (for the PR body)

1. **External player vs in-process decode** — compositor/GPU ownership stays with mpvpaper; no Qt Multimedia loop in the shell.
2. **Script boundary** — lifecycle + ffmpeg in bash; QML orchestrates. Packaging can relocate the script via `CLAVIS_MPVPAPER_SCRIPT`.
3. **xdg thumb then ffmpeg** — reuse `DesktopFiles.thumbnail` when present; do not reimplement freedesktop writers; Clavis-owned JPEG cache as fallback (path MD5).
4. **Hide, don’t composite** — while mpvpaper is active, Clavis does not draw the video itself.
5. **niri backdrop rule** — without `place-within-backdrop`, mpvpaper fights overview / wallpaper layers.

## Packaging

- Install `scripts/system/clavis-mpvpaper.sh` with other Clavis system scripts (`Paths.scriptPath("system", …)`).
- Until packages ship it, `CLAVIS_MPVPAPER_SCRIPT` may point at a user-installed copy.
- Layer-rule generation is niri-only (`niri_config.py`). Other compositors are follow-ups.

## Suggested upstream PR shape

- Base: **`StatIndet/quickshell` `main`**.
- One focused PR: video kind + service + script + picker preview + niri rule + `WallpaperSource` tests.
- Title sketch: `feat(wallpaper): mpvpaper live video wallpapers on niri`
- Body: optional deps (with mpvpaper leak link), Singleton/`import Quickshell` gotcha, non-goals (Hyprland, awww video).
- Exclude fork-only agent/docs commits from `personal`.

## Open questions for the maintainer

1. Document `mpvpaper` as optional soft-dep only, or gate the `video` kind behind a runtime probe?
2. Keep thumb warm-on-scan (`ensureVideoPreviews`) plus lazy `ensurePreview`, or only generate when a tile is visible?
## Gotcha (implementation note, not a user acceptance test)

`MpvpaperWallpaperService` must `import Quickshell`. With only `Quickshell.Io`, QML reports `Singleton is not a type` and then a cascading `Type … unavailable` chain across `Services/` that looks like a total shell failure.

## Test plan (for the upstream PR)

Environment: niri session; Clavis built/installed from the PR branch; at least one video under the configured wallpaper directory; `mpvpaper` and `ffmpeg` on `PATH`.

| # | Steps | Success signal |
|---|---|---|
| 1 | Rescan wallpapers / open Spotlight wallpaper mode | Video paths listed with basename |
| 2 | Open picker; wait briefly on a video tile | Still image on the tile (`~/.cache/clavis/mpvpaper/*.jpg` or xdg thumb) |
| 3 | Apply a video | `pgrep -x mpvpaper` non-empty; Clavis wallpaper `Image` hidden; `ThemeService.generateFromWallpaper` is called with `MpvpaperWallpaperService.thumbPath` (JPEG under `~/.cache/clavis/mpvpaper/`), not the `.mp4` |
| 4 | Apply a normal image afterward | `pgrep -x mpvpaper` empty; image wallpaper visible again |
| 5 | Apply a solid, a palette, and an image with awww backend | No `mpvpaper` process; surfaces match pre-change behavior for those modes |
| 6 | `bash scripts/system/clavis-mpvpaper.sh thumb /path/to/video.mp4` | Prints `THUMB_PATH=…jpg` and file exists |
| 7 | Unit | `tst_WallpaperSource.qml`: `kind` / `supported` for video extensions |

---

## Fork-only verification log (Robert)

Not for the upstream PR body.

| Check | How | Result |
|---|---|---|
| Apply on testbench user | Session `sura`, overlay `~/.config/quickshell/clavis` → fork tree | Video wallpaper via mpvpaper |
| Singleton footgun | Before `bc6c887` | Services cascade; after import, `Configuration Loaded` |
| Picker thumbs | After `0c46e5d` | Tiles use Clavis cache / `thumb` |
| `environment.d` | `CLAVIS_MPVPAPER_SCRIPT=$HOME/.local/bin/clavis-mpvpaper.sh` | Script found without system package install |
