# Asset Rig Specification: Modular Avatar System

## 1. Overview & Engine Conventions

This specification governs the 3D character pipeline for *Beauty, Rage, Balance* (ADR-05).
The character system uses a modular swap architecture:
- One single base body with a skinned mesh and unified armature.
- Garment assets exported on the identical armature with identical bone names and rest pose.
- Runtime swapping attaches garment `MeshInstance3D` nodes to the shared `Skeleton3D`.
- Body poke-through is eliminated via vertex-color region masking in the body shader.

### Engine Constants
- **Scale:** `1 unit = 1.0 meter`.
- **Character Height:** 1.76 m (standing barefoot).
- **Collision Capsule:** Radius = 0.30 m, Height = 1.75 m.
- **Forward Axis:** `-Z` (Godot convention; `+Y` is Up, `+X` is Right).
- **Format:** glTF 2.0 Binary (`.glb`).
- **LFS Policy:** All `.glb` and image assets are binary tracked via Git LFS.

---

## 2. Armature & Bone Hierarchy

The armature must maintain consistent bone names, rest pose transforms, and joint orientations across the base body and all garment assets.

```
Armature
└── root
    └── pelvis
        ├── spine_01
        │   └── spine_02
        │       └── spine_03
        │           ├── neck_01
        │           │   └── Head
        │           ├── clavicle_l
        │           │   └── upperarm_l
        │           │       └── lowerarm_l
        │           │           └── hand_l
        │           │               ├── thumb_01_l -> thumb_02_l -> thumb_03_l -> thumb_04_leaf_l
        │           │               ├── index_01_l -> index_02_l -> index_03_l -> index_04_leaf_l
        │           │               ├── middle_01_l -> middle_02_l -> middle_03_l -> middle_04_leaf_l
        │           │               ├── ring_01_l -> ring_02_l -> ring_03_l -> ring_04_leaf_l
        │           │               └── pinky_01_l -> pinky_02_l -> pinky_03_l -> pinky_04_leaf_l
        │           └── clavicle_r
        │               └── upperarm_r
        │                   └── lowerarm_r
        │                       └── hand_r
        │                           ├── thumb_01_r -> thumb_02_r -> thumb_03_r -> thumb_04_leaf_r
        │                           ├── index_01_r -> index_02_r -> index_03_r -> index_04_leaf_r
        │                           ├── middle_01_r -> middle_02_r -> middle_03_r -> middle_04_leaf_r
        │                           ├── ring_01_r -> ring_02_r -> ring_03_r -> ring_04_leaf_r
        │                           └── pinky_01_r -> pinky_02_r -> pinky_03_r -> pinky_04_leaf_r
        ├── thigh_l
        │   └── calf_l
        │       └── foot_l
        │           └── ball_l -> ball_leaf_l
        └── thigh_r
            └── calf_r
                └── foot_r
                    └── ball_r -> ball_leaf_r
```

- **Skin Joint Count:** 65 joints.
- **Rest Pose:** Standard A-pose / T-pose with arms angled 45° downward or horizontal, palms down or inward, feet flat at `Y = 0.0`.

---

## 3. Vertex-Color Region Masking (`COLOR_0`)

To prevent mesh poke-through when layered clothing deforms during animation, the base body mesh encodes discrete body region bitmasks into the vertex color attribute (`COLOR_0`).

In glTF, vertex colors are stored as normalized 8-bit integers (`0` to `255`).
In the vertex shader:
```glsl
int region_mask = int(round(COLOR.r * 255.0));
```

### Region Bitmask Table

| Region Name | Bit Value | Integer (`COLOR_0.r`) | Primary Assigned Bones |
|---|---|---|---|
| `HEAD` | `1 << 0` | 1 | `Head`, `neck_01` |
| `TORSO` | `1 << 1` | 2 | `spine_01`, `spine_02`, `spine_03`, `clavicle_l`, `clavicle_r` |
| `ARMS` | `1 << 2` | 4 | `upperarm_l`, `upperarm_r`, `lowerarm_l`, `lowerarm_r` |
| `HANDS` | `1 << 3` | 8 | `hand_l`, `hand_r`, all finger bones |
| `LEGS` | `1 << 4` | 16 | `pelvis`, `thigh_l`, `thigh_r`, `calf_l`, `calf_r` |
| `FEET` | `1 << 5` | 32 | `foot_l`, `foot_r`, `ball_l`, `ball_r` |

### `hides_regions` Uniform & Behavior

In `ClothingItem`:
```gdscript
@export_flags("HEAD:1", "TORSO:2", "ARMS:4", "HANDS:8", "LEGS:16", "FEET:32") var hides_regions: int = 0
```

When garments are equipped, `OutfitSlots` calculates the bitwise OR of all equipped items' `hides_regions`:
```gdscript
var hidden_regions: int = 0
for slot in equipped_items:
    if equipped_items[slot]:
        hidden_regions |= equipped_items[slot].hides_regions
```
The resulting integer is passed to the body material uniform `hidden_regions`. In `body_regions.gdshader`, any vertex matching `(hidden_regions & region_mask) != 0` is discarded across its fragments:
```glsl
varying float v_hide;

void vertex() {
    int region_mask = int(round(COLOR.r * 255.0));
    v_hide = ((hidden_regions & region_mask) != 0) ? 1.0 : 0.0;
}

void fragment() {
    if (v_hide > 0.5) {
        discard;
    }
}
```

---

## 4. Slot Definitions & Equipping Rules

Enums defined in `core/types/enums.gd`:
```gdscript
enum Slot {
    TOP,
    BOTTOM,
    DRESS,
    OUTERWEAR,
    SHOES,
    ACCESSORY,
}
```

### Slot Collision Rules
- Equipping a `DRESS` automatically unequips `TOP` and `BOTTOM`.
- Equipping a `TOP` or `BOTTOM` automatically unequips `DRESS`.
- Equipping into any slot replaces the existing item in that slot.

---

## 5. Poly & Texture Budgets

| Asset Type | Target Triangle Count | Max Triangle Count | Textures | Resolution |
|---|---|---|---|---|
| Base Body | 10,000 – 14,000 | 18,000 | BaseColor, Normal, Roughness | 1024x1024 |
| Top / Shirt | 1,500 – 3,500 | 5,000 | BaseColor, Normal, ORM | 1024x1024 |
| Bottom / Pants | 1,000 – 3,000 | 4,000 | BaseColor, Normal, ORM | 1024x1024 |
| Dress / Full Outfit | 2,500 – 6,000 | 8,000 | BaseColor, Normal, ORM | 1024x1024 |
| Shoes / Boots | 800 – 2,000 | 3,000 | BaseColor, Normal, ORM | 1024x1024 |
| Accessory | 200 – 1,500 | 2,500 | BaseColor, Normal, ORM | 512x512 / 1024x1024 |

---

## 6. Directory Structure & File Naming

### 3D Models (`assets/models/`)
All binary 3D assets live under `assets/models/` and are tracked by Git LFS:
- `assets/models/characters/base_body/base_body.glb`
- `assets/models/clothing/top/top_<name>.glb`
- `assets/models/clothing/bottom/bottom_<name>.glb`
- `assets/models/clothing/dress/dress_<name>.glb`
- `assets/models/clothing/shoes/shoes_<name>.glb`
- `assets/models/clothing/outerwear/outerwear_<name>.glb`
- `assets/models/clothing/accessory/acc_<name>.glb`

### ClothingItem Resource Definitions (`data/clothing/`)
Resource definitions live under `data/clothing/<slot>/<slot>_<name>.tres`:
- `data/clothing/top/top_peasant_tunic.tres`
- `data/clothing/bottom/bottom_peasant_skirt.tres`
- `data/clothing/dress/dress_peasant_ensemble.tres`
- `data/clothing/shoes/shoes_peasant_boots.tres`

---

## 7. glTF Export Settings

When exporting garments or base bodies from 3D DCC tools:
- **Format:** glTF Binary (`.glb`).
- **Includes:** Selected Objects, Custom Properties, Armatures, Meshes, PBR Materials, Textures.
- **Transform:** `+Y Up`, apply transforms.
- **Animation:** Embedded in `base_body.glb` (`Idle_Loop`, `Walk_Loop`) or animation libraries.
- **Skins:** Skinning armature matching named hierarchy; do not rename or prune root or leaf bones.
