# PS4 version of HAIRPIN RUSH — plan & status

## Facts
- The game is **Godot 4.3 (GDScript)**. Godot has **no PS4 export**, and no Godot runtime exists for the PS4 homebrew SDK (OpenOrbis, C/C++ with SDL2/GL-like APIs).
- `ps4-native.reference.yml` (from the owner's other game *Warzone Native*) builds a **native C++ PKG** with the OpenOrbis toolchain. It cannot build this repo: there is no `native/` C++ code here.
- So a PS4 build of this game = a **new native C++ port** (menu + simplified racing), not an export. Large; nothing of it exists yet.

## Done (works in the Godot game today)
- Gamepad support (PS4/PS5/Xbox pads, wired or Bluetooth) — `scripts/controls.gd` (autoload `Controls`):
  steer = left stick, gas = R2, brake = L2; every other action on a re-mappable button (Settings → GAMEPAD → "Gamepad buttons", `scripts/pad_editor.gd`).
- Touch buttons are hidden automatically while a pad is connected (Settings → Touch buttons: Auto / Show / Hide).
- LAN: the game already uses ENet UDP 24565 (play) / 24566 (discovery). A future native PS4 client must speak the same protocol to appear in the phones' LAN list.

## PKG identity (for homebrew packaging, when a native build exists)
In the OpenOrbis sample `Makefile` / `sce_sys/param.sfo`: `TITLE` (shown name), `TITLE_ID` (9 chars, e.g. `BREW00790`-style homebrew id — use an id of your OWN, never a real commercial game's id),
`CONTENT_ID`, `VERSION`; cover/icon = `sce_sys/icon0.png` (512×512) and optional `pic0.png`/`pic1.png` background. Use `art/icon.png` / `art/cover.png` as sources.

## Next steps (if the owner wants the native port)
1. Create a separate repo (e.g. `hairpin-ps4-native`) from the OpenOrbis hello_world sample; get the CI from `ps4-native.reference.yml` building a "hello" PKG first.
2. Port in this order: window/pad input → menu → one track + one car (software or GL) → ENet-compatible LAN client → sounds.
3. Test on the owner's jailbroken PS4 (the cloud sandbox cannot run PS4 code).
