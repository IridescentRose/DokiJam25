#!/usr/bin/env python3
import json, struct, sys
from collections import Counter

# --- CONFIG ---
AIR_ID = 0  # your enum value for Air

# Only put explicit overrides here. Unknown indices will:
#  - error out (default), OR
#  - map to themselves with --auto-identity, OR
#  - map to the number you pass to --default N
MATERIAL_ENUM_OVERRIDES = {
    0: AIR_ID,  # keep this
    1: 1,       # Log
    2: 2,       # Stone
}

def read_chunk(f):
    cid = f.read(4)
    if not cid:
        return None, None, None
    content_size, children_size = struct.unpack("<II", f.read(8))
    content = f.read(content_size) if content_size else b""
    children_end = f.tell() + children_size
    return cid, content, children_end

def flatten_index(x, y, z, sx, sy, sz):
    # ((y * SIZE_Z) + z) * SIZE_X + x
    return ((y * sz) + z) * sx + x

def convert_vox_to_json(vox_path, out_path, auto_identity=False, default_unknown=None):
    with open(vox_path, "rb") as f:
        if f.read(4) != b"VOX ":
            raise RuntimeError("Not a VOX file (missing 'VOX ' header)")
        _version = struct.unpack("<I", f.read(4))[0]

        mv_size = None
        voxels = []

        main_id, _, main_children_end = read_chunk(f)
        if main_id != b"MAIN":
            raise RuntimeError("Invalid VOX: missing MAIN chunk")

        while f.tell() < main_children_end:
            cid, content, children_end = read_chunk(f)
            if not cid:
                break

            if cid == b"SIZE":
                # MagicaVoxel stores size as x,y,z (with y up),
                # but your engine expects (x,y,z) where VOX's second is Z in your coords.
                # You said MV is x,z,y for your engine: reorder (sx, sz, sy).
                sx, sy_vox, sz_vox = struct.unpack("<iii", content[:12])
                mv_size = (sx, sz_vox, sy_vox)  # -> (x,y,z) for your engine

            elif cid == b"XYZI":
                (num,) = struct.unpack("<I", content[:4])
                data = content[4:]
                if len(data) != num * 4:
                    raise RuntimeError("XYZI length mismatch")
                for n in range(num):
                    # VOX gives x,y,z,c. You want (x,y,z) = (x, z, y)
                    x, y_vox, z_vox, c = struct.unpack("BBBB", data[n*4:(n+1)*4])
                    voxels.append((x, z_vox, y_vox, c))

            # skip to next
            f.seek(children_end)

    if mv_size is None:
        raise RuntimeError("Missing SIZE chunk")

    sx, sy, sz = mv_size

    # detect used color indices
    used_indices = sorted({c for (_, _, _, c) in voxels if c != 0})
    counts = Counter(c for (_, _, _, c) in voxels if c != 0)

    # build a mapping function
    def map_color_index(cidx: int) -> int:
        if cidx in MATERIAL_ENUM_OVERRIDES:
            return MATERIAL_ENUM_OVERRIDES[cidx]
        if auto_identity:
            return cidx
        if default_unknown is not None:
            return default_unknown
        # strict mode: fail loudly to prevent silent Air
        raise RuntimeError(
            "Unmapped MagicaVoxel color indices found: " +
            ", ".join(f"{c} (count={counts[c]})" for c in used_indices if c not in MATERIAL_ENUM_OVERRIDES) +
            "\nAdd them to MATERIAL_ENUM_OVERRIDES, or run with --auto-identity, or --default <INT>."
        )

    # fill blocks with Air
    blocks = [AIR_ID] * (sx * sy * sz)

    # write filled voxels
    for (x, y, z, c) in voxels:
        if not (0 <= x < sx and 0 <= y < sy and 0 <= z < sz):
            continue
        mat_id = AIR_ID if c == 0 else map_color_index(c)
        blocks[flatten_index(x, y, z, sx, sy, sz)] = mat_id

    # output (no palette, since blocks directly store material enums)
    out = {
        "version": 1,
        "size": [sx, sy, sz],
        "blocks": blocks
    }
    with open(out_path, "w", encoding="utf-8") as outf:
        json.dump(out, outf, separators=(",", ":"), ensure_ascii=False)

    # helpful stdout
    print(f"Converted {vox_path} -> {out_path}")
    print(f"Size: {sx}x{sy}x{sz}")
    print(f"Used color indices: {used_indices}")
    print("Top indices by count:", ", ".join(f"{c}:{counts[c]}" for c,_ in counts.most_common(8)))

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python vox_to_json.py <input.vox> <output.json> [--auto-identity] [--default <INT>]")
        sys.exit(1)
    vox_path, out_path = sys.argv[1], sys.argv[2]
    auto_identity = ("--auto-identity" in sys.argv)
    default_unknown = None
    if "--default" in sys.argv:
        i = sys.argv.index("--default")
        try:
            default_unknown = int(sys.argv[i+1])
        except Exception:
            print("Error: --default requires an integer value")
            sys.exit(1)
    convert_vox_to_json(vox_path, out_path, auto_identity=auto_identity, default_unknown=default_unknown)
