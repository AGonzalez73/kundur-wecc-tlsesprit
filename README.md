# Impact of Photovoltaic Power Plant Control Modes on Small-Signal and Transient Stability in Low-Inertia Power Systems

**Journal:** IEEE Latin America Transactions, 2026  
**Authors:**  
- Ángel González Domínguez  
- Héctor García Viveros  
- Marco A. Arjona López  
- Concepción Hernández  

*Tecnológico Nacional de México – Instituto Tecnológico de La Laguna, Torreón, Coahuila, México*

---

## 🔎 Overview

Generator G2 of the Kundur two-area system is completely replaced by a grid-following photovoltaic (PV) plant, modeled with the WECC generic models REGC_A, REEC_A and REPC_A and tuned to the steady-state P and Q of G2. G1, G3 and G4 keep their AVR, turbine governor and Δω power system stabilizer. Four scenarios are compared:

| Scenario | PV plant control |
|---|---|
| Fully synchronous | None (reference case, G1–G4 synchronous) |
| PV – P-control | Constant active power |
| PV – Q-control | Constant reactive power (fixed power factor) |
| PV – V-control | Voltage regulation at the point of interconnection |

- **Small-signal stability (Table I):** a 0.02 pu pulse on the AVR reference of G3 excites the electromechanical modes. TLS-ESPRIT identifies the inter-area mode in the tie-line power P79 and the local mode of Area 2 in the rotor speed of G3.
- **Transient stability (Figs. 3–4):** a three-phase fault at bus 9, cleared after 12 cycles. The inter-area angle separation Δδ(t) and P79 are compared.

---

## 📁 Included Files

This repository contains the scripts and simulation records required to reproduce the small-signal and transient-stability results reported in the manuscript.

```
.
├── README.md
├── run_all.m                  Main script (Table I and Figs. 3-4)
├── tls_esprit_modes.m         TLS-ESPRIT mode identification
├── plot_fault_response.m      Figs. 3 and 4
├── data/                      Simulation records (.mat)
├── CITATION.cff
└── LICENSE
```

### MATLAB

| File | Related Table / Figure / Equation | Description |
|---|---|---|
| `run_all.m` | Table I, Figs. 3–4 | Main script. Runs the TLS-ESPRIT identification on the four small-signal records, prints the identified modes next to the values of Table I, writes `results/table1.csv` and draws Figs. 3 and 4. |
| `tls_esprit_modes.m` | Eqs. (1)–(4), Section III, Table I | Mode identification of one record: Hankel matrix, TLS-ESPRIT poles for model orders 2–60, stabilization diagram, least-squares mode energy, window sweep and Monte Carlo noise test. The header documents every setting and its reference. |
| `plot_fault_response.m` | Eq. (5), Figs. 3–4 | Inter-area angle separation Δδ(t) (centre of inertia of each area) and tie-line power P79 after the three-phase fault. |

### Simulation records (`data/`)

Outputs of the Simulink model of the Kundur two-area system: 0–200 s sampled at 60 Hz (12 001 samples). The disturbance is applied at t = 150 s.

| File | Related Table / Figure | Scenario | Disturbance |
|---|---|---|---|
| `Kundur_FullSync.mat` | Table I | Fully synchronous | Vref pulse at G3 |
| `Kundur_PVcontrolP.mat` | Table I | PV – P-control | Vref pulse at G3 |
| `Kundur_PVcontrolQ.mat` | Table I | PV – Q-control | Vref pulse at G3 |
| `Kundur_PVcontrolV.mat` | Table I | PV – V-control | Vref pulse at G3 |
| `Kundur_Fault_FullSync.mat` | Figs. 3–4 | Fully synchronous | Three-phase fault at bus 9 |
| `Kundur_Fault_PVcontrolP.mat` | Figs. 3–4 | PV – P-control | Three-phase fault at bus 9 |
| `Kundur_Fault_PVcontrolQ.mat` | Figs. 3–4 | PV – Q-control | Three-phase fault at bus 9 |
| `Kundur_Fault_PVcontrolV.mat` | Figs. 3–4 | PV – V-control | Three-phase fault at bus 9 |

| Variable | Unit | Description | Records |
|---|---|---|---|
| `t1` | s | Time | All |
| `PB79` | MW | Active power on the tie-line from bus 7 to bus 9 (P79) | All |
| `DwG3` | pu | Rotor speed deviation of G3 | Small-signal |
| `dwG1`, `dwG2`, `dwG4` | pu | Rotor speed deviations of G1, G2 and G4 (`dwG2` is zero in the PV scenarios) | Small-signal |
| `DELTAT` | deg | Angle δ of G1–G4 from the Simscape machine measurement (column 2 is zero in the PV scenarios) | Fault |
| `dwT` | pu | Rotor speed deviations of G1–G4 | Fault |
| `PeT` | pu (900 MVA) | Electrical power of G1–G4 | Fault |
| `Vt` | pu | Terminal voltage magnitudes of G1–G4 | Fault |

---

## 💻 Requirements

### MATLAB
- MATLAB R2018b or later.
- No toolboxes are required to run the scripts.

### Simulink (only to regenerate the records)
- MATLAB/Simulink R2018b with Simscape Electrical (Specialized Power Systems).

---

## ▶️ How to Run

### Full reproduction
1. Download the repository (**Code → Download ZIP**) and extract it, or clone it.
2. Open MATLAB and set the repository folder as the current folder.
3. Run:
   ```matlab
   run_all
   ```
   The Monte Carlo noise test is the slowest part; `run_all('noise', false)` skips it and takes about a minute.
4. The results are written to `results/` (see **Expected Results**).

### One scenario at a time (Table I)
```matlab
load(fullfile('data', 'Kundur_PVcontrolV.mat'))
tls_esprit_modes          % set caseName at the top of the script first
```

### Figs. 3–4 only
```matlab
plot_fault_response
```

---

## 📊 Expected Results

`run_all` prints the identified modes and, under each row, the values published in Table I (f in Hz, ζ per unit):

| Case | Inter-area f | Inter-area ζ | Local Area 2 f | Local Area 2 ζ |
|---|---|---|---|---|
| Fully synchronous | 0.612 | 0.256 | 1.490 | 0.318 |
| PV – P-control | 0.624 | 0.228 | 1.491 | 0.319 |
| PV – Q-control | 0.621 | 0.234 | 1.490 | 0.319 |
| PV – V-control | 0.636 | 0.216 | 1.498 | 0.315 |

| Output in `results/` | Content |
|---|---|
| `table1.csv` | Identified f and ζ next to Table I, window-sweep ranges and 5–95 % ζ interval at 30 dB SNR |
| `<case>/summary.txt` | Full TLS-ESPRIT summary of each scenario and the settings used |
| `<case>/PB79_modes.csv`, `<case>/DwG3_modes.csv` | Every physical mode found in each signal |
| `<case>/tlsesprit_modes.png` | Window fit and stabilization diagram |
| `fig3_angle_separation.png/.pdf` | Fig. 3: (a) 150–200 s, (b) 150–161 s |
| `fig4_tieline_power.png/.pdf` | Fig. 4: 149–165 s |

---

## 📌 Notes for Reproducibility

- Every simulation includes a 150 s initialization interval; the disturbances are applied at t = 150 s, the origin of the time axes in Figs. 3–4.
- Small-signal disturbance: 0.02 pu pulse on the voltage reference of the AVR of G3 from 150.0 s to 150.1 s. Large disturbance: three-phase fault at bus 9 at 150 s, cleared after 12 cycles (200 ms).
- Only the free response is identified. The windows start 0.5 s (P79) and 0.1 s (rotor speed of G3) after the end of the pulse and last 4 periods of 0.62 Hz (6.45 s).
- The TLS-ESPRIT settings are the same for every scenario: linear detrending, unit-variance scaling, Hankel matrix with M = N/2 rows, model orders 2–60, stabilization criteria Δf/f < 1 % and Δζ/ζ < 5 %, band 0.1–2 Hz, dominant modes with normalized energy NE ≥ 0.10.
- Robustness checks: 30 windows (start shifted 0–0.5 s, length 3–4 periods) and white noise at 40, 30 and 20 dB SNR (200 runs per level). The random seed is fixed, so the results are deterministic.
- Δδ(t) follows Eq. (5): δ_Area2 is the centre of inertia of G3 and G4; δ_Area1 is the centre of inertia of G1 and G2 in the fully synchronous case and G1 alone in the PV scenarios, with H from Table II.
- The records keep only the variables listed above, copied unchanged from the workspace saved after each simulation.
- The synchronous-machine controls (IEEE Type-1 exciter, governor and Δω PSS) follow the Simscape Electrical example `power_PSS` (I. Kamwa, The MathWorks, Inc.). The PV plant parameters are those of [jonlesage/Renewable-PPMV](https://github.com/jonlesage/Renewable-PPMV) (The MathWorks, Inc., BSD-3-Clause). Only the P/Q setpoints and the control mode change between the PV scenarios.

---

## 📝 Citation

If you use this code or data, please cite:

```bibtex
@article{gonzalezdominguez2026pv,
  author  = {Gonz{\'a}lez Dom{\'i}nguez, {\'A}ngel and Garc{\'i}a Viveros, H{\'e}ctor and
             Arjona L{\'o}pez, Marco A. and Hern{\'a}ndez, Concepci{\'o}n},
  title   = {Impact of Photovoltaic Power Plant Control Modes on Small-Signal and
             Transient Stability in Low-Inertia Power Systems},
  journal = {IEEE Latin America Transactions},
  year    = {2026}
}
```

GitHub also offers this citation under **Cite this repository** (from `CITATION.cff`).

---

## ✉️ Contact

For questions, clarifications, or replication of results:

**Ángel González Domínguez**  
📧 m.agonzalezd@correo.itlalaguna.edu.mx

---

## ⚖️ License

Code and data are released under the BSD 3-Clause License (see `LICENSE`). Third-party components keep their own licenses.

## Acknowledgment

Tecnológico Nacional de México – Instituto Tecnológico de La Laguna, and the Secretaría de Ciencia, Humanidades, Tecnología e Innovación (SECIHTI).
