[2026 NASA Space Apps Challenge project page](https://www.spaceappschallenge.org/2026/find-a-team/steller-legion/)

[Play Spacebounds in your browser](https://jahinhossain8573.github.io/spacebound/)

# Spacebounds

Spacebounds is a browser-playable satellite engineering and orbital flight simulator built by Stellar Legion for the 2026 NASA Space Apps Challenge, **Space Mission Design Game**. It introduces students to spacecraft design and orbital mechanics through missions inspired by Bangladesh’s space program and regional challenges.

[Watch the project walkthrough](https://www.youtube.com/watch?v=P_-SGncbpRg)

## How to play

1. **Choose a contract.** Review the target orbit, required payload, and budget in Mission Control.
2. **Build a spacecraft.** Assemble a satellite in the 3D Workshop using components based on real hardware. Track mass, internal volume, solar power, battery endurance during eclipse, maneuver capability (Δv), and cost.
3. **Pass the Flight Readiness Review.** Resolve issues with payload fit, launch mass, power, propulsion, and required equipment before liftoff.
4. **Launch and operate in orbit.** Fly a guided or manual ascent, separate the rocket stages, and deploy the satellite. Perform orbital burns, manage power through eclipse, and downlink mission data.
5. **Review and upgrade.** Check your score and flight log in the debrief. Earn funds and spend Science Points in the Technology Tree to unlock hardware for future missions.

## Missions

| Mission | Objective |
| --- | --- |
| First Signal | Recreate the BRAC Onnesha mission by launching a CubeSat into low Earth orbit and sending a beacon to Betbunia ground station. |
| Orbital Sentinel | Observe the Bay of Bengal and downlink imagery via S-band. |
| Delta Flood Watch | Use multispectral imaging from a Sun-synchronous orbit to map monsoon flooding in Bangladesh. |
| Geostationary Gateway | Take inspiration from Bangladesh Satellite-1 and circularize a communications satellite into geostationary orbit. |
| Cislunar Pathfinder | Correct a lunar flyby trajectory, capture imagery, and return to Earth. |
| Lunar Touchdown | Attempt a powered soft landing on the Moon in this stretch mission. |

## Run locally

Open `project.godot` in **Godot 4.7.2** and press **F5**. Spacebounds uses GDScript and the Compatibility renderer.

To build and serve the Web version locally, install the matching Godot export templates, then run:

```sh
mkdir -p build/web
touch build/.gdignore
godot --headless --path . --export-release "Web"
python3 -m http.server 8000 --bind 127.0.0.1 --directory build/web
```

Open [localhost:8000](http://127.0.0.1:8000/) in your browser. The [GitHub Pages workflow](.github/workflows/pages.yml) also builds and publishes the Web export. For Windows, create `build/windows` and export using the **Windows Desktop** preset.

## Data and credits

The project page lists these resources:

- NASA spacecraft and mission data from the [Small Spacecraft Systems Virtual Institute](https://www.nasa.gov/smallsat-institute/), [NASA Technical Reports Server](https://ntrs.nasa.gov/), and [NSSDCA Master Catalog](https://nssdc.gsfc.nasa.gov/nmc/).
- Earth imagery and geography from [NASA Blue Marble](https://science.nasa.gov/earth/earth-observatory/blue-marble-next-generation/base-topography-bathymetry/) and [Natural Earth](https://www.naturalearthdata.com/downloads/110m-physical-vectors/).
- Additional spacecraft references from the [ESA SMILE Technical Red Book](https://sci.esa.int/documents/35028/36141/1567260374869-SMILE_RedBook_ESA_SCI_2018_1.pdf) and [General Catalog of Artificial Space Objects](https://planet4589.org/space/gcat/).

See [CREDITS.md](CREDITS.md) for asset attribution.
