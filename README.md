# spacebounds

Open `project.godot` with Godot 4.3 stable or newer and run the project. The project uses the Compatibility renderer for web support.

The default UI theme uses Roboto, licensed under the SIL Open Font License; see `assets/fonts/OFL.txt`. Theme colors are available under the `Spacebounds` type as `accent`, `warning`, and `failure`.

Run the data checks with `godot --headless --path . --script res://tests/test_data.gd`.

## Building and deploying

Use Godot **4.7.2 stable** with its matching official export templates. In the editor, open **Editor → Manage Export Templates** and install version 4.7.2; alternatively install the matching TPZ from the [official release](https://github.com/godotengine/godot/releases/tag/4.7.2-stable). This machine has the Web threadless and Windows x86-64 debug/release templates installed under `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`.

The commands below assume the Godot executable is available as `godot`. On this Mac it is `/Volumes/860 EVO/SteamLibrary/steamapps/common/Godot Engine/Godot.app/Contents/MacOS/Godot`.

```sh
godot --headless --path . --script res://tests/test_data.gd
mkdir -p build/web build/windows
touch build/.gdignore
godot --headless --path . --export-release "Web"
python3 -m http.server 8000 --bind 127.0.0.1 --directory build/web
```

Open `http://127.0.0.1:8000/` in a browser; opening `index.html` directly does not work. The current main menu intentionally shows an empty navy canvas. Stop the server with Ctrl+C.

The Web preset exports to `build/web/index.html` using Compatibility, with threads, extensions, and PWA caching disabled. It requires no cross-origin isolation headers. Both presets explicitly include the JSON catalogs and font license, and exclude tests, planning documents, and build output.

Package every generated Web file with `index.html` at the archive root:

```sh
(cd build/web && zip -r ../spacebounds-web.zip .)
```

Upload the complete ZIP when hosting is enabled later. It contains the HTML shell, JavaScript, WebAssembly, PCK data, icons, splash image, and audio worklets. `build/` is ignored by Git.

The Windows Desktop preset targets x86-64 at `build/windows/Spacebounds.exe`:

```sh
godot --headless --path . --export-release "Windows Desktop"
```

Windows execution testing remains for the final release issue.

### SPA-7 validation — 2026-11-08

- Godot 4.7.2 data checks and release Web export passed. The malformed-file diagnostics in the data test are intentional.
- The exported PCK was opened independently of the source folder: all four catalogs (3 launchers, 5 buses, 34 components, 6 missions) and the font license were present; tests and planning documents were excluded.
- Chrome for Testing 157.0.8103.38 completed startup and resized to 1280×720 and 900×900. The navy canvas filled both viewports with no console errors or failed requests. Screenshots and console logs are in `build/checks/`.
- Firefox validation is **blocked**: the temporary Firefox 159.0 Playwright build cannot load a profile, including when opened through the desktop launcher. It fails before loading the game. Repeat the browser smoke test in a working Firefox installation before marking that acceptance item complete.
- Public hosting is **deferred**. No public URL is available, and the public deployment acceptance item remains open.

## FlightSim calculations

Run the physics checks with `godot --headless --path . --script res://tests/test_flightsim.gd`. Each check prints PASS/FAIL, and failures exit with status 1.

`FlightSim` provides pure rocket, orbit, burn, eclipse, and battery calculations. Orbital distances and apsis radii are in kilometres from the body's center; orbital speeds are km/s. Rocket delta-v is m/s, mass is kg, Isp and time are seconds, power is watts, and battery capacity is Wh. The tangential-burn helper assumes zero radial velocity at the burn point; unbound results contain only `escaped: true`.

Mission skipping starts with a full battery at the beginning of sunlight, processes sunlight then eclipse, and truncates the final orbit to the requested duration. Reaching zero charge fails; `failed_orbit` is one-based, or -1 on survival. Orbit propagation supports ellipses (`0 <= eccentricity < 1`), with periapsis on +x; invalid elements return `Vector2.ZERO`.

Validated on Godot 4.7.2: all 43 physics checks, the existing data suite, and the project startup smoke check pass.
