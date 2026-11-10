# Space Mission Game: Aerospace Datasets Reference & Data Schemas

This reference handbook catalogs the official **NASA, ESA, and open aerospace datasets** used to ground the space mission game in flight-proven reality. It also provides ready-to-import **JSON data schemas** for game developers to load directly into their game engine (Unity, Godot, Unreal, or Web/React).

---

## 1. Primary Aerospace Datasets & Official Sources

| Dataset / Repository | Organization | Description & Direct Links | Primary Data Utilized in Game |
|---|---|---|---|
| **NASA S3VI SPOON & SSBoK** | NASA Ames Research Center / STMD | **SmallSat Parts On Orbit Now (SPOON)** database and the **Small Spacecraft Technology State of the Art Report**.<br>• Portal: [nasa.gov/smallsat-institute](https://www.nasa.gov/smallsat-institute/)<br>• Technical Report: [NASA NTRS Report 20240003140](https://ntrs.nasa.gov/) | CubeSat & SmallSat hardware: batteries, solar arrays, reaction wheels, star trackers, UHF/S/X-band transceivers, micro-propulsion systems. |
| **NASA NSSDCA Master Catalog** | NASA Goddard Space Flight Center | **National Space Science Data Center Archive (NSSDCA)**. Contains comprehensive descriptions, orbits, masses, and instrument payloads for all NASA and international spacecraft since 1957.<br>• Portal: [nssdc.gsfc.nasa.gov/nmc](https://nssdc.gsfc.nasa.gov/nmc/) | Planetary and lunar mission parameters: Lunar Reconnaissance Orbiter (LRO), Apollo Lunar Module & instruments (PSEP, LRRR), Surveyor 1–7, Clementine, Lunar Prospector. |
| **ESA eoPortal Directory** | European Space Agency (ESA) | Global directory of Earth observation satellite platforms, multispectral sensors, synthetic aperture radars (SAR), and thermal imagers.<br>• Portal: [eoportal.org](https://www.eoportal.org/) | Commercial and agency Earth observation hardware: Sentinel-1 C-SAR, Sentinel-2 MSI, Landsat-8 TIRS, cosine HyperScout, Simera Sense imagers, SSTL-50 bus. |
| **satsearch / satcatalog** | Global Space Marketplace | Global commercial space engineering platform cataloging commercial off-the-shelf (COTS) space hardware with verified flight heritage and TRL ratings.<br>• Portal: [satsearch.co](https://satsearch.co/) | COTS component dry masses, volumes, power consumption, standard pricing models, and flight history across global vendors (GomSpace, EnduroSat, BCT, AAC Clyde). |
| **NASA Lessons Learned (LLIS)** | NASA Office of the Chief Engineer | Public database of official aerospace engineering failure reports, mishap investigation board findings, and design margin guidelines.<br>• Portal: [llis.nasa.gov](https://www.nasa.gov/offices/oce/llis/) | In-flight random events: Apollo 11 fuel margins, Lucy solar array latch anomaly, Kepler reaction wheel issues, CAPSTONE recovery, space radiation latch-up. |
| **Jonathan's Space Report & GCAT** | Jonathan McDowell (Harvard-Smithsonian CfA) | **General Catalog of Artificial Space Objects (GCAT)**: Complete launch registry, dry and wet masses, orbital parameters, and stage data.<br>• Portal: [planet4589.org/space/gcat](https://planet4589.org/space/gcat/) | Accurate launch vehicle capabilities, dry and wet mass fractions, and real satellite orbital lifespans (BRAC Onnesha, Bangabandhu-1). |

---

## 2. Engineering Data Dictionary & Unit Standards

| Variable | Symbol | Game Engineering Unit | Real-World Physics Unit | Conversion / Notes |
|---|---|---|---|---|
| **Dry Mass** | $m_{\text{dry}}$ | Kilograms ($\text{kg}$) | $\text{kg}$ | Total mass of structure, avionics, payloads, and empty tanks. |
| **Wet Mass** | $m_{\text{wet}}$ | Kilograms ($\text{kg}$) | $\text{kg}$ | $m_{\text{dry}} + m_{\text{propellant}} + m_{\text{adapter}}$. |
| **Delta-V** | $\Delta v$ | Kilometers per second ($\text{km/s}$) | $\text{m/s}$ | $1.0\text{ km/s} = 1,000\text{ m/s}$. |
| **Specific Impulse** | $I_{\text{sp}}$ | Seconds ($\text{s}$) | $\text{s}$ | Exhaust velocity $v_e = I_{\text{sp}} \cdot g_0$ ($g_0 = 9.80665\text{ m/s}^2$). |
| **Electrical Power** | $P$ | Watts ($\text{W}$) | $\text{W}$ | Generation is **negative** (e.g. $-320\text{ W}$); consumption is **positive**. |
| **Battery Storage** | $E_{\text{batt}}$ | Watt-hours ($\text{Wh}$) / $\text{kWh}$ | $\text{Joules}$ | $1.0\text{ Wh} = 3,600\text{ Joules}$; $1.0\text{ kWh} = 1,000\text{ Wh}$. |
| **Internal Volume** | $V$ | Liters ($\text{L}$) | $\text{m}^3$ | $1\text{U CubeSat} = 10 \times 10 \times 10\text{ cm} = 1.0\text{ Liter} = 10^{-3}\text{ m}^3$. |
| **Data Downlink Rate**| $R_{\text{data}}$ | $\text{kbps}$ / $\text{Mbps}$ | $\text{bits/s}$ | $1.0\text{ Mbps} = 1,000\text{ kbps} = 10^6\text{ bits/s}$. |
| **Financial Cost** | $C$ | Millions of USD ($\$\text{M}$) | $\text{USD}$ | Game budget unit ($\$1.0\text{M} = \$1,000,000$). |

---

## 3. Developer JSON Data Schemas

These structured schemas can be saved into JSON data files (`launchers.json`, `buses.json`, `components.json`, `missions.json`) for straightforward loading into your game engine.

### 3.1 Launch Vehicles Schema (`launchers.json`)

```json
[
  {
    "id": "launcher_electron",
    "name": "Rocket Lab Electron",
    "manufacturer": "Rocket Lab",
    "tier": 0,
    "costMillions": 8.5,
    "baseReliability": 0.88,
    "fairingDiameterMeters": 1.2,
    "fairingHeightMeters": 2.5,
    "capacityLeoKg": 300,
    "capacityGtoKg": 0,
    "capacityTliKg": 0,
    "heritage": "First flight 2017; Rutherford electric-pump engines; launched NASA CAPSTONE to the Moon."
  },
  {
    "id": "launcher_vega_c",
    "name": "ESA Vega-C / ISRO PSLV",
    "manufacturer": "Avio / Arianespace / ISRO",
    "tier": 1,
    "costMillions": 45.0,
    "baseReliability": 0.93,
    "fairingDiameterMeters": 3.3,
    "fairingHeightMeters": 9.0,
    "capacityLeoKg": 2300,
    "capacityGtoKg": 1000,
    "capacityTliKg": 500,
    "heritage": "Solid propulsion stages + AVUM+ precision liquid restart upper stage; launched Chandrayaan-1."
  },
  {
    "id": "launcher_falcon_9",
    "name": "SpaceX Falcon 9",
    "manufacturer": "SpaceX",
    "tier": 3,
    "costMillions": 70.0,
    "baseReliability": 0.97,
    "fairingDiameterMeters": 5.2,
    "fairingHeightMeters": 13.1,
    "capacityLeoKg": 17500,
    "capacityGtoKg": 5500,
    "capacityTliKg": 3800,
    "heritage": "Workhorse orbital rocket; launched Bangabandhu Satellite-1 (first flight of Block 5) and lunar landers."
  }
]
```

---

### 3.2 Spacecraft Bus Platforms (`buses.json`)

```json
[
  {
    "id": "bus_cubesat_1u_3u",
    "name": "1U/3U CubeSat Platform",
    "manufacturer": "Kyutech BIRDS / GomSpace",
    "tier": 0,
    "dryMassKg": 1.5,
    "dimensionsMeters": [0.10, 0.10, 0.34],
    "internalVolumeLiters": 3.0,
    "costMillions": 0.3,
    "heritage": "BRAC Onnesha (Bangladesh, 2017), GomSpace GOMX, standard CubeSat standard."
  },
  {
    "id": "bus_cubesat_12u",
    "name": "12U Deep-Space CubeSat",
    "manufacturer": "NanoAvionics / Blue Canyon",
    "tier": 0,
    "dryMassKg": 16.0,
    "dimensionsMeters": [0.23, 0.23, 0.34],
    "internalVolumeLiters": 12.0,
    "costMillions": 1.0,
    "heritage": "NASA CAPSTONE cislunar probe, NanoAvionics M12P platform."
  },
  {
    "id": "bus_microsat_50",
    "name": "SSTL-50 / BCT-100 Microsat",
    "manufacturer": "Surrey Satellite / Blue Canyon",
    "tier": 1,
    "dryMassKg": 60.0,
    "dimensionsMeters": [0.60, 0.60, 0.60],
    "internalVolumeLiters": 150.0,
    "costMillions": 3.5,
    "heritage": "Disaster monitoring constellations, Surrey SSTL Earth observation series."
  },
  {
    "id": "bus_midsat_500",
    "name": "Blue Canyon BCT-500 Midsat",
    "manufacturer": "Blue Canyon Technologies / GA",
    "tier": 2,
    "dryMassKg": 180.0,
    "dimensionsMeters": [1.00, 1.00, 1.00],
    "internalVolumeLiters": 600.0,
    "costMillions": 10.0,
    "heritage": "NASA Lunar Reconnaissance Orbiter (LRO) class, ESPA-Star bus architecture."
  },
  {
    "id": "bus_heavy_geo_lunar",
    "name": "Spacebus / Lunar Lander Bus",
    "manufacturer": "Thales Alenia / Astrobotic / ISRO",
    "tier": 2,
    "dryMassKg": 350.0,
    "dimensionsMeters": [1.80, 1.80, 1.60],
    "internalVolumeLiters": 2500.0,
    "costMillions": 25.0,
    "heritage": "Bangabandhu Satellite-1 (Spacebus 4000B2), Chandrayaan-3 Vikram lander structure."
  }
]
```

---

### 3.3 Master Components & Subsystems (`components.json`)

```json
[
  {
    "id": "pwr_gomspace_p31u",
    "name": "GomSpace NanoPower P31u",
    "subsystem": "power",
    "tier": 0,
    "massKg": 0.3,
    "volumeLiters": 0.0,
    "isExternal": true,
    "powerGenWatts": 7.0,
    "powerDrawWatts": 0.0,
    "costMillions": 0.05,
    "heritage": "Body-mounted triple-junction GaAs cells. Flew on BRAC Onnesha."
  },
  {
    "id": "pwr_spectrolab_wing_m",
    "name": "Spectrolab XTJ Deployable Array (M)",
    "subsystem": "power",
    "tier": 1,
    "massKg": 6.0,
    "volumeLiters": 1.2,
    "isExternal": false,
    "powerGenWatts": 320.0,
    "powerDrawWatts": 0.0,
    "costMillions": 1.5,
    "heritage": "1.0 m² rigid deployable wing; used on medium Earth observation satellites."
  },
  {
    "id": "pwr_nasa_rhu_night_kit",
    "name": "NASA RHU + MLI Lunar Night Kit",
    "subsystem": "power_thermal",
    "tier": 4,
    "massKg": 4.0,
    "volumeLiters": 3.5,
    "isExternal": false,
    "powerGenWatts": 0.0,
    "powerDrawWatts": 0.0,
    "thermalHeatWatts": 10.0,
    "costMillions": 3.0,
    "heritage": "Plutonium-238 radioisotope decay heat; enables 14-day lunar night survival."
  },
  {
    "id": "av_bae_rad750",
    "name": "BAE Systems RAD750 OBC",
    "subsystem": "avionics",
    "tier": 2,
    "massKg": 2.5,
    "volumeLiters": 1.2,
    "isExternal": false,
    "powerGenWatts": 0.0,
    "powerDrawWatts": 10.0,
    "costMillions": 3.2,
    "heritage": "Radiation-hardened space computer. Flew on LRO, Kepler, Mars Curiosity, Deep Impact."
  },
  {
    "id": "prop_aerojet_r4d15",
    "name": "Aerojet Rocketdyne R-4D-15 Engine",
    "subsystem": "propulsion",
    "tier": 2,
    "massKg": 15.0,
    "volumeLiters": 20.0,
    "isExternal": false,
    "thrustNewtons": 490.0,
    "ispSeconds": 315.0,
    "costMillions": 5.0,
    "propellantType": "bipropellant",
    "heritage": "Apollo CSM, Cassini, Bangabandhu Satellite-1 apogee motor; GTO to GEO burn."
  },
  {
    "id": "inst_cosine_hyperscout2",
    "name": "cosine HyperScout-2 Imager",
    "subsystem": "instrument",
    "tier": 1,
    "massKg": 11.0,
    "volumeLiters": 13.0,
    "isExternal": false,
    "powerGenWatts": 0.0,
    "powerDrawWatts": 32.0,
    "costMillions": 6.0,
    "heritage": "Multispectral/hyperspectral Earth imager for flood and agricultural monitoring."
  },
  {
    "id": "inst_lro_lola",
    "name": "LOLA Lunar Laser Altimeter",
    "subsystem": "instrument",
    "tier": 3,
    "massKg": 11.5,
    "volumeLiters": 7.8,
    "isExternal": false,
    "powerGenWatts": 0.0,
    "powerDrawWatts": 28.0,
    "costMillions": 6.0,
    "heritage": "NASA LRO payload; 5-beam pulsed laser measuring global lunar elevation and slopes."
  },
  {
    "id": "inst_lro_lend",
    "name": "LEND Lunar Neutron Detector",
    "subsystem": "instrument",
    "tier": 3,
    "massKg": 8.8,
    "volumeLiters": 6.5,
    "isExternal": false,
    "powerGenWatts": 0.0,
    "powerDrawWatts": 11.0,
    "costMillions": 5.0,
    "heritage": "NASA LRO payload; maps epithermal neutrons to locate water ice in polar cold traps."
  },
  {
    "id": "inst_kara_landing_radar",
    "name": "KaRA + LDV Landing Radar & Velocimeter",
    "subsystem": "landing",
    "tier": 4,
    "massKg": 7.8,
    "volumeLiters": 5.8,
    "isExternal": false,
    "powerGenWatts": 0.0,
    "powerDrawWatts": 38.0,
    "costMillions": 6.0,
    "heritage": "Chandrayaan-3 Vikram terminal landing sensors; mandatory for soft touchdown."
  }
]
```

---

### 3.4 Master Mission Ladder (`missions.json`)

```json
[
  {
    "missionNumber": 1,
    "title": "First Signal: BRAC Onnesha",
    "realWorldHeritage": "Bangladesh's First Satellite (1U CubeSat, 2017)",
    "targetOrbit": "LEO",
    "targetAltitudeKm": 400,
    "requiredLauncher": "launcher_electron",
    "requiredBus": "bus_cubesat_1u_3u",
    "primaryRequirements": [
      "EnduroSat UHF Transceiver II onboard",
      "GomSpace P31u body solar panels installed",
      "Survive 35-minute eclipse on battery power",
      "Maintain active beacon downlink for 7 days"
    ],
    "rewardFundsMillions": 16.0,
    "rewardSciencePoints": 15,
    "unlocksTier": 1
  },
  {
    "missionNumber": 2,
    "title": "Orbital Sentinel",
    "realWorldHeritage": "3-Axis Earth Observation CubeSat (Dove Precursor)",
    "targetOrbit": "LEO",
    "targetAltitudeKm": 500,
    "requiredLauncher": "launcher_electron",
    "requiredBus": "bus_cubesat_12u",
    "primaryRequirements": [
      "GomSpace NanoCam C1U installed",
      "Syrlinks EWC27 S-Band Transceiver installed",
      "Rocket Lab RW-0.03 3-axis reaction wheels active",
      "Operate Earth imaging for 30 days"
    ],
    "rewardFundsMillions": 28.0,
    "rewardSciencePoints": 30,
    "unlocksTier": 1
  },
  {
    "missionNumber": 3,
    "title": "Delta Flood Watch",
    "realWorldHeritage": "Regional Disaster & Environmental Monitoring (South Asia)",
    "targetOrbit": "SSO",
    "targetAltitudeKm": 650,
    "requiredLauncher": "launcher_electron",
    "requiredBus": "bus_microsat_50",
    "primaryRequirements": [
      "cosine HyperScout-2 multispectral imager installed",
      "Syrlinks EWC30 X-Band 100 Mbps transmitter installed",
      "Downlink flood inundation maps over target delta"
    ],
    "rewardFundsMillions": 52.0,
    "rewardSciencePoints": 70,
    "unlocksTier": 2
  },
  {
    "missionNumber": 4,
    "title": "Geostationary Gateway: Bangabandhu Satellite-1",
    "realWorldHeritage": "Bangladesh's First Commercial GEO Satellite (SpaceX Falcon 9, 2018)",
    "targetOrbit": "GEO",
    "targetAltitudeKm": 35786,
    "requiredLauncher": "launcher_falcon_9",
    "requiredBus": "bus_heavy_geo_lunar",
    "primaryRequirements": [
      "Ku/Ka-band commercial transponder suite installed",
      "Aerojet R-4D-15 apogee engine installed",
      "Propellant sized for 1,500 m/s GTO to GEO circularization",
      "BAE Systems RAD750 rad-hard computer active",
      "Operate 24/7 telecommunications for 1 year"
    ],
    "rewardFundsMillions": 175.0,
    "rewardSciencePoints": 110,
    "unlocksTier": 3
  },
  {
    "missionNumber": 5,
    "title": "Cislunar Pathfinder",
    "realWorldHeritage": "Trans-Lunar Trajectory Flyby (CAPSTONE / Pioneer 4)",
    "targetOrbit": "Lunar Flyby",
    "targetAltitudeKm": 384400,
    "requiredLauncher": "launcher_vega_c",
    "requiredBus": "bus_cubesat_12u",
    "primaryRequirements": [
      "Trans-Lunar Injection (TLI) delta-v budget met",
      "General Dynamics SDST deep space transponder active",
      "LROC Wide Angle Camera flyby images captured"
    ],
    "rewardFundsMillions": 105.0,
    "rewardSciencePoints": 80,
    "unlocksTier": 3
  },
  {
    "missionNumber": 6,
    "title": "Lunar Polar Prospector",
    "realWorldHeritage": "NASA Lunar Reconnaissance Orbiter (LRO) / Chandrayaan-1",
    "targetOrbit": "Low Lunar Polar Orbit",
    "targetAltitudeKm": 100,
    "requiredLauncher": "launcher_falcon_9",
    "requiredBus": "bus_midsat_500",
    "primaryRequirements": [
      "Lunar Orbit Insertion (LOI) burn executed (900 m/s)",
      "LOLA laser altimeter mapping topographic elevation",
      "NASA LEND neutron spectrometer mapping polar water ice"
    ],
    "rewardFundsMillions": 155.0,
    "rewardSciencePoints": 130,
    "unlocksTier": 4
  },
  {
    "missionNumber": 7,
    "title": "Lunar Touchdown",
    "realWorldHeritage": "Targeted Soft Landing at South Pole (Surveyor / Vikram / SLIM)",
    "targetOrbit": "Lunar Surface",
    "targetAltitudeKm": 0,
    "requiredLauncher": "launcher_falcon_9",
    "requiredBus": "bus_heavy_geo_lunar",
    "primaryRequirements": [
      "LPSC 800N throttleable descent cluster installed",
      "KaRA landing radar and LDV velocimeter installed",
      "Hexagonal landing gear installed",
      "Survive powered descent and touchdown within 2 m/s",
      "Deploy ISRO ChaSTE regolith thermal penetration probe"
    ],
    "rewardFundsMillions": 210.0,
    "rewardSciencePoints": 180,
    "unlocksTier": 4
  },
  {
    "missionNumber": 8,
    "title": "South Pole Endurance & Rover",
    "realWorldHeritage": "Long-Duration Surface Science & Regolith Core Drilling (Apollo 15 / Pragyan)",
    "targetOrbit": "Lunar Surface",
    "targetAltitudeKm": 0,
    "requiredLauncher": "launcher_falcon_9",
    "requiredBus": "bus_heavy_geo_lunar",
    "primaryRequirements": [
      "Deploy Pragyan-Class 6-wheel micro-rover on surface",
      "Conduct 1-meter subsurface regolith core drilling",
      "NASA RHU night kit + EaglePicher battery installed",
      "Survive complete 14.75-day cryogenic lunar night (-180°C)"
    ],
    "rewardFundsMillions": 420.0,
    "rewardSciencePoints": 250,
    "unlocksTier": 4
  }
]
```