# ApX menu artwork

The button family uses a clipped steel casing with a warm gold perimeter highlight.
The entire label area is clear in every state; no interior rails cross labels.
The idle, hover/focus, activated and disabled images share the same 512x64 frame.
Labels remain live engine text, including localization keys and dynamic labels.
The activated state is feedback after an accepted action; CoD4's menu action
callback does not expose a separate mouse-down/mouse-up pair.

`tools/generate_interface.py` owns the geometry. It writes editable SVG and PNG
sources and a state preview in `art/ui/buttons/`, DXT5 IWI textures with complete
rectangular mip chains, 2D materials and `manifests/13-interface.csv`.
The shared asset writer is in `tools/generate_progression.py`.

```powershell
python -m pip install Pillow
python .\tools\generate_interface.py
.\tools\build.ps1
```

`components/buttons.inc` owns the interactive image button and the existing
`DR_BUTTON`/`DR_BUTTON2` APIs. `components/apx_panel.inc` uses it for prestige
actions. Conditional visibility applies to the artwork and hit area together.
Mouse entry and keyboard focus select the bright frame; leaving restores the
idle frame. Existing extended button description callbacks still run.
New shell buttons use a 12-unit label inset and an 18-unit baseline in a 27-unit
frame. Compatibility buttons retain their width-based inset. Confirmation dialogs
set an explicit nonzero focus text color, keeping labels visible on hover.

`ui/choices_setup_common.menu` wraps the preserved SDK choice macros under
`ui_mp/vendor/`; `components/choices.inc` is its compatibility entry point. It preserves their dvar
controls, focus groups, callbacks and bindings, replacing the background and
focus artwork. Native utility menus and project menus receive the same artwork through this
project-local overlay; the builder restores the actual SDK files after linking.
The catalog browser allows inspecting locked choices but disables Equip until
the server unlock rule passes. Ability availability uses saved challenge stats.

Material definitions are linked into `mod.ff` by the manifest. Textures are
included in `apx_dr.iwd` by the existing `assets/images` archive mapping. Parent
menu files are listed in `manifests/07-menus.csv`; includes compile into those
menus. UI material references do not require a new GSC menu-response handler.
Existing server responses and prestige validation remain in use.

All placement uses CoD4's 640x480 virtual canvas. The Tab scoreboard keeps its
slight gameplay tint, aligned columns and keyboard hints; it has no image buttons.
The no-picmip image flag preserves button resolution independently of world textures.

The asset test decodes the actual DXT5 payload and checks its transparent corners,
opaque center, complete rectangular mip chain and material dimensions/pointers.
SDK menu compilation and dedicated-server loading can be checked locally.
Final mouse/focus appearance still needs a connected game client.

The complete menu flow and actual-model turntable pipeline are documented in
[MENUS.md](MENUS.md). Normal builds consume generated assets; art generation
is optional. The main menu uses separate environment artwork with fullscreen
alignment and never displays the loadout operator.
