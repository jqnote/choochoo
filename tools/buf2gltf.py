import json, struct, sys, os, glob

# The original loader computes:  value = (raw + S) * T * delta + from
# with  x = 1 << (8 * bytesPerElement),  S = 0.5 * x for signed types else 0,
# and  T = 1 / x.  Note that x is 1<<16 (not 32768) for 16 bit integers.
TYPES = {
    "Float32Array": ("f", 4, 0.0, 1.0),
    "Uint16Array":  ("H", 2, 0.0, 1.0/65536.0),
    "Uint8Array":   ("B", 1, 0.0, 1.0/256.0),
    "Int16Array":   ("h", 2, 32768.0, 1.0/65536.0),
    "Int8Array":    ("b", 1, 128.0, 1.0/256.0),
    "Int32Array":   ("i", 4, 2147483648.0, 1.0/4294967296.0),
    "Uint32Array":  ("I", 4, 0.0, 1.0/4294967296.0),
}

def read_buf(path):
    d = open(path, "rb").read()
    n = struct.unpack("<I", d[:4])[0]
    hdr = json.loads(d[4:4+n].decode("utf8"))
    body = d[4+n:]
    off = 0
    attrs = {}
    for a in hdr["attributes"]:
        fmt, sz, bias, scale = TYPES[a["storageType"]]
        nc = a["componentSize"]
        cnt = hdr["indexCount"] if a["id"] == "indices" else hdr["vertexCount"]
        nb = cnt * nc * sz
        raw = struct.unpack("<" + fmt * (cnt * nc), body[off:off+nb])
        off += nb
        comps = [[raw[i*nc+j] for j in range(nc)] for i in range(cnt)]
        if a.get("needsPack"):
            pk = a["packedComponents"]
            for row in comps:
                for c in range(nc):
                    p = pk[c]
                    row[c] = (row[c] + bias) * scale * p["delta"] + p["from"]
        attrs[a["id"]] = comps
    return hdr, attrs

def write_glb(path, name, hdr, attrs, index_ctype="H"):
    bin_buf = bytearray()
    views = []
    def add_view(data, target=None):
        while len(bin_buf) % 4:
            bin_buf.append(0)
        off = len(bin_buf)
        bin_buf.extend(data)
        v = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
        if target is not None:
            v["target"] = target
        views.append(v)
        return len(views) - 1

    accessors = []
    def add_accessor(rows, ncomp, ctype, target, minmax=False):
        fmt = {"f": "f", "H": "H", "B": "B"}[ctype]
        values = [c for r in rows for c in r]
        arr = struct.pack("<" + fmt * len(values), *values)
        v = add_view(arr, target)
        mn = [min(r[c] for r in rows) for c in range(ncomp)]
        mx = [max(r[c] for r in rows) for c in range(ncomp)]
        acc = {"bufferView": v, "componentType": 5126 if ctype == "f" else (5123 if ctype == "H" else 5121),
               "count": len(rows), "type": {1:"SCALAR",2:"VEC2",3:"VEC3",4:"VEC4"}[ncomp]}
        if minmax:
            acc["min"], acc["max"] = mn, mx
        accessors.append(acc)
        return len(accessors) - 1

    prim = {"attributes": {}}
    if "position" in attrs:
        prim["attributes"]["POSITION"] = add_accessor(attrs["position"], 3, "f", 34962, True)
    if "normal" in attrs:
        prim["attributes"]["NORMAL"] = add_accessor(attrs["normal"], 3, "f", 34962)
    if "uv" in attrs:
        prim["attributes"]["TEXCOORD_0"] = add_accessor(attrs["uv"], 2, "f", 34962)
    if "indices" in attrs:
        prim["indices"] = add_accessor([[r[0]] for r in attrs["indices"]], 1,
                                       index_ctype, 34963)
    prim["mode"] = 4

    gltf = {
        "asset": {"version": "2.0", "generator": "buf2gltf"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": name}],
        "meshes": [{"name": name, "primitives": [prim]}],
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"byteLength": len(bin_buf)}],
    }
    js = json.dumps(gltf, separators=(",", ":")).encode("utf8")
    js += b" " * ((4 - len(js) % 4) % 4)
    total = 12 + 8 + len(js) + 8 + len(bin_buf)
    out = struct.pack("<III", 0x46546C67, 2, total)
    out += struct.pack("<II", len(js), 0x4E4F534A) + js
    out += struct.pack("<II", len(bin_buf), 0x004E4942) + bytes(bin_buf)
    open(path, "wb").write(out)

if __name__ == "__main__":
    src = sys.argv[1]
    dst = sys.argv[2]
    hdr, attrs = read_buf(src)
    write_glb(dst, os.path.basename(dst), hdr, attrs)
    if "position" in attrs:
        ps = attrs["position"]
        mn = [min(r[c] for r in ps) for c in range(3)]
        mx = [max(r[c] for r in ps) for c in range(3)]
        print(f"{os.path.basename(src):28} verts={len(ps):5} size=({mx[0]-mn[0]:.4f},{mx[1]-mn[1]:.4f},{mx[2]-mn[2]:.4f}) min={['%.3f'%v for v in mn]} max={['%.3f'%v for v in mx]}")
