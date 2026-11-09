# Choo-Choo World — Godot re-implementation

A Godot 4 re-implementation of the wooden train track builder from
<https://choochooworld.com>.

You build a railway piece by piece on a little diorama island: straight
track, curves, ramps, a tunnel, a passing loop and a crossover. A wooden
locomotive with two log wagons then runs along whatever you built — and
when the line closes back on the station the train runs forever.

## What is implemented

* The full set of track pieces of the original game: three straights, two
  curve radii for each side, a ramp up, a ramp down, a tunnel, a passing
  loop and a crossover — with the same geometry, the same order they are
  joined in and the same rules about where they may be placed.
* Building: hover to preview a piece (green when it fits, red when it
  would overlap the existing track or leave the building area), click to
  add it, undo the last piece or delete the whole line.
* The train: a locomotive with a headlight and two log wagons that follow
  the exact spline of the line, tilt on the ramps, and stop at the end of
  an open line — or run round for ever once the line is closed into a loop.
* Three cameras: an orbiting overview while building, a chase camera and a
  ride in the cab, plus a button that spins the camera around the scene.
* Five colour palettes that paint the line piece by piece, exactly like the
  original.
* Day and night, with the locomotive's headlight lighting the track.
* The diorama: the original island with its hills, lakes, trees, grass,
  flowers and the hot air balloon. Scenery that the track runs through
  disappears, and comes back when the piece is removed again.
* Sharing: the share dialog produces a link that opens the same layout on
  choochooworld.com, and the game reads that link back.
* The original music and sound effects.
* Screenshots of the scene can be downloaded from the camera button.

## Running

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .          # play
/Applications/Godot.app/Contents/MacOS/Godot --path . --headless --selftest   # run the checks
```

Useful command line switches:

| switch | meaning |
|---|---|
| `--data=<track>/<palette>/<day>` | load a shared layout, e.g. `--data=DFFBHFIJB/0/D` |
| `--mode=edit\|view\|follow\|first` | start in a given mode |
| `--night` | start in night mode |
| `--add=straight_0,left_0` | append pieces to the starting layout |
| `--shot=<frames>` | write a screenshot to `/tmp/ccw_shot.png` and quit |
| `--selftest` | run the built-in checks and quit |

## Controls

* **Hover** a track piece in the editor to preview it (green = it fits,
  red = it does not). **Click** to add it to the end of the line.
* The **bin** button deletes the whole line (with a confirmation), the
  **undo** button removes the last piece.
* The **Edit / View** switch at the bottom right toggles between building
  and watching the train.
* **Space** play / pause, **R** reverse, **← / →** change the speed.
* **Drag** with the left mouse button to orbit the camera, **scroll** to zoom.

## Sharing

The share dialog produces a `https://choochooworld.com/?DATA=…` link using
exactly the same encoding as the original web game, so a layout built here
can be opened on the website and vice versa. The engine accepts the same
parameter through `--data=`.

## How it was built

The original game is a Three.js application. Its assets were reused where
possible:

* `assets/models/tracks/*.glb`, `assets/models/train/*.glb` — the original
  meshes, decoded from the proprietary `.buf` format by `tools/buf2gltf.py`.
* `assets/models/landscape/*.glb` — the original island, trees, grass and
  balloon (Draco-compressed glTF, decompressed with `gltf-transform`).
* `assets/images/**`, `assets/textures/**`, `assets/audio/**` — the original
  interface art, track textures and sounds.
* `scripts/spline_data.gd` — the path of every track piece, extracted from
  the original `*_SPLINE.buf` files, so the train follows exactly the same
  line as in the web game.

Everything else — the railway chain, the piece overlap test, the train, the
cameras, the interface and the day/night cycle — is written from scratch in
GDScript.

### Layout of the project

```
scenes/Main.tscn       the entry scene
scripts/game.gd        the game controller
scripts/railway.gd     the chain of track pieces
scripts/track_piece.gd one piece: mesh, spline and collision boxes
scripts/track_data.gd  the piece catalogue and colour palettes
scripts/spline_data.gd generated path data for every piece
scripts/train.gd       locomotive and wagons
scripts/camera_rig.gd  overview / follow / first person cameras
scripts/landscape.gd   the diorama
scripts/ui.gd          the heads-up display
scripts/audio.gd       music and sound effects
scripts/url_manager.gd the shared ?DATA= parameter
scripts/selftest.gd    the built-in checks
tools/                 the model decoder and the original source meshes
```

## Licence note

The models, textures, sounds and interface art belong to the authors of
Choo-Choo World and are included here only so that this re-implementation
can be compared with the original.
