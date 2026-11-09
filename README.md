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

Mission skipping starts from the current battery charge and orbital phase, processes sunlight and eclipse, and truncates the final orbit to the requested duration. Reaching zero charge fails; `failed_orbit` is one-based, or -1 on survival. Orbit propagation supports ellipses (`0 <= eccentricity < 1`), with periapsis on +x; invalid elements return `Vector2.ZERO`.

Validated on Godot 4.7.2: all 43 physics checks, the existing data suite, and the project startup smoke check pass.

## Workshop preview

Open `scenes/Workshop.tscn` in Godot and run the scene (F6), or run `godot --path . res://scenes/Workshop.tscn`. With no selected campaign mission, it previews Mission 1. Right-drag to orbit, scroll to zoom, or click the 3D view and use the arrow keys and +/-; Reset view restores the camera. Launch is enabled when the readiness review has no failures.

Run the assembly checks with `godot --headless --path . --script res://tests/test_workshop.gd`. Workshop, data, and FlightSim headless checks pass on Godot 4.7.2. A temporary Compatibility Web export loaded in the in-app browser; adding/removing a part and keyboard camera rotation were visually checked. Native scene startup was checked, but native visual interaction, browser scrolling, and resize remain to be verified.

## Campaign flow

New Campaign initializes and saves a new agency; Continue restores `user://save.json`. Mission Select opens the Workshop, and later flight scenes can provide `GameManager.last_result` and enter `scenes/Debrief.tscn` for scoring and settlement. A running mission must be started with `GameManager.start_mission(number)` so the debrief has its attempt identity. Reopening the same debrief does not pay twice. Failed saves can be retried.

Run campaign tests with `godot --headless --path . --script res://tests/test_campaign.gd`. The deliberately corrupt-save case prints a JSON parse error. The campaign, Workshop, FlightSim, and data suites pass on Godot 4.7.2. An isolated Web fixture verified a successful debrief, Mission 2 unlock, saved balances after reload, Workshop navigation, and debug controls; F9 was also checked in a release export. Native visual interaction remains unverified.

## Readiness review

Workshop telemetry updates as parts and propellant change. Run Readiness Review to see individual failures and advisories; Launch requires no failures. Launch saves an independent build snapshot and opens the launch sequence.

Run checks with `godot --headless --path . --script res://tests/test_readiness.gd`. The readiness, Workshop, campaign, FlightSim, and data tests pass on Godot 4.7.2. An isolated Web preview was checked for the report, Mission 1 assembly, live updates, and launch handoff. Native visual interaction and browser resize/scroll checks remain unverified.

`GameManager.current_build` holds `launcher`, `bus`, `installed_components`, `propellant_mass_kg`, and `stats`; stats include power, battery, mass, volume, delta-v, cost, and landing TWR. Mission 7 landing mass uses the 2,600 m/s pre-landing handoff from SPA-23.

## Flight preview

Run `godot --path . res://scenes/FlightView.tscn` (or F6 in the editor). It previews Mission 1 when no mission is selected. Choose 1/10/100/1000x warp and toggle between spacecraft and map views with M. Right-drag or use arrows over the viewport to rotate, and scroll or use +/- to zoom. Battery simulation and mission completion are active; orbital burns are planned separately.

`GameManager.initial_orbit` accepts an `OrbitState` handoff; FlightView copies it. `FlightView.set_orbit()` validates and redraws an orbit without resetting total elapsed time. Lunar missions require their dedicated flight scenes.

Run `godot --headless --path . --script res://tests/test_orbit.gd`. All orbit and existing regression suites pass on Godot 4.7.2. Native rendering was captured in `build/checks/flight-native.png`; Web rendering, warp, camera presets, keyboard rotation, and the eclipse indicator were visually checked. Browser resizing and native interactive controls remain unverified.
## Launch sequence

A ready Workshop build opens the launch countdown. Press Space or Launch now to ignite; subsequent successful launches can skip the ascent. Failed launches cannot be skipped. In debug builds, F9 offers mutually exclusive reliability overrides. Lunar destinations remain unavailable until their dedicated scenes exist.

Run `godot --headless --path . --script res://tests/test_launch.gd`. Launch, orbit, readiness, campaign, Workshop, physics, and data checks passed on Godot 4.7.2. An isolated native capture and temporary Web preview showed the rocket, staging, fairing separation, and flight handoff. Interactive native controls, browser resizing, failure visuals, and frame pacing still need manual verification.

## Battery and mission-time skip

FlightView now charges batteries in sunlight and drains them in eclipse, including at high time warp. Below 15%, the bar flashes red with LOW BATTERY. Depletion stops simulation and opens Debrief after three seconds. Orbit-only previews display battery availability without settling campaign results.

Skip mission time starts from the current charge and orbital phase, emits `GameManager.mission_skip_started(remaining_s)` before calculation, and animates the clock and minimum battery display over three seconds. Mission 4 requires circular GEO before skip is enabled; its maneuver implementation remains a later issue. The helper accepts optional `start_wh` and sunlight-first `phase_s` arguments while preserving existing callers. Minimum battery percentage is passed to campaign scoring.

Run `godot --headless --path . --script res://tests/test_power.gd`. All 16 power checks and existing data, physics, Workshop, readiness, campaign, orbit, and launch suites pass. A temporary Web Mission 1 fixture verified the battery HUD, skip animation, Debrief, payout, and Tier 1 unlock. Native visual interaction, low-battery flashing, and failure presentation remain manually unverified. Alarm audio and event effects belong to later issues.

## Fuel balance

The fuel slider covers the build's remaining allowance, accounting for bus volume, propellant density and ullage, tank and adapter mass, the 10% launch margin, and mission budget. The numeric control still accepts larger amounts for experimentation; the allowance message explains overloads. Missions 1–3 require no spacecraft fuel because their launchers provide the starting orbit.

Run `godot --headless --path . --script res://tests/test_balance.gd` for full readiness checks using parts available at each mission's tier. Example passing fuel amounts are 0.5 kg (optional Mission 1 cold gas), 0 kg (Missions 2–3), 394.694 kg (Mission 4), 0.793 kg (Mission 5), and 840.082 kg (Mission 7). The test lists the complete part combinations. No catalog masses or launcher capacities were changed. Balance, Workshop, readiness and physics checks passed; the revised slider has not been visually checked.

## Continuous launch and flight

The scripted ascent and orbital flight share the same Earth, spacecraft, viewport, and camera. The launch station is hidden during ascent; insertion preserves the rocket's position and camera framing. Right-drag and the wheel control the camera, and M switches between flight and map view. The launch remains scripted and the ascent is visually compressed to 15 seconds.

`godot --headless --path . --script res://tests/test_launch.gd` checks staging, station visibility, insertion continuity, shared camera/viewport ownership, and map switching. Launch, orbit, power, and campaign checks passed. A temporary Web preview was checked from pad through orbit and back from map view; a native run reported no rendering errors.

## Mission 1

The reference build uses P31u panels, BP4 battery, NanoMind A3200 computer and EnduroSat UHF on the 1U/3U bus. The first signal requires a complete powered sunlit pass after eclipse exit; Skip can simulate it. A successful reference mission earns 92.5 points, $16M and 17 SP with existing bonus rules.

Run `godot --headless --path . --script res://tests/test_mission1.gd`. Mission 1 and existing regression suites pass, and the release Web export succeeds. Public hosting remains deferred. The full native and browser campaign playthrough, reload, and resize checks remain to be verified.

## Orbital burns

In FlightView, enter Δv in m/s, choose prograde or retrograde, and execute. The panel shows remaining fuel, available Δv, estimated burn duration, and the predicted apsides. Wait for apoapsis or periapsis to warp to the chosen point; these controls are disabled for circular orbits. The model turns before the impulse, and fuel remains aboard the transient flight state. Escaping or unaffordable burns are rejected. Burns are planar and instantaneous; finite-duration physics and maneuver nodes are future work.

Run `godot --headless --path . --script res://tests/test_burns.gd`. The burn, orbit, launch, power, Mission 1, physics, readiness, and campaign checks pass. An isolated Web preview verified entering 1,470 m/s, waiting for apoapsis, circularizing the GTO orbit, fuel reduction, and enabling mission-time Skip. Public hosting remains deferred.

## Research

Open Research from Mission Select to spend Science Points on parts and effects. Nodes display their tier, prerequisites, cost, unlocks, and status; unavailable future nodes are marked Post-hackathon. Tier gates open after Missions 1, 3, 4, and 5. Mission 3 grants L11 and Falcon 9 automatically. Mission launchers and buses remain fixed; research their required hardware before starting a mission.

`godot --headless --path . --script res://tests/test_research.gd` checks the research path, prerequisites, save rollback and persistence, Falcon grant, and the L10 adapter effect. The source design lists 50 distinct nodes (28 enabled in the hackathon); all 50 are included. Research and existing regression suites pass, and a release Web export succeeds. An isolated browser preview verified the tree, A1 purchase, and updated balance; native interaction and browser resize remain unverified.
