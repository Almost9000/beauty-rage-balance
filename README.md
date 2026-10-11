# Beauty, Rage, Balance (BRB)

A Godot 4 3D life simulation about the authentic, self-directed life of an independent, unmarried woman.

## Requirements
- Godot **4.3** (editor binary, Forward+)
- GUT **9.4.0** (vendored in `addons/gut/`)
- Git LFS: `sudo apt install git-lfs && git lfs install`

## Getting started
```bash
git clone git@github.com:Almost9000/beauty-rage-balance.git
cd beauty-rage-balance
git lfs pull
godot -e .            # open in editor
tools/validate.sh     # headless import + tests
```

## Layout
See `docs/` and the folder conventions: features own text resources, `assets/` owns binaries (LFS),
`data/` owns `.tres` content, `levels/` only compose features.
