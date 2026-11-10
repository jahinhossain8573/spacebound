# Space Mission Game: Realistic Tech Tree (NASA TRL Edition)

This file pairs with `space-mission-game-design-realistic.md`. It defines the complete research tree: science point (SP) costs, NASA Technology Readiness Levels (TRL), prerequisites, and part unlocks for real-world spaceflight hardware.

---

## 1. Research Mechanics & NASA TRL Framework

- Players earn **Science Points (SP)** by completing primary and secondary mission objectives.
- Each tech node represents an advance in **NASA Technology Readiness Level (TRL)** from laboratory demonstration (TRL 4–5) to spaceflight qualification and flight-proven heritage (TRL 8–9).
- A node becomes unlockable when its **Tier Gate** is open and all **Prerequisite Nodes** are owned.
- **Owned at the start (Tier 0, Free):**
  - Launcher: **Rocket Lab Electron**
  - Buses: **GomSpace 1U/3U CubeSat**, **NanoAvionics M12P 12U CubeSat**
  - Power: **GomSpace P31u Body Panels**, **MMA eHaWK Deployable Array (S)**, **GomSpace BP4 Battery (70 Wh)**
  - Avionics/ADCS: **GomSpace NanoMind A3200 OBC**, **NewSpace Fine Sun Sensor**, **ZARM Magnetorquers**, **NovAtel OEM719-SP Space GPS**
  - Comms: **EnduroSat UHF Transceiver II**, **Syrlinks EWC27 S-Band Transceiver**
  - Propulsion: **VACCO MiPS Cold Gas Thruster**
  - Thermal: **Thermal MLI Kit (S)**
  - Payloads: **GomSpace NanoCam C1U**, **Fluxgate Magnetometer (MAG)**
- **Fail-Safe SP Economy:** 
  - Partial or failed missions return **$40\%$ of base SP** as "Lessons Learned".
  - Replaying a completed contract returns **$25\%$ of base SP**.
  - Launcher reliability starts at base values and can be improved with reliability research up to a hard cap of **$99\%$**.

### Tier Progression Gates

| Tier | Unlocks After | Special Campaign Gates |
|---|---|---|
| **Tier 0 (T0)** | Game Start | All baseline CubeSat hardware available immediately. |
| **Tier 1 (T1)** | Mission 1 (BRAC Onnesha) | Vega-C / PSLV launcher opens after Mission 3. |
| **Tier 2 (T2)** | Mission 3 (Delta Flood Watch) | Enables high-power GEO buses and RAD-hard computing. |
| **Tier 3 (T3)** | Mission 4 (Bangabandhu Satellite-1) | Falcon 9 heavy launcher opens after Mission 6. |
| **Tier 4 (T4)** | Mission 6 (Lunar Polar Prospector) | Pragyan-Class Rover & NASA RHU Night Kit open after Mission 7. |

---

## 2. The Six Research Branches

### 2.1 Launch Vehicles & Structures (139 SP)

| ID | Research Node | SP | Tier | Prerequisites | Flight Hardware Unlocked | Real-World Engineering Impact |
|---|---|---|---|---|---|---|
| **L1** | Microsatellite Bus Platform | 6 | T1 | None | **SSTL-50 / BCT-100 Bus** | Enables $60\text{ kg}$ spacecraft with $150\text{ L}$ payload volume. |
| **L2** | Medium-Lift Launch Vehicle | 8 | T1 | Mission 3 Completed | **ESA Vega-C / ISRO PSLV** | LEO capability expands to $2,300\text{ kg}$; opens GTO capability ($1,000\text{ kg}$). |
| **L3** | Midsatellite Bus Platform | 12 | T2 | L1 | **Blue Canyon BCT-500 Bus** | $180\text{ kg}$ structure with $600\text{ L}$ volume for lunar mapping payloads. |
| **L4** | High-Capacity Spacecraft Bus | 16 | T2 | L3 | **Thales Spacebus / Vikram Bus** | $350\text{ kg}$ dry bus for multi-kilowatt GEO comms and lunar landers. |
| **L5** | Component Qualification (Test Campaign I) | 5 | T1 | None | **Thermal & Component Test Facility** | Unlocks optional pre-launch testing; cuts subsystem anomaly risk by $30\%$. |
| **L6** | System TVAC (Test Campaign II) | 12 | T2 | L5 | **Thermal-Vacuum Chamber & Shaker Table** | System-level vibration & TVAC tests; cuts failure risk by $50\%$ and adds $+5\%$ landing roll. |
| **L7** | Propulsion Quality Assurance I | 5 | T1 | None | **Quality Control Program I** | $+2\%$ reliability across all launch vehicles. |
| **L8** | Propulsion Quality Assurance II | 10 | T2 | L7, L5 | **Quality Control Program II** | $+2\%$ additional reliability across all launch vehicles. |
| **L9** | Avionics Redundancy Standards | 18 | T3 | L8, L6 | **Dual-String Avionics Protocol** | $+2\%$ additional reliability across all launch vehicles (capped at $99\%$). |
| **L10** | Composite Payload Adapter Optimization | 12 | T2 | L2 | **Optimized Carbon Clampband** | Adapter overhead penalty drops from $2\%$ to $1\%$ of dry mass. |
| **L11** | Heavy Reusable Launch Vehicle | 35 | T3 | L2, L4, Mission 6 Completed | **SpaceX Falcon 9** | High-energy cislunar capability: $3,800\text{ kg}$ to TLI, $5,500\text{ kg}$ to GTO. |

---

### 2.2 Electrical Power & Thermal Systems (64 SP)

| ID | Research Node | SP | Tier | Prerequisites | Flight Hardware Unlocked | Real-World Engineering Impact |
|---|---|---|---|---|---|---|
| **P1** | Deployable Arrays & Medium Storage | 5 | T1 | None | **Spectrolab Wing (M) & ABS SLC Battery (M)** | Provides $-320\text{ W}$ solar generation and $250\text{ Wh}$ battery reserve. |
| **P2** | Kilowatt Arrays & Heavy Energy Storage | 12 | T2 | None | **Airbus High-Power Array (L) & EaglePicher Battery (L)** | Generates $-1,300\text{ W}$ and stores $2.2\text{ kWh}$ for multi-transponder GEO comms. |
| **P3** | Triple-Junction Solar Cell Optimization | 22 | T3 | P2 | **Spectrolab XTJ Prime Solar Cells** | Increases array generation efficiency by $+15\%$ ($300 \to 345\text{ W/m}^2$). |
| **P4** | NASA RHU & Cryogenic Thermal Shield | 25 | T4 | P2, Mission 7 Completed | **NASA RHU + MLI Lunar Night Kit** | Plutonium-238 decay heat keeps lander and rover electronics alive during 14-day night. |

---

### 2.3 Telecommunications & Deep Space Network (55 SP)

| ID | Research Node | SP | Tier | Prerequisites | Flight Hardware Unlocked | Real-World Engineering Impact |
|---|---|---|---|---|---|---|
| **C1** | High-Data-Rate X-Band Downlink | 6 | T1 | None | **Syrlinks EWC30 X-Band Transmitter** | Boosts downlink bandwidth to $100\text{ Mbps}$ in LEO for multispectral imaging. |
| **C2** | Lossless Data Compression Algorithms | 12 | T2 | C1 | **CCSDS On-Board Image Compressor** | Reduces raw scientific downlink volume by $30\%$ without data loss. |
| **C3** | Deep Space Transponder & 0.3m Dish | 15 | T3 | None | **General Dynamics SDST + 0.3m Cassegrain** | Enables $200\text{ kbps}$ two-way link at lunar distance with NASA DSN ground stations. |
| **C4** | High-Gain Gimballed 1.0m Dish Antenna | 22 | T3 | C3 | **Carbon-Composite 1.0m Reflector** | Provides high-bandwidth $2.5\text{ Mbps}$ at the Moon and $50\text{ Mbps}$ at geostationary orbit. |

---

### 2.4 Guidance, Navigation, Control (GN&C) & In-Space Propulsion (86 SP)

| ID | Research Node | SP | Tier | Prerequisites | Flight Hardware Unlocked | Real-World Engineering Impact |
|---|---|---|---|---|---|---|
| **A1** | Precision 3-Axis Reaction Wheel Array | 5 | T1 | None | **Rocket Lab RW-0.03 RWA** | Active 3-axis pointing control for Earth observation cameras. |
| **A2** | Miniature Optical Star Tracker | 5 | T1 | A1 | **Rocket Lab ST-16 Star Tracker** | Sub-arcsecond autonomous attitude determination for scientific observations. |
| **A3** | Hydrazine Monopropellant Propulsion | 5 | T1 | None | **Aerojet Rocketdyne MR-103G Thruster** | $22\text{ N}$ thrust, $227\text{ s} \ I_{\text{sp}}$ for orbit maintenance and collision avoidance. |
| **A4** | Active Thermal Control for Microsats | 4 | T1 | None | **Thermal MLI Kit (M)** | Regulates component temperatures under continuous solar exposure. |
| **A5** | Radiation-Hardened Deep Space Computing | 12 | T2 | None | **BAE Systems RAD750 OBC** | **Essential for GEO and Moon**. Zero latch-up under cosmic rays and CMEs. |
| **A6** | High-Torque Heavy Reaction Wheels | 10 | T2 | A1 | **Honeywell HR14 High-Torque RWA** | Rapid slewing and pointing stability for large satellites and landers. |
| **A7** | Heavy Bus Cryogenic Thermal Enclosure | 8 | T2 | A4 | **Thermal MLI Kit (L)** | Multi-layer insulation blankets for large GEO platforms and lunar buses. |
| **A8** | High-Performance Bipropellant Apogee Engine | 15 | T2 | None | **Aerojet Rocketdyne R-4D-15 Engine** | $490\text{ N}, 315\text{ s} \ I_{\text{sp}}$. Enables GTO $\to$ GEO circularization and Lunar Orbit Insertion. |
| **A9** | Electric Hall Effect Propulsion | 22 | T3 | A8, P2 | **Safran PPS-1350 / Busek Hall Thruster** | $2,200\text{ s} \ I_{\text{sp}}$. Low-thrust, high-efficiency transfers; requires continuous $350\text{ W}$. |

---

### 2.5 Scientific Instruments & Payloads (188 SP)

| ID | Research Node | SP | Tier | Prerequisites | Flight Hardware Unlocked | Primary Mission Role |
|---|---|---|---|---|---|---|
| **I1** | Cosmic Ray Space Radiation Sensor | 4 | T1 | None | **NASA CRaTER Space Weather Detector** | Measures ionizing radiation environment in Van Allen Belts and cislunar space. |
| **I2** | Multispectral Environmental Imager | 10 | T1 | None | **cosine HyperScout-2 / MultiScape** | **Monitors flood patterns, river deltas, agriculture, and forestry**. |
| **I3** | Thermal Infrared Meteorological Sensor | 10 | T2 | I2 | **Landsat-8 TIRS Thermal Sensor** | Detects cyclone formation, sea surface temperatures, and drought stress. |
| **I4** | High-Resolution Earth Telescope | 12 | T2 | I2 | **WorldView-Class Optical Camera** | Detailed sub-meter ground mapping for urban infrastructure and navigation. |
| **I5** | Commercial Ku/Ka Transponder Suite | 15 | T2 | A5, P2 | **Commercial GEO Transponders** | High-throughput communications transponders (**Bangabandhu Satellite-1**). |
| **I6** | Cislunar Optical Flyby Camera | 8 | T3 | None | **LROC Wide Angle Camera (WAC)** | Captures high-definition imagery during lunar flybys and approaches. |
| **I7** | Lunar Global Mapping Camera Suite | 12 | T3 | I6 | **LROC Narrow Angle Camera (NAC)** | High-resolution lunar surface mapping from polar orbit ($100\text{ km}$). |
| **I8** | Lunar Orbiter Laser Altimeter | 14 | T3 | I7 | **LOLA Laser Altimeter** | 5-beam pulsed laser mapping 3D lunar topography and slope hazards. |
| **I9** | Epithermal Neutron Water-Ice Detector | 15 | T3 | I6 | **NASA LEND Neutron Detector** | **Discovers subsurface water-ice in polar permanently shadowed regions (PSRs)**. |
| **I10** | Thermal Radiometer & Mineral Spectrometer | 15 | T3 | I7 | **Diviner Lunar Radiometer (DLRE)** | Maps surface composition, silicate minerals, and cryogenic cold traps. |
| **I11** | Spaceborne Synthetic Aperture Radar | 30 | T3 | I4, P3 | **Sentinel-1 C-Band Active Radar (SAR)** | Penetrates dense monsoon cloud cover and tropical cyclones for 24/7 imaging. |
| **I12** | Lunar Surface Seismometer | 12 | T4 | G2 | **Apollo / ILSA MEMS Seismometer** | Detects moonquakes and meteoroid surface impact shockwaves. |
| **I13** | Regolith Thermophysical Surface Probe | 10 | T4 | G2 | **ISRO ChaSTE Regolith Thermal Probe** | Measures vertical thermal conductivity gradients down to $10\text{ cm}$ in soil. |
| **I14** | Cryogenic Regolith Core Drill | 18 | T4 | G2 | **Subsurface Core Drill System** | Penetrates up to $1.0\text{ m}$ to extract pristine volatile ice samples. |
| **I15** | Precision Laser Retroreflector Array | 3 | T4 | G4 | **NASA Goddard LRA Passive Array** | Sub-millimeter laser ranging from Earth to measure lunar orbital dynamics. |

---

### 2.6 Lunar Surface Guidance & Landing Systems (115 SP)

| ID | Research Node | SP | Tier | Prerequisites | Flight Hardware Unlocked | Real-World Engineering Impact |
|---|---|---|---|---|---|---|
| **G1** | High-Frame-Rate Descent Camera | 5 | T4 | None | **Descent Optical Camera** | Captures real-time descent imagery; returns bonus science data upon touchdown. |
| **G2** | Dual-Band Radar Altimeter & Velocimeter | 20 | T4 | None | **Chandrayaan-3 KaRA + LDV Suite** | **Mandatory for Lunar Soft Landing**. Measures altitude and 3D velocity vectors. |
| **G3** | Throttleable Lunar Descent Engine | 25 | T4 | A8 | **ISRO LPSC 800N Cluster / Apollo DPS** | $2,400\text{ N}$ thrust, throttleable from $30\%$ to $100\%$. Enables soft touchdown. |
| **G4** | Crushable Lunar Landing Struts | 8 | T4 | G3 | **Hexagonal Shock-Absorbing Legs** | Dissipates residual vertical kinetic energy upon touchdown (up to $2.0\text{ m/s}$). |
| **G5** | Autonomous Powered Descent Guidance | 10 | T4 | G2 | **Guidance Algorithm Software Package** | Projects fuel consumption, calculates gate turn-over, displays pre-launch landing odds. |
| **G6** | Flash Lidar Hazard Avoidance System | 22 | T4 | G2, G5 | **LHDAC Real-Time Hazard Lidar** | Scans landing ellipse for boulders and steep slopes; adds $+15\%$ landing safety roll. |
| **G7** | Rocker-Bogie Lunar Micro-Rover | 25 | T4 | G4, P2, Mission 7 Completed | **Pragyan-Class 6-Wheel Micro-Rover** | Deploys from lander ramp; traverses surface obstacles to conduct distributed science. |

**Total Tech Tree Cost: 647 Science Points (SP).**

---

## 3. Mission Rewards & Progression Balance

The campaign awards **865 Total Science Points (SP)**, creating an engaging, balanced progression where players have room for experimentation while facing tight engineering choices during the transition to geostationary and lunar exploration.

| # | Mission Title | Real-World Inspiration | SP Reward | Money Reward | Key Tech Unlocked |
|---|---|---|---|---|---|
| **1** | **First Signal: BRAC Onnesha** | **Bangladesh's 1st Satellite (1U CubeSat)** | **15 SP** | $\$16\text{M}$ | Tier 1 Tech Branches, S-Band Transceiver |
| **2** | **Orbital Sentinel** | Early Earth Observation CubeSat | **30 SP** | $\$28\text{M}$ | Microsatellite Bus, X-Band Downlink |
| **3** | **Delta Flood Watch** | Disaster Monitoring over South Asia | **70 SP** | $\$52\text{M}$ | Vega-C Launcher, Midsat Bus, Tier 2 Branches |
| **4** | **Geostationary Gateway** | **Bangabandhu Satellite-1 (GEO)** | **110 SP** | $\$175\text{M}$ | BAE RAD750, Bipropellant Engine, Tier 3 Branches |
| **5** | **Cislunar Pathfinder** | High-energy lunar flyby (CAPSTONE) | **80 SP** | $\$105\text{M}$ | Deep Space Antenna, LOLA Altimeter |
| **6** | **Lunar Polar Prospector** | Polar Water-Ice Search (NASA LRO) | **130 SP** | $\$155\text{M}$ | SpaceX Falcon 9, Descent Engine, Tier 4 Branches |
| **7** | **Lunar Touchdown** | South Pole Soft Landing (Surveyor/Vikram) | **180 SP** | $\$210\text{M}$ | Pragyan Rover, NASA RHU Lunar Night Kit |
| **8** | **South Pole Endurance & Rover** | Lunar Night Survival & Deep Drilling | **250 SP** | $\$420\text{M}$ | Master Mission Badge, Infinite Sandbox Mode |
| | **Campaign Total** | | **865 SP** | | |

---

## 4. Minimum Research Path (Difficulty Tuning)

The table below outlines the optimal, lowest-cost research path required to fulfill primary requirements for each mission:

| Mission | Minimum New Nodes Needed | SP Cost | Cumulative SP Spent | SP Available Before Mission | Spare SP Buffer |
|---|---|---|---|---|---|
| **1: BRAC Onnesha** | *(T0 baseline hardware)* | 0 | 0 | 0 | 0 |
| **2: Orbital Sentinel** | A1 (Reaction Wheels) | 5 | 5 | 15 | 10 |
| **3: Delta Flood Watch** | L1 (Microsat), I2 (HyperScout-2) | 16 | 21 | 45 | 24 |
| **4: Bangabandhu Satellite-1** | L2, L3, P2, A5, I5, A8, A4, A1 | 83 | 104 | 115 | 11 |
| **5: Cislunar Pathfinder** | I6 (Flyby Cam), C3 (Deep Space Transponder) | 23 | 127 | 225 | 98 |
| **6: Lunar Polar Prospector** | I7 (Mapping Cam), I9 (LEND Detector), A2 (Star Tracker), C4 (High-Gain Dish) | 54 | 181 | 305 | 124 |
| **7: Lunar Touchdown** | G2 (Landing Radar), G3 (Descent Engine), G4 (Landing Gear) | 53 | 234 | 435 | 201 |
| **8: South Pole Endurance** | L4 (Heavy Bus), L11 (Falcon 9), P4 (NASA RHU Kit), G7 (Pragyan Rover), I14 (Core Drill) | 119 | 353 | 615 | 262 |

### Key Pedagogical Design Insights:
- **Mission 4 is the Crucial Engineering Squeeze:** With only $11\text{ SP}$ spare, students are forced to prioritize core orbital mechanics (bipropellant engine and rad-hard computer) over optional luxuries.
- **The Entire Tech Tree Cannot Be Bought Early:** The full tree costs $647\text{ SP}$, while the total pool before Mission 8 is $615\text{ SP}$. Students must plan their technology roadmap carefully.
- **Mission 7 Uses the Midsat Platform:** Mission 7 can be accomplished on the Midsat bus ($\sim 250\text{ kg}$ dry mass with landing gear, radar, and engine). The heavy bus is reserved for Mission 8's rover and deep drilling suite.

---

## 5. Developer JSON Data Schema

Game developers can ingest this data structure directly into Unity, Godot, or web-based engines:

```json
{
  "nodeId": "A5",
  "name": "Radiation-Hardened Deep Space Computing",
  "branch": "adcs_propulsion",
  "tier": 2,
  "costSP": 12,
  "prerequisites": [],
  "campaignGate": null,
  "trlLevel": 9,
  "unlocksParts": ["bae_rad750_obc"],
  "effects": [
    {
      "type": "radiationImmunity",
      "value": 1.0,
      "description": "Completely prevents single-event upsets and CMEs from corrupting spacecraft flight computer."
    }
  ]
}
```

```json
{
  "partId": "bae_rad750_obc",
  "name": "BAE Systems RAD750 OBC",
  "manufacturer": "BAE Systems",
  "subsystem": "avionics",
  "massKg": 2.5,
  "volumeLiters": 1.2,
  "powerDrawWatts": 10.0,
  "costMillions": 3.2,
  "techTier": 2,
  "flightHeritage": "Lunar Reconnaissance Orbiter (LRO), Kepler, Mars Curiosity",
  "requiredForEnvironments": ["GEO", "Lunar"]
}
```