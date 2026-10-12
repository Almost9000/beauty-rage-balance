#!/usr/bin/env python3
"""
build_character_assets.py
Extracts Quaternius CC0 Universal Base Character & Modular Outfits,
encodes vertex color body regions into COLOR_0, embeds idle and walk animations,
optimizes textures to 1024x1024, and generates self-contained .glb models
for the modular avatar system.
"""

import io
import json
import os
import struct
import zipfile
from PIL import Image

BASE_ZIP = "/tmp/universal_base_characters.zip"
OUTFITS_ZIP = "/tmp/modular_outfits_fantasy.zip"
ANIM_ZIP = "/tmp/universal_animation_library.zip"

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BASE_OUT = os.path.join(PROJECT_ROOT, "assets/models/characters/base_body/base_body.glb")
TOP_OUT = os.path.join(PROJECT_ROOT, "assets/models/clothing/top/top_peasant_tunic.glb")
BOTTOM_OUT = os.path.join(PROJECT_ROOT, "assets/models/clothing/bottom/bottom_peasant_skirt.glb")
DRESS_OUT = os.path.join(PROJECT_ROOT, "assets/models/clothing/dress/dress_peasant_ensemble.glb")
SHOES_OUT = os.path.join(PROJECT_ROOT, "assets/models/clothing/shoes/shoes_peasant_boots.glb")


def optimize_png(data: bytes, max_dim: int = 1024) -> bytes:
    img = Image.open(io.BytesIO(data))
    if img.width > max_dim or img.height > max_dim:
        scale = max_dim / max(img.width, img.height)
        new_size = (max(1, int(img.width * scale)), max(1, int(img.height * scale)))
        img = img.resize(new_size, Image.Resampling.LANCZOS)
    out = io.BytesIO()
    img.save(out, format="PNG", optimize=True)
    return out.getvalue()


def create_1x1_png(color=(255, 255, 255, 255)) -> bytes:
    img = Image.new("RGBA", (1, 1), color)
    out = io.BytesIO()
    img.save(out, format="PNG")
    return out.getvalue()


def pack_glb(gltf_dict: dict, bin_bytes: bytes, images_dict: dict) -> bytes:
    combined_bin = bytearray(bin_bytes)
    while len(combined_bin) % 4 != 0:
        combined_bin.append(0)

    buffer_views = list(gltf_dict.get("bufferViews", []))
    new_images = []

    fallback_png = create_1x1_png()

    for img in gltf_dict.get("images", []):
        uri = img.get("uri", "")
        img_name = img.get("name", uri)
        data = images_dict.get(uri) or images_dict.get(img_name)
        if not data:
            # Try normalized name
            for k, v in images_dict.items():
                if k.lower() == uri.lower() or k.lower() == img_name.lower():
                    data = v
                    break
        if not data:
            data = fallback_png

        # Optimize image
        try:
            data = optimize_png(data, max_dim=1024)
        except Exception:
            pass

        offset = len(combined_bin)
        combined_bin.extend(data)
        while len(combined_bin) % 4 != 0:
            combined_bin.append(0)

        bv_idx = len(buffer_views)
        buffer_views.append({
            "buffer": 0,
            "byteOffset": offset,
            "byteLength": len(data),
        })
        new_img = {
            "name": img_name,
            "mimeType": "image/png",
            "bufferView": bv_idx,
        }
        new_images.append(new_img)

    gltf_dict["images"] = new_images
    gltf_dict["bufferViews"] = buffer_views
    gltf_dict["buffers"] = [{"byteLength": len(combined_bin)}]

    json_bytes = json.dumps(gltf_dict).encode("utf-8")
    while len(json_bytes) % 4 != 0:
        json_bytes += b" "
    while len(combined_bin) % 4 != 0:
        combined_bin.append(0)

    total_len = 12 + 8 + len(json_bytes) + 8 + len(combined_bin)
    header = struct.pack("<4sII", b"glTF", 2, total_len)
    chunk0 = struct.pack("<I4s", len(json_bytes), b"JSON") + json_bytes
    chunk1 = struct.pack("<I4s", len(combined_bin), b"BIN\x00") + bytes(combined_bin)
    return header + chunk0 + chunk1


def build_base_body():
    print("Building base_body.glb...")
    with zipfile.ZipFile(BASE_ZIP) as z:
        base_gltf = json.loads(z.read("Universal Base Characters[Standard]/Base Characters/Godot - UE/Superhero_Female_FullBody.gltf").decode("utf-8"))
        base_bin = bytearray(z.read("Universal Base Characters[Standard]/Base Characters/Godot - UE/Superhero_Female_FullBody.bin"))

        base_images = {}
        for name in z.namelist():
            if name.endswith(".png"):
                bname = os.path.basename(name)
                base_images[bname] = z.read(name)
        # Map uri typo
        if "T_Eye_Normal.png" in base_images:
            base_images["T_Eye_Normal_png.png"] = base_images["T_Eye_Normal.png"]

    # Encode vertex color region masks into COLOR_0
    # Bit 0 (1): HEAD
    # Bit 1 (2): TORSO
    # Bit 2 (4): ARMS
    # Bit 3 (8): HANDS
    # Bit 4 (16): LEGS
    # Bit 5 (32): FEET
    prim = base_gltf["meshes"][2]["primitives"][0]
    joints_acc = base_gltf["accessors"][prim["attributes"]["JOINTS_0"]]
    weights_acc = base_gltf["accessors"][prim["attributes"]["WEIGHTS_0"]]
    color_acc = base_gltf["accessors"][prim["attributes"]["COLOR_0"]]
    skin_joints = base_gltf["skins"][0]["joints"]
    joint_names = [base_gltf["nodes"][j]["name"] for j in skin_joints]

    j_off = base_gltf["bufferViews"][joints_acc["bufferView"]]["byteOffset"]
    w_off = base_gltf["bufferViews"][weights_acc["bufferView"]]["byteOffset"]
    c_off = base_gltf["bufferViews"][color_acc["bufferView"]]["byteOffset"]

    for i in range(joints_acc["count"]):
        j = struct.unpack("<4B", base_bin[j_off + i * 4 : j_off + (i + 1) * 4])
        w = struct.unpack("<4f", base_bin[w_off + i * 16 : w_off + (i + 1) * 16])
        bname = joint_names[j[w.index(max(w))]]

        mask = 0
        if bname in ["Head", "neck_01"]:
            mask = 1  # HEAD
        elif bname in ["spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r"]:
            mask = 2  # TORSO
        elif bname in ["upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r"]:
            mask = 4  # ARMS
        elif bname.startswith(("hand_", "thumb_", "index_", "middle_", "ring_", "pinky_")):
            mask = 8  # HANDS
        elif bname in ["pelvis", "thigh_l", "thigh_r", "calf_l", "calf_r"]:
            mask = 16  # LEGS
        elif bname in ["foot_l", "foot_r", "ball_l", "ball_r"]:
            mask = 32  # FEET

        base_bin[c_off + i * 4] = mask
        base_bin[c_off + i * 4 + 1] = 255
        base_bin[c_off + i * 4 + 2] = 255
        base_bin[c_off + i * 4 + 3] = 255

    # Transfer Idle_Loop and Walk_Loop from Universal Animation Library
    with zipfile.ZipFile(ANIM_ZIP) as z:
        glb_data = z.read("Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb")
    chunk_len = struct.unpack("<I", glb_data[12:16])[0]
    anim_gltf = json.loads(glb_data[20 : 20 + chunk_len].decode("utf-8"))
    anim_bin = glb_data[20 + chunk_len + 8 :]

    base_node_map = {n["name"]: idx for idx, n in enumerate(base_gltf["nodes"])}
    base_gltf["animations"] = []

    def copy_accessor(anim_acc_idx):
        acc = dict(anim_gltf["accessors"][anim_acc_idx])
        bv = anim_gltf["bufferViews"][acc["bufferView"]]
        bv_offset = bv.get("byteOffset", 0)
        bv_len = bv["byteLength"]
        acc_offset = acc.get("byteOffset", 0)

        data = anim_bin[bv_offset + acc_offset : bv_offset + acc_offset + (bv_len - acc_offset)]

        while len(base_bin) % 4 != 0:
            base_bin.append(0)
        new_bv_offset = len(base_bin)
        base_bin.extend(data)
        while len(base_bin) % 4 != 0:
            base_bin.append(0)

        new_bv_idx = len(base_gltf["bufferViews"])
        base_gltf["bufferViews"].append({
            "buffer": 0,
            "byteOffset": new_bv_offset,
            "byteLength": len(data),
        })

        new_acc_idx = len(base_gltf["accessors"])
        acc["bufferView"] = new_bv_idx
        acc["byteOffset"] = 0
        base_gltf["accessors"].append(acc)
        return new_acc_idx

    for target_name in ["Idle_Loop", "Walk_Loop"]:
        anims = [a for a in anim_gltf["animations"] if a["name"] == target_name]
        if not anims:
            continue
        anim = anims[0]
        new_anim = {"name": target_name, "channels": [], "samplers": []}
        sampler_map = {}

        for s_idx, s in enumerate(anim["samplers"]):
            new_in = copy_accessor(s["input"])
            new_out = copy_accessor(s["output"])
            new_s = {"input": new_in, "output": new_out, "interpolation": s.get("interpolation", "LINEAR")}
            new_s_idx = len(new_anim["samplers"])
            new_anim["samplers"].append(new_s)
            sampler_map[s_idx] = new_s_idx

        for c in anim["channels"]:
            target = c["target"]
            node_name = anim_gltf["nodes"][target["node"]]["name"]
            if node_name in base_node_map:
                new_c = {
                    "sampler": sampler_map[c["sampler"]],
                    "target": {
                        "node": base_node_map[node_name],
                        "path": target["path"],
                    },
                }
                new_anim["channels"].append(new_c)

        base_gltf["animations"].append(new_anim)

    glb_bytes = pack_glb(base_gltf, base_bin, base_images)
    os.makedirs(os.path.dirname(BASE_OUT), exist_ok=True)
    with open(BASE_OUT, "wb") as f:
        f.write(glb_bytes)
    print(f"Generated {BASE_OUT} ({len(glb_bytes)} bytes)")


def build_clothing():
    print("Building clothing GLBs...")
    with zipfile.ZipFile(OUTFITS_ZIP) as z:
        tex_names = ["T_Peasant_BaseColor.png", "T_Peasant_Normal.png", "T_Peasant_ORM.png"]
        peasant_tex = {}
        for tname in tex_names:
            matches = [n for n in z.namelist() if n.endswith(tname)]
            if matches:
                peasant_tex[tname] = z.read(matches[0])

        parts = {
            TOP_OUT: "Modular Character Outfits - Fantasy[Standard]/Exports/glTF (Godot-Unreal)/Modular Parts/Female_Peasant_Body.gltf",
            BOTTOM_OUT: "Modular Character Outfits - Fantasy[Standard]/Exports/glTF (Godot-Unreal)/Modular Parts/Female_Peasant_Legs.gltf",
            SHOES_OUT: "Modular Character Outfits - Fantasy[Standard]/Exports/glTF (Godot-Unreal)/Modular Parts/Female_Peasant_Feet.gltf",
            DRESS_OUT: "Modular Character Outfits - Fantasy[Standard]/Exports/glTF (Godot-Unreal)/Outfits/Female_Peasant.gltf",
        }

        for out_path, gltf_path in parts.items():
            gltf = json.loads(z.read(gltf_path).decode("utf-8"))
            bin_path = gltf_path.replace(".gltf", ".bin")
            bin_bytes = z.read(bin_path)

            glb = pack_glb(gltf, bin_bytes, peasant_tex)
            os.makedirs(os.path.dirname(out_path), exist_ok=True)
            with open(out_path, "wb") as f:
                f.write(glb)
            print(f"Generated {out_path} ({len(glb)} bytes)")


def main():
    build_base_body()
    build_clothing()
    print("All assets built successfully.")


if __name__ == "__main__":
    main()
