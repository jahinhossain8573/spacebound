# Space Mission Game: Realistic Parts List & Game Loop (NASA Space Apps Edition)

This document updates the space mission engineering game with **real-world flight hardware, authentic launch vehicles, and historical mission milestones** (including Bangladesh's **BRAC Onnesha** and **Bangabandhu Satellite-1**, followed by international **Lunar exploration**). 

Hardware specifications and flight heritage are drawn from **NASA's Small Spacecraft Systems Virtual Institute (S3VI / SPOON)**, the **NASA NSSDCA Master Catalog**, the **ESA eoPortal Directory**, and **satsearch COTS databases**. Numbers are game-balanced and rounded for pedagogical clarity and tuning. Costs are presented in $M (game budget), and research tiers range from **T0** (unlocked at start) to **T4** (advanced lunar exploration).

---

## 1. Core Engineering Rules & Orbital Mechanics

| Rule | Formula / Baseline Value | Real-World Engineering Context |
|---|---|---|
| **Tsiolkovsky Rocket Equation** | $\Delta v = I_{\text{sp}} \cdot g_0 \cdot \ln\left(\frac{m_{\text{wet}}}{m_{\text{dry}}}\right)$<br>$m_{\text{prop}} = m_{\text{dry}} \cdot \left(e^{\frac{\Delta v}{I_{\text{sp}} \cdot g_0}} - 1\right)$ | $g_0 = 9.80665\text{ m/s}^2$. Governs every propulsive orbital maneuver. |
| **Tank Mass Ratio** | $8\%$ of propellant mass | Composite overwrapped pressure vessels (COPV) or titanium tanks. |
| **Propellant Density** | Hydrazine: $1.0\text{ kg/L}$; Bipropellant (MON/MMH): $1.2\text{ kg/L}$ ($+10\%$ ullage margin) | Pressurized tank volume sizing for internal bus layout. |
| **Propellant Cost** | $\$0.005\text{M per kg}$ | Space-grade hypergolic propellant fueling and pad operations. |
| **Solar Generation Baseline** | $300\text{ W/m}^2$ (standard 1 AU Earth orbit) | High-efficiency triple-junction InGaP/InGaAs/Ge cells ($\sim 29.5\text{–}32\%$ AM0 efficiency). |
| **LEO Eclipse Duration** | $\sim 35\%$ of each $90\text{-minute}$ orbit ($\sim 35\text{ min}$ eclipse) | Batteries must supply $100\%$ bus and survival heater power in eclipse. |
| **Lunar Night Duration** | $\sim 354\text{ hours}$ ($14.75\text{ Earth days}$) | Temperatures plummet to $-130^\circ\text{C}$ to $-180^\circ\text{C}$; requires RHUs or high-capacity battery/heater packs. |
| **Launcher Payload Adapter** | Adds $2\%$ to dry payload mass automatically | Standard ESPA ring or clampband separation system. |
| **Engineering Mass Margin** | Warning if total wet mass exceeds $90\%$ of launcher capability ($<10\%$ margin) | AIAA S-120A standard flight margin requirement. |

### Mission $\Delta v$ Budget Reference ($\text{km/s}$)

| Maneuver | Required $\Delta v$ | Operational Notes |
|---|---|---|
| **LEO Station-Keeping & Drag Makeup** | $0.05\text{ km/s per year}$ | Solar cycle and atmospheric drag dependent ($400\text{–}550\text{ km}$). |
| **LEO Disposal / Controlled Deorbit** | $0.10\text{ km/s}$ | Lowers perigee into upper atmosphere to prevent space debris. |
| **GTO $\to$ GEO Circularization & Inclination Removal** | $1.50\text{ km/s}$ | High apogee burn (as performed by Bangabandhu Satellite-1). |
| **Trans-Lunar Mid-Course Correction (MCC)** | $0.05\text{ km/s}$ | Corrects trajectory errors during 3 to 5-day cislunar cruise. |
| **Trans-Lunar Injection (TLI) $\to$ Low Lunar Orbit (LOI)** | $0.90\text{ km/s}$ | Retro-burn into a $100\text{ km}$ polar lunar orbit (LRO heritage). |
| **Low Lunar Orbit $\to$ Soft Touchdown** | $1.90\text{ km/s}$ | Powered braking descent + vertical velocity pitch-over + terminal touchdown. |

---

## 2. Launch Vehicles (Flight Heritage)

All launchers represent real, operational rocket systems.

| Vehicle | Manufacturer / Operator | Usable Fairing ($\varnothing \times \text{H}$) | LEO Payload | GTO Payload | TLI Payload | Launch Cost | Base Reliability | Tech Tier | Real-World Heritage |
|---|---|---|---|---|---|---|---|---|---|
| **Electron** | Rocket Lab | $1.2 \times 2.5\text{ m}$ | $300\text{ kg}$ | None | None | $\$8.5\text{M}$ | $88\%$ | T0 | Dedicated smallsat launcher, Rutherford electric-pump engines. Launched NASA CAPSTONE to Moon (with Lunar Photon). |
| **Vega-C / PSLV** | ESA / Avio / ISRO | $3.3 \times 9.0\text{ m}$ | $2,300\text{ kg}$ | $1,000\text{ kg}$ | $500\text{ kg}$ | $\$45\text{M}$ | $93\%$ | T1 | Solid first/second stages + precision liquid upper stage (AVUM+). Workhorse for medium Earth observation and lunar orbiters. |
| **Falcon 9** | SpaceX | $5.2 \times 13.1\text{ m}$ | $17,500\text{ kg}$ | $5,500\text{ kg}$ | $3,800\text{ kg}$ | $\$70\text{M}$ | $97\%$ | T3 | Reusable two-stage liquid rocket (Merlin 1D). Launched **Bangabandhu Satellite-1** (May 2018), Intuitive Machines Nova-C, and CLPS lunar missions. |

*Notes on Launcher Operations:*
* Sun-Synchronous Orbit (SSO) capacity is approximately $70\%$ of maximum LEO capacity.
* Base launcher reliability increases by $+2\%$ for each acquired reliability research node (capped at $99\%$).

---

## 3. Spacecraft Bus Platforms

Spacecraft buses provide the primary load-bearing structure, internal component mounting bays, wiring harnesses, and thermal backplanes.

| Bus Platform | Reference Heritage | Structure Dry Mass | External Dimensions | Internal Payload Volume | Unit Cost | Tech Tier | Real Mission Example |
|---|---|---|---|---|---|---|---|
| **1U / 3U CubeSat** | Kyutech BIRDS / GomSpace 3U | $1.2\text{–}4.0\text{ kg}$ | $10 \times 10 \times 34\text{ cm}$ | $3.0\text{ L}$ | $\$0.3\text{M}$ | T0 | **BRAC Onnesha** (Bangladesh 1U, 2017), GomSpace GOMX |
| **12U Deep-Space CubeSat** | NanoAvionics M12P / BCT XB12 | $16\text{ kg}$ | $23 \times 23 \times 34\text{ cm}$ | $12.0\text{ L}$ | $\$1.0\text{M}$ | T0 | NASA CAPSTONE (Lunar cislunar navigation) |
| **Microsat Platform** | Surrey SSTL-50 / Blue Canyon BCT-100 | $60\text{ kg}$ | $0.6\text{ m cube}$ | $150\text{ L}$ | $\$3.5\text{M}$ | T1 | Disaster monitoring, rapid revisit constellations |
| **Midsat Platform** | Blue Canyon BCT-500 / General Atomics ESPA-Star | $180\text{ kg}$ | $1.0\text{ m cube}$ | $600\text{ L}$ | $\$10.0\text{M}$ | T2 | Lunar Reconnaissance Orbiter (LRO), scientific observatories |
| **Heavy GEO / Lunar Lander Bus** | Thales Spacebus-4000B2 / Astrobotic Peregrine / ISRO Vikram | $350\text{ kg}$ | $1.8 \times 1.8 \times 1.6\text{ m}$ | $2,500\text{ L}$ | $\$25.0\text{M}$ | T2 | **Bangabandhu Satellite-1** (GEO), Chandrayaan-3 Vikram (Lunar Lander) |

---

## 4. Subsystems & Flight Components

### 4.1 Electrical Power Subsystem (EPS)
*(Negative power indicates power generation)*

| Component | Flight Heritage / Reference | Mass | Volume | Power Gen/Draw | Cost | Tier | Key Engineering Role |
|---|---|---|---|---|---|---|---|
| **GomSpace NanoPower P31u** | GomSpace GaAs 3U Panel | $0.3\text{ kg}$ | External | $-7\text{ W}$ | $\$0.05\text{M}$ | T0 | Body-mounted cells; no deployment mechanism; used on BRAC Onnesha. |
| **MMA eHaWK Deployable Array (S)** | MMA Design CubeSat Wing | $1.0\text{ kg}$ | $0.15\text{ L}$ | $-35\text{ W}$ | $\$0.2\text{M}$ | T0 | Deployable spring-loaded solar wing for 3U/12U CubeSats. |
| **Spectrolab XTJ Deployable Array (M)** | Spectrolab Triple-Junction Wing ($1.0\text{ m}^2$) | $6.0\text{ kg}$ | $1.2\text{ L}$ | $-320\text{ W}$ | $\$1.5\text{M}$ | T1 | High-efficiency rigid panels for Earth observation microsats. |
| **Airbus / Maxar High-Power Array (L)** | GEO / Deep Space Solar Array ($4.0\text{ m}^2$) | $22.0\text{ kg}$ | $4.5\text{ L}$ | $-1,300\text{ W}$ | $\$5.0\text{M}$ | T2 | High-power wings for communications satellites (BS-1 class) and lunar orbiters. |
| **GomSpace BP4 Battery Pack** | 4-Cell Li-Ion Module | $0.25\text{ kg}$ | $0.15\text{ L}$ | $70\text{ Wh}$ store | $\$0.1\text{M}$ | T0 | Supplies bus power during $35\text{-minute}$ LEO eclipse. |
| **ABS SLC Space Battery (M)** | Aerospace Li-Ion Space Battery | $2.2\text{ kg}$ | $1.6\text{ L}$ | $250\text{ Wh}$ store | $\$0.6\text{M}$ | T1 | Medium power storage with radiation-tolerant battery management system. |
| **EaglePicher Deep Space Battery (L)** | High-Capacity Nickel-Hydrogen / Li-Ion Pack | $18.0\text{ kg}$ | $14.0\text{ L}$ | $2.2\text{ kWh}$ store | $\$3.0\text{M}$ | T2 | Powers GEO transponders through eclipse or lunar night heaters. |
| **NASA RHU + MLI Lunar Night Kit** | Radioisotope Heater Unit (Pu-238) + Multilayer Insulation | $4.0\text{ kg}$ | $3.5\text{ L}$ | $0\text{ W elect.} / +10\text{ W th.}$ | $\$3.0\text{M}$ | T4 | Passive decay heat keeps lunar avionics above $-20^\circ\text{C}$ throughout the 14-day night. |

---

### 4.2 On-Board Computer (OBC), ADCS, & Thermal Control

| Component | Flight Heritage / Reference | Mass | Volume | Power Draw | Cost | Tier | Engineering Function & Constraints |
|---|---|---|---|---|---|---|---|
| **GomSpace NanoMind A3200** | ARM Cortex-M3 CubeSat OBC | $0.2\text{ kg}$ | $0.15\text{ L}$ | $1.5\text{ W}$ | $\$0.25\text{M}$ | T0 | Low-power commercial LEO computer; susceptible to heavy cosmic radiation. |
| **BAE Systems RAD750 OBC** | BAE Systems Rad-Hard Processor | $2.5\text{ kg}$ | $1.2\text{ L}$ | $10.0\text{ W}$ | $\$3.2\text{M}$ | T2 | **Mandatory for GEO and Lunar missions**. Immune to solar proton events and single-event latchups. |
| **NewSpace Fine Sun Sensor (FSS)** | Digital Bi-Axial Sun Sensor | $0.08\text{ kg}$ | $0.05\text{ L}$ | $0.1\text{ W}$ | $\$0.05\text{M}$ | T0 | Provides coarse sun vector for safe mode and solar panel pointing. |
| **ZARM Technik Magnetorquers (MTQ)** | Magnetic Torque Rod Triad | $0.4\text{ kg}$ | $0.2\text{ L}$ | $1.2\text{ W}$ | $\$0.1\text{M}$ | T0 | Interacts with Earth's geomagnetic field to detumble. **LEO only; useless at Moon/GEO**. |
| **NovAtel OEM719-SP Space GPS** | Spaceborne GNSS Receiver | $0.2\text{ kg}$ | $0.1\text{ L}$ | $1.0\text{ W}$ | $\$0.15\text{M}$ | T0 | Autonomous real-time orbit determination. **Operational in LEO only**. |
| **Rocket Lab RW-0.03 Reaction Wheels** | Sinclair / Rocket Lab 3-Axis RWA | $1.2\text{ kg}$ | $1.0\text{ L}$ | $4.0\text{ W}$ | $\$1.0\text{M}$ | T1 | Provides fine 3-axis attitude control and payload slewing for microsats. |
| **Honeywell HR14 High-Torque RWA** | Space-Qualified Reaction Wheel Suite | $10.5\text{ kg}$ | $9.0\text{ L}$ | $22.0\text{ W}$ | $\$4.0\text{M}$ | T2 | High angular momentum storage for heavy GEO and lunar observation satellites. |
| **Rocket Lab ST-16 Star Tracker** | Autonomous Miniature Star Tracker | $0.35\text{ kg}$ | $0.3\text{ L}$ | $1.8\text{ W}$ | $\$0.8\text{M}$ | T1 | Arcsecond attitude determination needed for precision Earth and lunar mapping. |
| **Multilayer Insulation (MLI) & Thermal Kits** | S / M / L Thermal Management Kits | $0.3 / 3.0 / 14\text{ kg}$ | $0.2 / 2.0 / 9\text{ L}$ | $0 / 5 / 20\text{ W}$ | $\$0.1 / 0.8 / 3.0\text{M}$ | T0 / T1 / T2 | Sized to bus to survive thermal extremes of space vacuum and lunar shade. |

---

### 4.3 Telecommunications Subsystem

| Component | Flight Heritage / Reference | Mass | Volume | Power Draw | Operational Data Rate & Range | Cost | Tier |
|---|---|---|---|---|---|---|---|
| **EnduroSat UHF Transceiver II** | 437 MHz CubeSat Transceiver | $0.12\text{ kg}$ | $0.1\text{ L}$ | $1.2\text{ W}$ | $9.6\text{ kbps}$ (LEO beacon / emergency uplink) | $\$0.1\text{M}$ | T0 |
| **Syrlinks EWC27 S-Band Transceiver** | S-Band Space Transceiver & Patch | $0.6\text{ kg}$ | $0.35\text{ L}$ | $7.5\text{ W}$ | $2.0\text{ Mbps}$ (LEO command and telemetry) | $\$0.5\text{M}$ | T0 |
| **Syrlinks EWC30 X-Band Transmitter** | High-Rate X-Band Transmitter | $2.2\text{ kg}$ | $1.8\text{ L}$ | $26.0\text{ W}$ | $100.0\text{ Mbps}$ (Earth observation imagery downlink) | $\$2.0\text{M}$ | T1 |
| **GD Small Deep Space Transponder (SDST)** | General Dynamics Deep Space Radio + $0.3\text{ m}$ Dish | $4.2\text{ kg}$ | $3.2\text{ L}$ | $42.0\text{ W}$ | $200.0\text{ kbps}$ at Lunar Distance (NASA DSN compatible) | $\$3.2\text{M}$ | T3 |
| **High-Gain Deep Space 1.0m Dish** | Gimballed Carbon-Composite Reflector | $11.5\text{ kg}$ | $5.2\text{ L}$ | $85.0\text{ W}$ | $2.5\text{ Mbps}$ at Moon; $50\text{ Mbps}$ at GEO | $\$8.0\text{M}$ | T3 |

---

### 4.4 In-Space Propulsion Subsystem

| Engine / Thruster | Manufacturer / Model | Mass | Thrust | Vacuum $I_{\text{sp}}$ | Unit Cost | Tech Tier | Primary Mission Application |
|---|---|---|---|---|---|---|---|
| **VACCO MiPS Cold Gas** | VACCO Micro-Propulsion System | $1.1\text{ kg}$ | $1.0\text{ N}$ | $68\text{ s}$ | $\$0.25\text{M}$ | T0 | Safe, non-toxic CubeSat detumble and orbit adjustment ($\sim 25\text{ m/s} \ \Delta v$). |
| **Aerojet MR-103G Hydrazine** | Aerojet Rocketdyne Monopropellant | $1.2\text{ kg}$ | $22.0\text{ N}$ | $227\text{ s}$ | $\$1.0\text{M}$ | T1 | Proven satellite reaction control and orbit maintenance. |
| **Aerojet R-4D-15 Bipropellant** | Aerojet 490 N High-Performance Apogee Engine | $15.0\text{ kg}$ | $490.0\text{ N}$ | $315\text{ s}$ | $\$5.0\text{M}$ | T2 | **Apollo & GEO Satellite Workhorse**. Performs the $1.5\text{ km/s}$ GTO $\to$ GEO apogee burn and Lunar Orbit Insertion (LOI). |
| **Safran PPS-1350 Hall Thruster** | Safran / Busek Electric Ion Engine | $6.5\text{ kg}$ | $0.09\text{ N}$ | $2,200\text{ s}$ | $\$6.0\text{M}$ | T3 | Ultra-high fuel efficiency. Requires continuous $350\text{ W}$ electrical power. |
| **LPSC 800N Throttleable Cluster** | ISRO LPSC Chandrayaan / Apollo DPS Heritage | $28.0\text{ kg}$ | $2,400\text{ N}$ (throttles $30\text{–}100\%$) | $312\text{ s}$ | $\$12.0\text{M}$ | T4 | **Essential for Lunar Soft Landing**. Deeply throttleable for terminal powered descent. |
| **Lunar Landing Gear System** | Hexagonal Crushable Shock Struts | $18.0\text{ kg}$ | Structural | N/A | $\$2.0\text{M}$ | T4 | Aluminum honeycomb shock-absorbing legs for payloads up to $500\text{ kg}$ dry mass. |

---

## 5. Scientific Instruments & Payloads

### 5.1 Earth Observation & Communications Payloads

| Instrument | Flight Reference | Mass | Volume | Power Draw | Unit Cost | Primary Scientific Application | Tech Tier |
|---|---|---|---|---|---|---|---|
| **GomSpace NanoCam C1U** | Spaceborne CMOS Color Imager | $0.8\text{ kg}$ | $0.7\text{ L}$ | $2.5\text{ W}$ | $\$0.5\text{M}$ | Basic Earth visual monitoring ($30\text{ m}$ GSD). Flew on CubeSats. | T0 |
| **Fluxgate Magnetometer (MAG)** | Space Science Triaxial Sensor | $0.9\text{ kg}$ | $0.5\text{ L}$ | $1.2\text{ W}$ | $\$0.5\text{M}$ | Earth geomagnetic storm and auroral current monitoring. | T0 |
| **NASA CRaTER Space Radiation Detector** | Cosmic Ray Telescope Sensor | $1.6\text{ kg}$ | $1.1\text{ L}$ | $2.2\text{ W}$ | $\$0.6\text{M}$ | Measures ionizing radiation dose and solar energetic protons. | T1 |
| **cosine HyperScout-2 / MultiScape** | Hyperspectral / Multispectral Imager | $11.0\text{ kg}$ | $13.0\text{ L}$ | $32.0\text{ W}$ | $\$6.0\text{M}$ | **Flood monitoring, agricultural health, mangrove delta analysis**. | T1 |
| **Landsat-8 TIRS (Thermal Infrared)** | Quantum Well Infrared Sensor | $19.0\text{ kg}$ | $22.0\text{ L}$ | $38.0\text{ W}$ | $\$7.0\text{M}$ | Cyclonic cloud monitoring, sea surface temperature, urban heat islands. | T2 |
| **WorldView-Class High-Res Camera** | Sub-Meter Ground Telescope | $24.0\text{ kg}$ | $28.0\text{ L}$ | $55.0\text{ W}$ | $\$8.0\text{M}$ | High-precision mapping and infrastructure monitoring ($1.0\text{ m}$ GSD). | T2 |
| **Ku/Ka-Band Transponder Suite** | High-Throughput Satellite Payload | $120.0\text{ kg}$ | $95.0\text{ L}$ | $1,200.0\text{ W}$ | $\$25.0\text{M}$ | **Commercial GEO Communications** (direct mirror of Bangabandhu Satellite-1). | T2 |
| **Sentinel-1 C-SAR Synthetic Radar** | Cloud-Penetrating Active Radar | $85.0\text{ kg}$ | $140.0\text{ L}$ | $750.0\text{ W}$ | $\$30.0\text{M}$ | Day/night imaging through monsoon storm clouds and flood disaster mapping. | T3 |

---

### 5.2 Lunar Exploration Payloads

| Instrument | Flight Reference / Mission | Mass | Volume | Power Draw | Unit Cost | Primary Scientific Application | Tech Tier |
|---|---|---|---|---|---|---|---|
| **LROC Wide Angle Camera (WAC)** | NASA Lunar Reconnaissance Orbiter | $4.5\text{ kg}$ | $3.8\text{ L}$ | $9.0\text{ W}$ | $\$2.0\text{M}$ | Global lunar multi-spectral mapping and flyby imaging. | T3 |
| **LOLA (Laser Altimeter)** | NASA Lunar Orbiter Laser Altimeter | $11.5\text{ kg}$ | $7.8\text{ L}$ | $28.0\text{ W}$ | $\$6.0\text{M}$ | Lunar topographic elevation and 3D surface slope characterization. | T3 |
| **LEND (Neutron Detector)** | NASA LRO Lunar Exploration Neutron Detector | $8.8\text{ kg}$ | $6.5\text{ L}$ | $11.0\text{ W}$ | $\$5.0\text{M}$ | **Search for hydrogen and polar water-ice cold traps**. | T3 |
| **Diviner Lunar Radiometer (DLRE)** | NASA LRO Thermal Radiometer | $9.5\text{ kg}$ | $8.5\text{ L}$ | $17.0\text{ W}$ | $\$6.0\text{M}$ | Maps extreme lunar thermal variations and surface silicate mineralogy. | T3 |
| **KaRA + LDV Landing Radar & Velocimeter** | Chandrayaan-3 Landing Sensor Suite | $7.8\text{ kg}$ | $5.8\text{ L}$ | $38.0\text{ W}$ | $\$6.0\text{M}$ | **Mandatory for Lunar Soft Landing**. Real-time altitude and horizontal velocity. | T4 |
| **LHDAC Hazard Avoidance Lidar** | Lander Hazard Detection & Avoidance Camera | $9.8\text{ kg}$ | $7.5\text{ L}$ | $34.0\text{ W}$ | $\$9.0\text{M}$ | Scans landing zone for boulders and steep slopes; automatically diverts lander. | T4 |
| **Apollo / ILSA Lunar Seismometer** | MEMS Lunar Surface Seismometer | $2.8\text{ kg}$ | $1.8\text{ L}$ | $3.5\text{ W}$ | $\$4.0\text{M}$ | Records moonquakes and micrometeorite surface impacts. | T4 |
| **ISRO ChaSTE Thermal Probe** | Chandra's Surface Thermophysical Experiment | $2.1\text{ kg}$ | $1.4\text{ L}$ | $4.5\text{ W}$ | $\$3.0\text{M}$ | Motorized thermal probe penetrating $10\text{ cm}$ into lunar regolith. | T4 |
| **Subsurface Core Drill** | Luna 24 / ESA PROSPECT Drill System | $11.5\text{ kg}$ | $9.5\text{ L}$ | $38.0\text{ W}$ | $\$7.0\text{M}$ | Drills up to $1.0\text{ m}$ depth to extract pristine cryogenic ice samples. | T4 |
| **NASA Laser Retroreflector Array (LRA)** | NASA Goddard Passive Target Array | $0.4\text{ kg}$ | $0.2\text{ L}$ | $0.0\text{ W}$ | $\$0.3\text{M}$ | Passive corner-cube retroreflector for millimeter-precision laser ranging. | T4 |
| **Pragyan-Class 6-Wheel Micro-Rover** | 26–45 kg Rocker-Bogie Lunar Rover | $42.0\text{ kg}$ | $0.8 \times 0.6 \times 0.4\text{ m}$ | $75.0\text{ W}$ | $\$15.0\text{M}$ | Surface mobility, obstacle traversal, and deployment of APXS spectrometers. | T4 |

---

## 6. Mission Ladder & Educational Progression

The 8-mission campaign takes students on an inspiring journey from university nanosatellite engineering to national geostationary telecommunications and challenging lunar exploration.

```
M1 (BRAC Onnesha) ➔ M2 (Orbital Sentinel) ➔ M3 (Delta Flood Watch) ➔ M4 (Bangabandhu Satellite-1) ➔ M5 (Pathfinder Flyby) ➔ M6 (Lunar Reconnaissance) ➔ M7 (Lunar Touchdown) ➔ M8 (South Pole Endurance & Rover)
```

| # | Mission Title | Real-World Context & Inspiration | Primary Mission Requirements | Designated Launcher | Mission Reward | Unlocks |
|---|---|---|---|---|---|---|
| **1** | **First Signal: BRAC Onnesha** | **Bangladesh's First Satellite (2017)**. Built by university students, proving basic LEO orbit operations. | 1U/3U CubeSat, GomSpace OBC, EnduroSat UHF beacon, body solar panels; survive LEO eclipse for $7\text{ days}$. | Electron | $\$16\text{M}$, $15\text{ SP}$ | T1 Tech Branch, S-Band Radio |
| **2** | **Orbital Sentinel** | Early Earth observation satellite (Landsat/Dove precursor). | 12U CubeSat, GomSpace NanoCam C1U, Syrlinks S-Band, 3-axis RW-0.03 wheels, operate $30\text{ days}$. | Electron | $\$28\text{M}$, $30\text{ SP}$ | Microsat Bus, X-Band Transmitter |
| **3** | **Delta Flood Watch** | **Disaster & Environmental Monitoring**. Real-time flood, agricultural, and cyclone mapping over South Asia. | SSTL-50 Microsat, HyperScout-2 multispectral imager in Sun-Synchronous Orbit (SSO); downlink flood maps. | Electron / Vega-C | $\$52\text{M}$, $70\text{ SP}$ | Vega-C Launcher, Midsat Bus, T2 Tech |
| **4** | **Geostationary Gateway: Bangabandhu Satellite-1** | **Bangladesh's First Commercial GEO Satellite (2018)**. Historic maiden commercial flight of Falcon 9 Block 5. | Heavy Bus, $1.2\text{ kW}$ Ku/Ka transponder payload, R-4D-15 engine for $1.5\text{ km/s}$ GTO $\to$ GEO circularization; operate $1\text{ year}$. | Falcon 9 | $\$175\text{M}$, $110\text{ SP}$ | Deep Space Comms, BAE RAD750, T3 Tech |
| **5** | **Cislunar Pathfinder** | High-energy lunar flyby mission (inspired by NASA CAPSTONE and Pioneer 4). | 12U CubeSat or Microsat, deep-space transponder, LROC camera; achieve trans-lunar trajectory with mid-course burn. | Vega-C / Falcon 9 | $\$105\text{M}$, $80\text{ SP}$ | Deep Space 1.0m Dish, LOLA Altimeter |
| **6** | **Lunar Polar Prospector** | Polar mapping orbiter (inspired by NASA LRO and Chandrayaan-1). | Midsat Bus, R-4D engine for $0.9\text{ km/s}$ LOI burn into $100\text{ km}$ polar orbit, LOLA laser altimeter + LEND water-ice detector. | Falcon 9 | $\$155\text{M}$, $130\text{ SP}$ | Throttleable Descent Engine, Landing Radar, T4 Tech |
| **7** | **Lunar Touchdown** | Precision soft landing at lunar south pole (inspired by Surveyor, Vikram, and SLIM). | Lunar Lander Bus, throttleable descent engine, KaRA landing radar altimeter, ChaSTE thermal probe; execute soft touchdown. | Falcon 9 | $\$210\text{M}$, $180\text{ SP}$ | Pragyan Rover, RHU Night Kit, Core Drill |
| **8** | **South Pole Endurance & Rover** | Long-duration lunar surface exploration (Apollo 15 / VIPER / Chandrayaan-3). | Deploy 6-wheel rover, conduct subsurface core drilling, survive extreme $-150^\circ\text{C}$ 14-day lunar night with RHU/batteries. | Falcon 9 | $\$420\text{M}$, $250\text{ SP}$ | Sandbox Mode, Master Mission Badge |

---

## 7. The Core Game Loop (NASA Project Lifecycle)

The game loop explicitly mirrors NASA’s Space Flight Project Life Cycle (**NASA NPR 7120.5**):

```
PHASE A: OBJECTIVE  ➔  PHASE B: RESEARCH  ➔  PHASE C: DESIGN & REVIEW  ➔  PHASE D: TEST & LAUNCH  ➔  PHASE E: OPERATE & POST-MISSION
```

```mermaid
sequenceDiagram
    autonumber
    actor Player as Mission Director (Player)
    participant Board as Mission Contract Board (Phase A)
    participant Tech as Research Tree (Phase B)
    participant CAD as Spacecraft Builder (Phase C)
    participant Rev as Flight Readiness Review
    participant Pad as Launch Pad (Phase D)
    participant Ops as Mission Operations (Phase E)
    participant Debrief as NASA Post-Flight Review

    Board->>Player: Issue Contract (e.g. Bangabandhu Satellite-1: GTO->GEO, 1.2kW, Budget $180M)
    Player->>Tech: Spend Science Points (SP) to unlock R-4D engine & RAD750 computer
    Player->>CAD: Assemble Launcher + Bus + Transponders + Bipropellant Tanks
    CAD->>Rev: Submit CAD design for automated telemetry review
    alt Margin Violation
        Rev-->>Player: RED FLAG: Bipropellant tank lacks 150 m/s margin for GEO circularization!
    else Flight Ready
        Rev-->>Player: GREEN: Design meets mass, power, thermal, and delta-v constraints
    end
    Player->>Pad: Initiate launch sequence (Roll against Falcon 9 reliability: 97%)
    Pad->>Ops: Staging nominal; deploy spacecraft in GTO
    Ops->>Player: In-Flight Timeline & Anomaly Event (e.g. Solar flare warning)
    Player->>Ops: Executive decision: Point arrays away, put transponder in safe mode
    Ops->>Debrief: Primary objectives completed + thermal margins verified
    Debrief-->>Player: Award Science Points ($110 SP$) + Budget ($175M$) + Lessons Learned
```

### The 7 Gameplay Steps:
1. **Mission Contract (Phase A - Concept Studies):** Player selects a contract outlining payload requirements, target orbit, mission lifetime, and budget cap.
2. **Research & Development (Phase B - Formulation):** Player allocates Science Points (SP) to unlock engines, solar panels, instruments, and launcher reliability upgrades.
3. **Spacecraft Builder (Phase C - Design):** Interactive builder showing real-time telemetry bars:
   * **Total Wet Mass vs. Launcher Limit**
   * **Internal Volume vs. Bus Enclosure**
   * **Power Generation vs. Load (Sunlit vs. Eclipse)**
   * **$\Delta v$ Budget Remaining vs. Maneuver Requirements**
   * **Downlink Bandwidth vs. Ground Station Pass Duration**
4. **Flight Readiness Review (The Teaching Checklist):** The game analyzes the design and provides actionable engineering feedback:
   * ❌ *"Insufficient battery storage: During 35-minute LEO eclipse, GomSpace OBC will lose bus power. Add GomSpace BP4 module."*
   * ❌ *"Thermal failure: Spacecraft has no radiation-hardened computer (RAD750). Cosmic rays will corrupt avionics in Van Allen Belts."*
5. **Testing & Environmental Qualification (Phase D):** Optional vibration and thermal-vacuum (TVAC) chamber testing can be purchased with game money to suppress in-flight component failure risks.
6. **Launch & Ascent:** Staging and orbital insertion sequence rolled against launcher reliability.
7. **Mission Operations & Incident Management (Phase E):** The mission timeline unfolds with real orbital maneuvers and telemetry alerts. Unexpected anomalies (solar particle events, sensor blinding, cloud cover) force the player to make real-time engineering trade-offs. Post-mission review awards Science Points ($SP$) and funds even on partial failures.