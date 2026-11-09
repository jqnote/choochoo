"""Decode the original game's `.buf` model files into glTF for Godot.

The web game stores its track and train meshes in a small custom binary
container: a uint32 header length, a JSON header describing the vertex
attributes and then the packed attribute buffers.  `buf2gltf.py` decodes
that container; this script walks the source folder and writes one `.glb`
per mesh into the Godot project, plus the spline data that the train
follows.

    python3 tools/convert_all.py
"""

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from buf2gltf import read_buf, write_glb  # noqa: E402

ROOT = os.path.dirname(HERE)
SRC = os.path.join(HERE, "source", "models")
DST = os.path.join(ROOT, "assets", "models")
DATA = os.path.join(ROOT, "assets", "data")


def convert_models():
    splines = {}
    for dirpath, _dirnames, filenames in os.walk(SRC):
        for filename in sorted(filenames):
            if not filename.endswith(".buf"):
                continue
            path = os.path.join(dirpath, filename)
            base = os.path.splitext(filename)[0]
            if base.endswith("_SPLINE"):
                header, attrs = read_buf(path)
                positions = attrs["position"]
                distance = 0.0
                for i in range(1, len(positions)):
                    distance += sum(
                        (positions[i][c] - positions[i - 1][c]) ** 2 for c in range(3)
                    ) ** 0.5
                splines[base[:-7]] = {"positions": positions, "distance": distance}
                continue
            sub = "train" if "train" in dirpath else "tracks"
            out = os.path.join(DST, sub, base + ".glb")
            os.makedirs(os.path.dirname(out), exist_ok=True)
            header, attrs = read_buf(path)
            index_type = "H"
            for attribute in header["attributes"]:
                if attribute["id"] == "indices":
                    index_type = {
                        "Uint16Array": "H",
                        "Uint8Array": "B",
                        "Uint32Array": "I",
                    }[attribute["storageType"]]
            write_glb(out, base, header, attrs, index_type)
            print("%-40s -> %s/%s.glb" % (os.path.relpath(path, SRC), sub, base))
    return splines


def main():
    splines = convert_models()
    print("\nspline sources:", ", ".join(sorted(splines)))


if __name__ == "__main__":
    main()
