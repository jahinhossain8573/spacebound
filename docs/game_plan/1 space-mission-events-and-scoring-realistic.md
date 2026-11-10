# Space Mission Game: Realistic In-Flight Events & Scoring (NASA Lessons Learned)

This file pairs with `space-mission-game-design-realistic.md` and `space-mission-tech-tree-realistic.md`. It governs the **Operations Phase** (random in-flight anomalies grounded in historical spaceflight incidents) and the **Results Phase** (scoring, payouts, and NASA Lessons Learned debriefs).

---

## Part A: In-Flight Events & NASA Lessons Learned

### A1. Aerospace Engineering Design Rules

Every event in the game follows four core systems engineering principles:
1. **Telemetry Warning:** The player receives advance telemetry or countdown alerts whenever physically possible.
2. **Operational Decision:** The player must make an executive trade-off (e.g., expend reserve $\Delta v$, shed non-critical payload load, accept operational risk).
3. **Preventative Design Margin:** There is always an engineering margin (mass, power, battery capacity, thermal insulation, sensor redundancy) that softens or completely neutralizes the event.
4. **NASA Lessons Learned Citation:** The post-mission flight debrief connects the incident directly to historical mission precedents from the **NASA Lessons Learned Information System (LLIS)**.

Events are **never arbitrary punishments**; they are real tests of the engineering trade-offs made during the design phase.

---

### A2. Event Occurrence by Mission Complexity

| Mission Tier | Applicable Missions | Events Rolled | Permitted Severity Levels |
|---|---|---|---|
| **Early LEO (Tutorial)** | 1 (BRAC Onnesha) – 2 (Orbital Sentinel) | 1 | Minor only |
| **Operational LEO / SSO** | 3 (Delta Flood Watch) | 2 | Minor + Major |
| **High-Energy GEO** | 4 (Bangabandhu Satellite-1) | 2 | Minor + Major |
| **Cislunar & Lunar Orbit** | 5 (Pathfinder) – 6 (Lunar Prospector) | 2–3 | Minor + Major |
| **Lunar Landing & Surface** | 7 (Touchdown) – 8 (Endurance & Rover) | 3 | Minor + Major + Critical |

---

### A3. Influence of Testing Campaigns (NASA Environmental Qualification)

| Environmental Test Research | Operational Effect on In-Flight Reliability | Real-World NASA Engineering Analogy |
|---|---|---|
| **Test Campaign I (L5)** | Subsystem failure events (E2, E3, E5, E6, E11, E14) are **$30\%$ less likely**. | Component thermal cycling and bake-out testing. |
| **Test Campaign II (L6)** | Subsystem failure events are **$50\%$ less likely**; adds **$+5\%$ to lunar landing success probability**. | Full-spacecraft acoustic, shaker table, and Thermal-Vacuum (TVAC) chamber qualification. |

---

### A4. Master In-Flight Event Catalog

#### 1. Launch & Early Orbit Phase (LEOP)

| ID | Event Title | Severity | Probability | Operational Impact | Player Decision / Mitigation | Historical Precedent & NASA Lesson |
|---|---|---|---|---|---|---|
| **E1** | **Ascent Staging Anomaly** | Critical | $1 - \text{Launcher Reliability}$ | Launch vehicle failure; mission lost in upper atmosphere. | Invest in launcher reliability research nodes (L7–L9) and flight-proven rockets. | **NASA LLIS 0743:** Multiple engine redundancy (Falcon 9) vs single-point upper stage failures. |
| **E2** | **Acoustic / Vibration Shock** | Major | $8\%$ | Launch vibrations damage optics; camera/imager data quality drops by $50\%$. | Pre-launch TVAC testing (L6); mount sensitive instruments on higher-mass bus platform. | **James Webb / Hubble Heritage:** Rigorous acoustic vibration testing isolates delicate optical benches. |
| **E3** | **Solar Array Latch Jam** | Major | $6\%$ | Deployable solar wing fails to fully lock; array generation reduced by $50\%$. | Design with $+25\%$ power margin, or utilize body-mounted panels (BRAC Onnesha style). | **NASA Lucy Mission (2021):** Circular solar array failed to fully latch; survived on redundant power margins. |
| **E4** | **Post-Separation Tip-Off Tumble** | Minor | $10\%$ | Spacecraft tumbles upon dispenser separation; science delayed $3\text{ days}$. | Detumble slowly using magnetorquers (free in LEO) or fast using cold gas thrusters (costs $10\text{ m/s} \ \Delta v$). | **NASA CAPSTONE (2022):** Experienced post-separation attitude tumble on way to Moon; detumbled via onboard thrusters. |

---

#### 2. LEO & GEO Operations Phase

| ID | Event Title | Severity | Probability | Operational Impact | Player Decision / Mitigation | Historical Precedent & NASA Lesson |
|---|---|---|---|---|---|---|
| **E5** | **Primary Downlink Transmitter Failure** | Major | $5\%$ | Main high-rate X-Band transmitter fails; cannot downlink science packets. | Secondary low-data-rate UHF/S-Band transceiver maintains emergency $9.6\text{ kbps}$ telemetry link. | **STEREO & Pioneer Missions:** Redundant low-gain antennas and secondary beacons are essential for spacecraft survival. |
| **E6** | **Battery Depth-of-Discharge Degradation** | Minor | $5\%$ | Thermal stress permanently degrades battery capacity by $-20\%$. | Design with $>20\%$ battery storage margin for eclipse periods. | **Hubble Space Telescope:** Prudent depth-of-discharge management prolongs space battery operational lifespan. |
| **E7** | **Solar Energetic Particle Event / CME** | Major | $12\%$ ($20\%$ in GEO/Moon) | Severe coronal mass ejection; computer reboots. Non-rad-hard computer has $40\%$ chance of permanent burnout. | **BAE Systems RAD750 OBC** is completely immune; radiation detector gives advance warning to safe payloads. | **Galaxy 15 / SOHO Heritage:** Non-radiation-hardened commercial components suffer latch-up in deep space radiation belts. |
| **E8** | **Orbital Debris Conjunction Warning** | Major | $8\%$ in LEO | High-velocity orbital debris track predicted within $500\text{ m}$; $5\%$ collision chance if ignored. | Execute Collision Avoidance Maneuver (CAM) burning $0.01\text{ km/s} \ \Delta v$, or risk pass. | **ISS & Sentinel Fleet:** Regular propulsive debris collision avoidance burns protect operational satellites. |
| **E9** | **Monsoon Cloud Cover Blockade** | Minor | $20\%$ (100% in Mission 3) | Heavy tropical monsoon clouds completely block optical and multispectral imaging for $7\text{ days}$. | Wait for clear atmospheric window, or deploy all-weather **Sentinel-1 C-Band SAR Active Radar**. | **Copernicus Emergency Management:** Optical satellites blinded by typhoon clouds; Synthetic Aperture Radar provides all-weather flood maps. |
| **E10** | **Ground Station Uplink Outage** | Minor | $10\%$ | Local ground station pass dropped due to severe weather; downlink pass missed. | High-bandwidth transmitter with $+30\%$ throughput catches up on next pass; onboard storage buffer. | **NASA DSN Scheduling:** Onboard solid-state data recorders prevent data loss during ground station network downtime. |

---

#### 3. Cislunar Trajectory & Deep Space Maneuver Phase

| ID | Event Title | Severity | Probability | Operational Impact | Player Decision / Mitigation | Historical Precedent & NASA Lesson |
|---|---|---|---|---|---|---|
| **E11** | **Apogee Engine Isp Underperformance** | Major | $8\%$ per burn | Bipropellant engine delivers $10\%$ less $\Delta v$ due to mixture temperature offset. | Carry $+10\%$ propellant reserves; split burn into multiple passes (apogee pumping). | **Apollo 11 & Chandrayaan:** Propellant reserve margins are life-or-death requirements for lunar trajectory insertion. |
| **E12** | **Cislunar Trajectory Navigation Drift** | Minor | $25\%$ on lunar cruise | Gravitational perturbations push craft off course; requires extra $0.05\text{–}0.12\text{ km/s} \ \Delta v$ to correct. | Carry mid-course $\Delta v$ margin; **Rocket Lab ST-16 Star Tracker** reduces correction magnitude. | **NASA Lunar Prospector:** Autonomous optical navigation and star tracking minimize trajectory correction delta-v. |
| **E13** | **Optical Star Tracker Sun Blinding** | Minor | $6\%$ | Bright glint blinds star tracker; spacecraft enters safe mode for $48\text{ hours}$. | Secondary NewSpace Sun Sensor acts as coarse pointing fallback while reaction wheels stabilize craft. | **Kepler Space Telescope:** Multi-tier attitude sensor redundancy prevents mission-ending loss of attitude control. |
| **E14** | **Thermal Environment Extremes** | Major | $7\%$ | Severe vacuum temperature gradient causes component overheating or freezing. | Install properly sized Thermal MLI Kit (S/M/L) and passive louvers. | **NASA LLIS 1102:** Multilayer insulation blankets and thermal balance testing prevent deep-space component freeze. |

---

#### 4. Lunar Surface Operations Phase

| ID | Event Title | Severity | Probability | Operational Impact | Player Decision / Mitigation | Historical Precedent & NASA Lesson |
|---|---|---|---|---|---|---|
| **E15** | **Touchdown Boulder & Slope Hazard** | Critical | Roll against landing rule | Lander touches down on $25^\circ$ slope or large boulder; tip-over crash and mission loss. | **KaRA Landing Radar** (mandatory); **LHDAC Hazard Avoidance Lidar** detects obstacles; reserve $0.1\text{ km/s} \ \Delta v$ for landing divert. | **Apollo 11 & Chandrayaan-3:** Real-time visual/lidar hazard detection allows autonomous lander divert to safe landing zones. |
| **E16** | **Lunar Cryogenic Night Shock** | Critical | Always checked in Mission 8 | $354\text{ hours}$ without sunlight; temperature drops to $-180^\circ\text{C}$; lander electronics freeze. | **NASA RHU Night Kit** (Pu-238 decay heat) combined with **EaglePicher Deep Space Battery**. | **Chang'e-4 vs Surveyor:** Radioisotope heating enables long-duration lunar night survival; solar-only landers freeze. |
| **E17** | **Rover Mobility Wheel Entrapment** | Minor | $12\%$ | Micro-rover wheels sink into fine lunar regolith; rover stuck on surface. | Rocker-bogie suspension wiggling maneuver (costs $2\text{ days}$); surface APXS science continues. | **Spirit / Opportunity Rover:** Rocker-bogie drive design and cautious slip-angle monitoring overcome soft regolith traps. |

---

#### 5. Positive Opportunity

| ID | Event Title | Severity | Probability | Positive Operational Impact | Real-World Engineering Lesson |
|---|---|---|---|---|---|
| **E18** | **Mission Extension Approval** | Positive | $10\%$ | Systems operating beyond nominal health; agency approves mission extension. Yields **$+20\%$ Science Points** if fuel/power margins exist. | **Voyager / LRO / Opportunity:** Robust design margins allow multi-year mission extensions far beyond baseline life. |

---

### A5. Quantitative Landing Success Formula (Event E15)

The terminal powered descent to the lunar surface is the ultimate test of spacecraft guidance:

$$\text{Landing Success Probability} = P_{\text{base}} + \sum \text{Mitigation Modifiers}$$

| Engineering Factor | Modifier Value | Technical Requirement |
|---|---|---|
| **Base Landing Probability** | **$70\%$** | Raw ballistic descent without advanced terrain sensing. |
| **Chandrayaan-3 KaRA Landing Radar (G2)** | **MANDATORY** | **Without this radar altimeter/velocimeter, landing probability is $0\%$ (instant crash).** |
| **LHDAC Real-Time Hazard Lidar (G6)** | **$+15\%$** | Scans terrain for boulders $>30\text{ cm}$ and slopes $>15^\circ$; diverts lander. |
| **Propellant Margin $\ge 10\%$** | **$+5\%$** | Allows hover time for terminal guidance adjustments. |
| **System TVAC Qualification (L6)** | **$+5\%$** | Guarantees throttle valve actuators survive cryogenic propellant chill. |
| **Descent Optical Camera (G1)** | **$+0\%$** | Returns high-value touchdown imagery and bonus SP; does not alter landing odds. |

*Rule:* The final landing success probability is **capped at a maximum of $95\%$** (spaceflight is never risk-free). The **Descent Trajectory Planner (G5)** displays this exact calculated percentage to the player *before* launch.

---

### A6. Quantitative Lunar Night Survival Formula (Event E16)

The $14.75\text{-day}$ lunar night ($354\text{ hours}$ at $-180^\circ\text{C}$) freezes unshielded batteries and electronics:

| Spacecraft Configuration | Survival Probability | Engineering Outcome |
|---|---|---|
| **NASA RHU Night Kit (P4) + EaglePicher Battery (L)** | **$90\%$** | Spacecraft wakes up nominally when dawn sunlight strikes solar arrays. |
| **NASA RHU Night Kit (P4) + Medium Battery (M)** | **$65\%$** | Critical avionics survive; one non-essential instrument suffers thermal degradation. |
| **Electrical Resistance Heaters + Battery (L) (No RHU)** | **$45\%$** | Battery drains completely by Day 9; high risk of frozen propellant lines. |
| **Standard Baseline Bus (No Night Kit)** | **$5\%$** | Complete catastrophic freeze; satellite permanently dead at lunar sunset. |

---

## Part B: Mission Scoring & NASA Flight Debrief

### B1. The 100-Point Flight Rating System

$$\text{Total Mission Score} = \text{Primary Objectives (0–60)} + \text{Bonus Objectives (0–20)} + \text{Cost Efficiency (0–10)} + \text{Mass Utilization (0–10)}$$

| Scoring Component | Points | Calculation Formula & Evaluation Method |
|---|---|---|
| **Primary Mission Objectives** | **0–60** | $60 \times \left(\frac{\sum \text{Weight of Completed Objectives}}{\sum \text{Total Objective Weight}}\right)$. Binary pass/fail per requirement. |
| **Bonus Mission Objectives** | **0–20** | $+5\text{ points}$ each for: (1) Total cost under target budget, (2) Dry mass under target envelope, (3) Additional scientific data returned, (4) Operating beyond minimum lifespan. |
| **Cost Efficiency Factor** | **0–10** | $10 \times \text{clamp}\left(\frac{\text{Budget Saved}}{\text{Total Budget} \times 0.30}, 0, 1\right)$. Saving $30\%$ or more of contract budget earns full 10 points. |
| **Launcher Mass Utilization** | **0–10** | Ratio of Spacecraft Wet Mass to Launcher Maximum Capacity for target orbit:<br>• **80%–90%**: **10 points** (Optimal engineering sizing)<br>• **90%–100%**: **6 points** (High risk / tight margin)<br>• **60%–80%**: **6 points** (Acceptable sizing)<br>• **<60%**: **3 points** (Oversized, wasteful launch vehicle selection) |

---

### B2. Mission Ratings, Payouts, & Lessons Learned

| Flight Evaluation | Performance Threshold | Science Points Paid | Contract Funds Awarded |
|---|---|---|---|
| **Mission Loss / Failure** | No primary objectives met (launch failure or dead on arrival). | **$40\%$ of Base SP** ("Lessons Learned") | $\$0\text{M}$ |
| **Partial Mission Success** | Some primary objectives satisfied. | **$60\%$ of Base SP** | Proportional share of contract reward |
| **⭐ Success (1 Star)** | All primary objectives met; Score: $60\text{–}69$. | **$70\%$ of Base SP** | $100\%$ Contract Funds |
| **⭐⭐ Success (2 Stars)** | All primary objectives met; Score: $70\text{–}84$. | **$85\%$ of Base SP** | $100\%$ Contract Funds |
| **⭐⭐⭐ Success (3 Stars)** | Exceptional design; Score: $85\text{–}100$. | **$100\%$ of Base SP** | $100\%$ Contract Funds |

*Bonus SP Modifier:* Each completed secondary bonus objective grants an additional **$+5\%$ of base SP** (up to $+20\%$ extra SP on a 3-star mission).

---

### B3. Sample Flight Debrief: Mission 4 (Bangabandhu Satellite-1)

```
================================================================================
                    NASA FLIGHT READINESS & POST-MISSION DEBRIEF
               MISSION 4: GEOSTATIONARY GATEWAY (BANGABANDHU SATELLITE-1)
================================================================================

FLIGHT RATING: ⭐⭐⭐ (3 STARS) - TOTAL SCORE: 92.4 / 100

SCORE BREAKDOWN:
  [████████████████████] Primary Mission Objectives:  60.0 / 60 pts
  [███████████████░░░░░] Secondary Bonus Objectives:   15.0 / 20 pts
  [█████████████████░░░] Cost Efficiency (Saved 24%):   8.0 / 10 pts
  [████████████████████] Launch Mass Use (84.5% Cap):  10.0 / 10 pts

FLIGHT TIMELINE LOG:
  [T+00:00:00] Liftoff aboard SpaceX Falcon 9. Launch roll nominal (Roll: 98% vs 97% req).
  [T+00:32:00] Spacecraft deployed into Geostationary Transfer Orbit (GTO).
  [T+02:14:00] IN-FLIGHT INCIDENT: Coronal Mass Ejection detected (Solar Flare Event E7).
               >> BAE Systems RAD750 OBC prevented latch-up. Zero system damage.
  [T+04:10:00] Apogee circularization burn: Aerojet R-4D-15 engine delivered 1,500 m/s.
  [T+05:00:00] Geostationary Orbit achieved at 119.1° East. Solar arrays deployed (1.3 kW).
  [T+30 Days ] Ku/Ka-band telecommunications suite active. 100% transponder uptime.

PAYOUT & REWARDS:
  • Science Points Earned: 110 Base SP + 15% Bonus = 126 SP
  • Contract Funding: $175.0M
  • Technologies Unlocked: Deep Space Comms (C3), LROC Camera (I6), Tier 3 Tech Tree

NASA LESSONS LEARNED CITATION:
  "NASA LLIS 1421: In geostationary orbit, exposure to trapped electrons and solar proton
   events degrades unprotected CMOS microprocessors within days. The inclusion of the
   radiation-hardened BAE RAD750 flight computer preserved vehicle command authority."
================================================================================
```