# HAIRPIN RUSH (هيربن راش) — AI hand-off guide / دليل التسليم لأي ذكاء اصطناعي

> Give this file to a fresh AI session and it will know the project, the owner's constraints, how everything was built and
> tested, and what is unfinished. Keep it updated when you finish a task (add a line to section 10).
> أعطِ هذا الملف لأي ذكاء اصطناعي جديد ليفهم المشروع وطريقة العمل وما تم إنجازه وما بقي.

---------------------------------------------------------------------------------------------------

## 0. Summary (عربي مختصر)

- اللعبة: **HAIRPIN RUSH / هيربن راش** — لعبة سباق سيارات (Godot 4.3، 3D مكعبات، Compatibility renderer) فيها وضع Solo/LAN/Online، سباق فرق (سائق + حامل خريطة)، كراج وتخصيص، مهنة (Career)، متجر، إعلانات AdMob، ولوحة إدارة منفصلة.
- المالك يعمل **من الآيفون فقط** عبر موقع GitHub + GitHub Actions (لا كمبيوتر). يجرّب على أندرويد (APK) وآيفون (IPA غير موقّع). يتكلم **عربي ليبي** — أجبه بالعربي المختصر.
- الاستوديو: **KRG Studios**. الترخيص مملوك (ملف `LICENSE`)؛ لا تنسخ/تنشر الكود.
- الرفع: `git push origin HEAD:main` إلى `eab71334-web/P2P-Pursuit` (المستودع انتقل: `https://github.com/eab71334-web/P2P-Pursuit.git`).
- أي شيء تجرّبه: اختبره محلياً بصور Godot (xvfb) قبل الرفع، وقل للمالك بصدق ما اختُبر وما لم يُختبر (لم يُختبر على هاتف حقيقي إلا إذا أخبرك هو).

---------------------------------------------------------------------------------------------------

## 1. Owner & working rules

| Item | Value |
|---|---|
| Language | Arabic (Libyan dialect). Short replies, no long recaps. Say what was tested vs not tested. |
| Devices | iPhone (main) + Android phone (testing). No PC. All builds via GitHub Actions. |
| Repo | `eab71334-web/P2P-Pursuit` (branch `main`). Admin app/backend: `eab71334-web/sabak-admin-app`. |
| Commit trailers | End every commit with the attribution lines the harness gives (Co-Authored-By + Claude-Session). |
| Honesty | Never claim a feature works on the phone unless the owner confirmed. Report limits plainly. |
| Do NOT change | The road (track generation), the old car-repair method (hood lever → exit → lift hood → extinguisher). |
| Secrets | `ads config LIVE.json` in the repo root may hold REAL AdMob ids — review/remove from the public repo; never print keys. |

The saved Claude skill **`github-game-workflow`** (account level, not in repo) describes: clone → test → commit → push → report in Arabic.

---------------------------------------------------------------------------------------------------

## 2. Build & release (GitHub Actions) — `.github/workflows/`

| Workflow | What |
|---|---|
| `android.yml` | APK (push to main + manual). Godot 4.3.0 via `chickensoft-games/setup-godot@v2`, Android SDK 34, gradle build. |
| `ios.yml` | Unsigned IPA (macOS runner). Writes `export_presets.cfg` inline. |
| `android-ads.yml`, `ios-ads.yml` | Manual (`workflow_dispatch`) builds WITH AdMob (iOS needs Xcode 16 / Google Mobile Ads SDK 12; plugin in `ios_admob/`). Android ads currently **opt-in** (disabled by default after crashes). |
| (server) | "Online Server (Linux)" builds `rally-server` (see `server/README_SERVER.md`). |

CI runs `godot --headless --import` so new assets/classes register. **New `class_name` scripts need a re-import**
(locally too: `godot --headless --import`), otherwise "Identifier not declared".

Branch `experiment/effekseer`: Effekseer GPU-particle trial (CI downloads the plugin via `tools/get_effekseer.py`; untested; effects must be authored on a computer). Not merged.

---------------------------------------------------------------------------------------------------

## 3. Repo map

```
project.godot          autoloads: L (i18n), Gfx, Sfx, Net, Profile, Backend, Ads, Radio, Score
scenes/                intro, main (menu), world (race), server (headless dedicated server)
scripts/
  world.gd             the race: teams, HUD, cabin buttons (2 pages), hud editor hooks, ceremony, results (~4000 lines)
  car.gd               Car (VehicleBody3D): physics, visuals, engine bay, fire/explosion, mirrors, audio, discs, debris
  car_style.gd         exterior of every model (GREENHOUSE shapes, body kits, wheels, windows/panes, rain-glass windshield)
  car_interior.gd      dash/seats/door cards per model;  car_actions.gd = every cabin action (windows, dome, A/C, hazard, handbrake…)
  avatar.gd            the player character (box avatar + optional "human" rig, see §6)
  rigged_actor.gd      skinned human / mannequin + clothing layers + hair (see §6)
  cloth.gd             verlet cloth (scarf)
  ceremony.gd          podium ceremony (cup/medals, crowd, camera keys, rigged spectators)
  catalog.gd           ALL shop data: cars, paints, stripes, hats, shirts, pants, shoes, emotes, wheels, mods
  profile.gd           save data (coins, gems, loadout, outfits, career progress)
  hud_layout.gd / hud_editor.gd   customizable driving buttons (see §5)
  score.gd             interactive race music (3 synced stems) ; radio.gd = in-car radio
  fx_shaders.gd        shader library (rain on glass, brake-disc heat, speed lines)
  debris.gd            Voronoi shatter debris (pure script)
  settings_ui.gd       Settings page ; gfx.gd = quality presets + toggles
  net.gd               ENet LAN/online; backend.gd/billing.gd/checkout.gd = coins shop, redeem codes, payments
  career*.gd, solo_hub.gd, hub*.gd, menu.gd, intro.gd, tutorial.gd, ...
assets/ual/            Universal Animation Library (45 clips + mannequin) — CC0, Quaternius
assets/ubc/            Universal Base Characters (male/female bodies + hair + beard) — CC0, Quaternius
audio/ , art/ , fonts/ generated sounds (tools/make_*.py), logos, Arabic-capable font
server/ , render.yaml  online server docs ; Render blueprint for the Sabak backend (backend/ lives in the admin repo)
tools/                 sound/score generators (python), montage/screenshot helpers, online_test.sh
docs/AI_HANDOFF.md     this file
```

---------------------------------------------------------------------------------------------------

## 4. How to test locally (the method used for everything)

Godot 4.3 binary is installed in the sandbox (`godot`). Network is allow-listed (GitHub only; PyPI/Blender not reachable).

```bash
rm -rf /tmp/t && mkdir /tmp/t && tar --exclude=.git -cf - . | tar -xf - -C /tmp/t && cd /tmp/t
godot --headless --import                       # needed after adding scripts/assets/class_name
# write a tiny test scene (a .tscn pointing to a script), because `-s` scripts do NOT get autoloads:
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 res://_test.tscn
# the test script saves a screenshot: get_viewport().get_texture().get_image().save_png("/tmp/shots/x.png")
```
Then look at the PNG. Typical tests: `Car.new().setup(...)` + `Avatar.new()` at `car.seat_origin(role)`, `Ceremony.new()` with `entries`,
button editor via `World`, etc. Headless quality auto-detects as "weak" (`Gfx.fx = 0.25`), so force `Gfx.fx = 1.0` when a feature is gated by quality.

Known GDScript/engine gotchas learned here
- Lambdas capture by copy (use arrays/dicts to mutate). `var x := expr` fails when the type can't be inferred → annotate (`var u: Vector3 = …`).
- When patching files with Python `.replace`, `assert` the pattern exists (indentation mismatches fail silently).
- Never `pkill -f` (kills the shell). Touch input also emits emulated mouse events (extra mouse press before ScreenTouch).
- Windshield quad has no UVs → shaders use `VERTEX.xy`. Compatibility renderer: no SDFGI/SSR/etc.; keep shaders simple.
- Imported glTF meshes can carry `ARRAY_CUSTOMn` + 8-bone weights → when rebuilding surfaces null the custom arrays / pass `ARRAY_FLAG_USE_8_BONE_WEIGHTS`.
- ConfigFile can store Dictionaries (used for HUD layouts).
- `SkeletonIK3D` (deprecated but working in 4.3) is used for the driver's hands.

---------------------------------------------------------------------------------------------------

## 5. Gameplay systems built (reference)

- **Cabin buttons**: 2-page grid in the race (horn, lights, wipers, radio, windows, dome, A/C, hazard, flash, handbrake, greet, mirrors…). Actions are dicts `{side,dur,lean,events:[{t,fn,done}],pose:Callable}` in `car_actions.gd`; network relay through `net_event(what,val)` → world `send_cabin`/`cabin_sync` → `remote(what,val)`. Remote cars are visual only (physics frozen).
- **Customizable HUD buttons** (`hud_layout.gd`, `hud_editor.gd`): move/resize/rotate/reset, multi-select, pinch/twist, 3 layout slots + "+" unlimited, Save/Delete, Exit discards, add/remove buttons dialog; first-run intro card; Settings row "Buttons layout"; in-race BUTTONS zone. Layout = anchors as screen fractions + offsets.
- **Debris** (`debris.gd`): Voronoi cell shards (RigidBody3D) on hard crashes/explosion.
- **Interactive music** (`score.gd`): 3 stems in `AudioStreamSynchronized`; Settings "Race music": radio | interactive | off.
- **Shaders** (`fx_shaders.gd`): rain droplets on windshield (wipers clear), brake-disc glow, speed lines.
- Older (see git log): team race, online server, career, shop/chests/redeem codes, AdMob, replay, stickers, podium ceremony, tutorials.

---------------------------------------------------------------------------------------------------

## 6. Characters: Classic (default) vs Human (EXPERIMENTAL)

The owner asked for **two versions**: the main game keeps the original **block characters**; the realistic human is an **opt-in beta**.

- Switch: **Settings → "Characters (experimental)" → Classic | Human (beta)**; stored as `Gfx.human_chars` (default `false`) in `user://` gfx config.
- Classic path: unchanged box avatar code in `avatar.gd` (torso/limbs/legs/helmet boxes, box IK for arms).
- Human path (`Gfx.human_chars == true`, only for OTHER players' avatars — the local player sees only his own hands in first person):
  - `RiggedActor.setup_human(female, skin)` loads `assets/ubc/base/Superhero_{Male,Female}_FullBody.gltf` (real face, eyes, fingers) and copies the
    45 clips from `assets/ual/UAL1.glb` into an `AnimationPlayer`. Both use the **same 65-bone Quaternius skeleton**, so every clip plays on every body.
  - `dress(shirt, pants, shoes, skin, long_sleeve)` builds real garments: it cuts triangles of the body mesh by dominant bone weight
    (torso+arms = shirt, pelvis+legs = pants, feet = shoes), pushes them out along normals, and skins them to the same skeleton (they follow all animation).
    Colours come from the wardrobe (`Catalog.SHIRTS/PANTS/SHOES`).
  - `set_hair(style, color, beard)` hangs hair/beard (`assets/ubc/hair/Origin`) on the Head bone with a `BoneAttachment3D`. Hair only shows for hats `headset`/`bandana`
    (other hats are the old box hats, scaled 0.62 and placed on the head bone each frame; the helmet becomes a sphere).
  - Poses (in `Avatar._rig_update`): seated = "Driving" frozen + `SkeletonIK3D` to the same hand targets as the box arms (wheel, horn, emotes, gestures);
    standing/podium = Dance/Idle_Talking/Idle; outside work = Interact / Pistol_Aim_Neutral; blast = Death01.
  - Racing scarf = `cloth.gd` (position-based cloth, ~40 particles, world-space, wind from car velocity), seated only.
  - `Ceremony._build_spectators()` adds up to 10 rigged spectators (Dance; all dance at the winner announcement) — only when `Gfx.human_chars`.
- Not done / ideas: winner holding the cup in the hand (cup is still a floating box), jacket stripes/logos, finger curl around the wheel, skin-tone shading tuning,
  hats sized to the real head, hair for every hat, local player's own body in third person, female/male choice UI (`outfit["body"] == "f"` is read but not exposed).
- **FBX**: no FBX files were produced. Godot imports glTF/GLB natively (used here). FBX would need the editor FBX importer; if the owner uploads FBX, convert to GLB.

---------------------------------------------------------------------------------------------------

## 7. Third-party assets & licences

| Asset | Source | Licence |
|---|---|---|
| Universal Animation Library (`assets/ual`) | Quaternius | CC0 |
| Universal Base Characters + hair (`assets/ubc`) | Quaternius | CC0 (`assets/ubc/License_Standard.txt`) |
| Game code, generated sounds, logos | KRG Studios | proprietary (`LICENSE`) |
| Owner's forks (not used in game): JoltPhysics, godot-docs, Modeling-Cloth (Blender addon), BoolTool, fast-carve (Blender), Godot_Vertex_Animation_Textures_Plugin (needs Godot 4.5+), AnimationAttacher (Blender) | GitHub forks | — |

Blender add-ons cannot run on the owner's iPhone nor in the sandbox (PyPI/bpy unreachable). Realistic cars were evaluated and NOT done:
the cars are still blocky procedural models; realistic cars would need artist-made `.glb` files uploaded by the owner (then: split wheels, doors, glass, hook to `car.gd`).

---------------------------------------------------------------------------------------------------

## 8. Backend / admin / ads (outside the game repo)

- `sabak-admin-app` (separate repo): Python `server.py` backend (+ mobile admin app) hosted on Render (`render.yaml` here is the blueprint). Handles events, redeem codes, payments (test provider), error reports.
- Game ↔ backend: `backend.gd`, `billing.gd`, `checkout.gd`, `backend_ui.gd`.
- AdMob: `ads.gd`, `ios_admob/`, `ads_config.json` (test ids) — **`ads config LIVE.json` must be reviewed (real ids) and kept out of public history**.
- Online: `server/README_SERVER.md` (one room per mode per server; tested only locally).

---------------------------------------------------------------------------------------------------

## 8b. Gamepad & PS4 (added later)

- `scripts/controls.gd` (autoload `Controls`): pad support + remap (saved in `user://controls.cfg`); steer = left stick, gas = R2, brake = L2; other actions remappable via `scripts/pad_editor.gd` (Settings → GAMEPAD). Touch buttons auto-hide while a pad is connected (`Controls.touch_wanted()` is used in `world.gd` for `show_touch` and `_cab_page`).
- Not verified on a real pad. Menu navigation by pad (focus/`ui_accept`) was not worked on.
- PS4: see `docs/ps4/PS4_PLAN.md` — Godot cannot run on PS4; a PS4 build needs a separate native C++ port (OpenOrbis). `docs/ps4/ps4-native.reference.yml` is the owner's workflow for another game, kept for reference only.

---------------------------------------------------------------------------------------------------

## 9. Open items / waiting on the owner

1. Owner has not yet confirmed on phone: Android buttons/sky/crash fixes, cabin extras, button editor, Score music, rain, human characters.
2. "Phase 5" was mentioned by the owner but never defined — ask.
3. Android ads are opt-in; re-enable later. Effekseer branch build result unknown.
4. Realistic cars (needs uploaded `.glb`), real finger gripping, cup in hand, hat fitting — see §6/§7.
5. README.md in the root is old (Co-Driver Rally era); this file is the current truth.

---------------------------------------------------------------------------------------------------

## 10. Changelog of this large session (newest last)

1. Cabin extras (windows, dome, A/C, hazard, flash, handbrake, greet) + 2-page grid.
2. Customizable HUD button editor (+ slots, add/remove, multi-touch).
3. Voronoi debris, interactive Score music, shader library, (branch) Effekseer trial; GitHub skill saved.
4. Animated rigged spectators at the podium (Quaternius UAL).
5. "Pro body": skinned human seated in the car with hand IK; garments by bone-weight layers; verlet scarf.
6. Every character state uses real skeletal clips (podium, standing, outside, blast).
7. High-detail human (UBC) with face/eyes/fingers, hair & beard on the head bone.
8. Characters switch: Classic (default) vs Human (beta) in Settings; this handoff document.
9. Gamepad support + button remap + touch auto-hide; PS4 plan docs.
