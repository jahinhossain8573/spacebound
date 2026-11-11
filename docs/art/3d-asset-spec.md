# 3D asset specification

This is the rulebook for every model in the game. It is the repository copy of Linear issue [3D-1](https://linear.app/spacebounds/issue/3D-1/art-direction-and-technical-spec-for-all-3d-assets-read-first); keep both in step when a rule changes. Every model must drop into the game without code changes, so all assets share one scale, one file format, one naming scheme and the same attachment points.

## Art direction

- **Style:** clean, semi-realistic low-poly. Real proportions from photos of the actual hardware, with simplified shapes and flat, readable materials. Think "museum model", not "film VFX".
- **Readability:** parts must be recognisable at small size in the Workshop. Exaggerate key features slightly: dish rims, nozzle bells, lens barrels.
- **Logos:** no company logos or trademarks (SpaceX, Rocket Lab and so on). The Bangladesh flag and the game's own mission patch decals are fine.

### Shared material library

All assets use one small set of materials from `art_source/materials/sb_materials.blend`:

| Material | Look | Used on |
| -- | -- | -- |
| `sb_white_paint` | Off-white, roughness 0.6 | Rocket bodies, bus panels |
| `sb_black_composite` | Near-black, roughness 0.5 | Electron, Falcon 9 interstage |
| `sb_mli_gold` | Crinkled gold foil (normal map), metallic 1, roughness 0.35 | Thermal blankets on buses and the lander |
| `sb_mli_silver` | Same, silver | Optional variant |
| `sb_solar_cell` | Deep blue cells with a thin silver grid, roughness 0.25 | All solar arrays |
| `sb_aluminium` | Brushed, metallic 1, roughness 0.4 | Frames, CubeSat rails |
| `sb_nozzle` | Dark grey metal, slightly burnt rim | Engine nozzles |
| `sb_black_anodised` | Black, roughness 0.7 | Sensors, baffles |
| `sb_glass_lens` | Dark reflective | Camera lenses |

UV conventions for the textured materials:

- `sb_solar_cell`: one texture tile is 4 × 4 cells. Scale the UVs so one cell is about 4 × 8 cm.
- `sb_nozzle`: V runs from the throat (0) to the exit rim (1). The burnt colour is in the top quarter.
- `sb_mli_gold` and `sb_mli_silver`: the crinkle tiles seamlessly; about one tile per 0.3 m looks right.

To use the library, add `art_source/materials` under **Preferences → File Paths → Asset Libraries**, then drag materials from the Asset Browser with the **Append (Reuse Data)** import method. Do not link them, because linked files break when folders move. Rebuild the library with `blender -b --factory-startup --python art_source/tools/sb_materials.py`; edit that script rather than the `.blend`.

Metals show mostly what they reflect. In a Godot scene whose environment has no sky, `sb_aluminium`, `sb_mli_silver`, `sb_mli_gold` and `sb_nozzle` look almost black in the Compatibility renderer. Give 3D scenes a `Sky` and set **Reflected Light → Source** to Sky; the background can stay a flat colour. Preview models with that setup.

An asset may use a material outside the library when nothing in it fits, such as concrete or grass on the launch pad. Name it `sb_<what>` and say why in the asset's issue. The model checks list these as warnings.

## Technical rules

- **Tool:** Blender 4.2 or later; the tools are tested with Blender 5.2. Any tool that exports correct glTF 2.0 is fine, but the export script below only runs in Blender.
- **Format:** `.glb` (binary glTF 2.0) with embedded textures.
- **Units:** 1 unit = 1 metre, **real size**. A 1U CubeSat is 0.1 m wide; the Falcon 9 is 70 m tall. Scene units must be Metric with unit scale 1.0.
- **Transforms:** apply scale on every mesh (Ctrl+A → Scale), and apply rotation on static meshes. Empties and animated objects keep their location and rotation, because the game reads them. Modifiers are applied on export.
- **Materials:** Principled BSDF only (metallic-roughness), with only Image Texture, Normal Map, UV Map, Texture Coordinate and Mapping nodes feeding it. At most 3 materials per asset. The web build uses Godot's Compatibility renderer, which cannot run custom shaders.
- **Textures:** power-of-two sizes. Use JPG for colour and PNG for normal maps. Prefer the shared library over unique textures. Maximum size per category:

  | Category | Maximum texture |
  | -- | -- |
  | Parts | 512 px |
  | Buses, vehicles | 1024 px |
  | Rockets, environment | 2048 px |

  Electron, Falcon 9, and Vega-C use full-length livery textures up to 4096 px to keep their markings legible in close-up.

- **Triangle budgets:** the upper limits are enforced. The lower numbers are guidance; a simple part may be smaller.

  | Asset | Triangles |
  | -- | -- |
  | Small parts (sensors, antennas) | 200 – 1,500 |
  | Large parts (arrays, dishes, engines) | 1,000 – 4,000 |
  | Buses | 1,000 – 6,000 |
  | Rockets | 8,000 – 25,000 |
  | Launch pad and other environment pieces | ≤ 15,000 |
  | Lander or rover | ≤ 12,000 |

  The whole visible scene should stay under about 150,000 triangles, because the game must run in a browser.
- **Total size:** all models together stay under 25 MB, so the web build stays small.

## Axes: Godot and Blender

Godot is Y-up and the front of a model faces −Z. The exporter converts Blender's Z-up axes, so model in Blender like this:

| Godot | Blender |
| -- | -- |
| +Y (up) | +Z |
| −Z (front) | +Y. Blender's Front view (numpad 1) looks at the model's back. |
| +X (right) | +X |

Use **Single Arrow** empties for attachment points. The arrow is the empty's local Z axis in Blender, which becomes its +Y axis in Godot. Point the arrow the way the rules below say +Y should point.

## Origins and attachment points (the code depends on these)

Empties become `Node3D` nodes in Godot. Use these exact snake_case names, without Blender's `.001` suffixes. Avoid object names ending in Godot import hints such as `-col`, `-noimp` or `-loop`, because Godot changes how it imports those nodes.

- **Parts** (antennas, instruments, engines, solar wings): the origin is at the centre of the face that touches the bus, and the part extends along **+Y**. The code rotates the part to whichever bus face it mounts on.
- **Buses:** the origin is at the geometric centre and the size matches `dimensionsMeters` in `data/buses.json` within 10%. Add these empties, each with +Y pointing outward:

  | Empty | Position | Blender arrow points |
  | -- | -- | -- |
  | `mount_top` | Centre of the top face | +Z |
  | `mount_bottom` | Centre of the bottom face | −Z |
  | `mount_front` | Centre of the front face | +Y |
  | `mount_back` | Centre of the back face | −Y |
  | `mount_left` | Centre of the left face | −X |
  | `mount_right` | Centre of the right face | +X |
  | `array_hinge_left` | Where the left solar wing attaches | −X |
  | `array_hinge_right` | Where the right solar wing attaches | +X |
  | `engine_mount` | Centre of the bottom face | −Z |

  Parts mounted on a face take the empty's whole orientation, so its roll matters too. Turn each empty only as far as it needs: every empty except `mount_front` and `mount_back` keeps its Godot Z axis along the bus's Z axis (Blender: local Y along the bus's Y), and `mount_front` and `mount_back` keep their X axis along the bus's X axis. For `mount_bottom` and `engine_mount`, that is a 180° rotation about X.
- **Rockets:** the origin is at the centre of the base, on the ground. Separable sections are separate child objects:
  - `stage_1`, `stage_2` (and so on), `interstage` if present, `fairing_left` and `fairing_right`. Together the two fairing halves match `fairingDiameterMeters` and `fairingHeightMeters` in `data/launchers.json` within 10%.
  - `payload_mount`: where the spacecraft sits, inside the fairing.
  - `exhaust_stage_1`, `exhaust_stage_2` (one for each stage): at each nozzle exit, with −Y pointing down the plume, so the Blender arrow points up (+Z). The code spawns flame particles here.
- **Deployables** (solar arrays, landing legs, booms): include an action named `deploy`, folded at frame 0 and deployed at about frame 60 (2 seconds at 30 fps). It must not loop. The game can stop it halfway to show a jammed array (event E3), so the middle frame must look plausible. Parts with `"deployable": true` in `data/components.json` must have it; other parts need it only when their issue asks. The exporter writes the frame 0 pose as the model's rest pose. If several objects move, keyframe them in the same `deploy` action.

## Naming and delivery

- The file name equals the game data id: `assets/models/<category>/<id>.glb`, where `<category>` is `launchers`, `buses`, `parts`, `environment` or `vehicles`.
- Keep the source file in `art_source/<category>/<id>.blend`. Godot ignores `art_source/`.
- List every reference photo source and any third-party asset in [`CREDITS.md`](../../CREDITS.md).
- [NASA 3D Resources](https://science.nasa.gov/3d-resources/) can be used as reference, or as a base after checking its usage terms. Credit it if used. Do not use paid or unclearly licensed store models.

## Exporting

Disable rendering (the camera icon in the Outliner) on anything that should not ship, such as reference cubes and photo planes. Then run `art_source/tools/sb_export.py`, either from Blender's Scripting workspace or headless:

```sh
blender -b art_source/<category>/<id>.blend --python art_source/tools/sb_export.py
```

The script refuses to export when units, scale, materials, triangle count or object names break the rules above. Otherwise it writes `assets/models/<category>/<id>.glb` with the correct glTF settings: GLB, +Y up, modifiers applied, textures embedded, animations exported per action.

To reapply the Electron or Falcon 9 livery after a geometry export, run `python3 art_source/tools/paint_launcher.py electron clean.glb painted.glb` (use `falcon9` for Falcon 9). This requires Pillow and embeds the livery in the output GLB.

## Checking a model

Import new files, then run the model checks:

```sh
godot --headless --path . --import
godot --headless --path . --script res://tests/test_models.gd
```

On import, Godot extracts each model's embedded textures next to it as `<id>_<texture>.png` or `.jpg`. Commit those files and their `.import` files with the model.

The checks load every file under `assets/models`. They verify triangle and texture budgets, materials, required empties and their directions, bus and fairing sizes against the game data, `deploy` animations, and the 25 MB total. `tests/fixtures/models/buses/bus_spec_fixture.glb`, rebuilt by `art_source/tools/build_fixture.py`, proves the Blender-to-Godot axis conversion on every run.

The game loads models through `scripts/ModelLibrary.gd`. `instantiate(category, id)` returns `null` until the file exists, so the code keeps its primitive stand-in and assets can land one at a time.

## Definition of done for every asset issue

- [ ] Exported with `sb_export.py`; `test_models.gd` passes, and Godot imports the file with no warnings.
- [ ] Within the triangle and texture budget, using the shared materials.
- [ ] Empties named and oriented exactly as above, and the `deploy` animation where required.
- [ ] Looks correct in the Compatibility renderer (the project's only renderer) next to a 1 m reference cube.
- [ ] Screenshot attached to the issue, and the reference sources in `CREDITS.md`.
