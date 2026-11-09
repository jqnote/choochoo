# Tools

Helper scripts used while building this re-implementation.

* `buf2gltf.py` — decodes the original game's proprietary `.buf` model
  container (a JSON header plus packed vertex buffers) into glTF.
* `convert_all.py` — walks `source/models` and writes one `.glb` per mesh
  into `assets/models`, ready to be imported by Godot.
* `source/models` — the original `.buf` files, downloaded from
  `choochooworld.com/assets/models`.

Run `python3 tools/convert_all.py` from the project root after adding new
source meshes.

The Draco-compressed landscape models (`tree.glb`, `terrain.glb`, …) are
decompressed with the glTF-Transform CLI:

```bash
npx -y @gltf-transform/cli copy in.glb out.glb
```
