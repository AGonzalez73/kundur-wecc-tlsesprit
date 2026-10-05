# kundur-wecc-tlsesprit

> **MATLAB/Simulink code and data to reproduce the results of:**
>
> Á. González Domínguez, H. García Viveros, M. A. Arjona López and C. Hernández, "Impact of Photovoltaic Power Plant Control Modes on Small-Signal and Transient Stability in Low-Inertia Power Systems," *IEEE Latin America Transactions*, 2026.

---

## Overview

Generator G2 of the Kundur two-area system is completely replaced by a grid-following photovoltaic (PV) plant built from the WECC generic models REGC_A, REEC_A and REPC_A, tuned to the same steady-state P and Q as G2. The remaining machines (G1, G3, G4) keep their AVR, turbine governor and Δω power system stabilizer. Four scenarios are compared:

| Scenario | Description |
|---|---|
| **Fully synchronous** | G1–G4 synchronous machines (reference case) |
| **PV – P-control** | PV plant at constant active power |
| **PV – Q-control** | PV plant at constant reactive power (fixed power factor) |
| **PV – V-control** | PV plant regulating the voltage at the point of interconnection |

Two analyses are performed:

1. **Small-signal (Table I):** a 0.02 pu pulse on the AVR reference of G3 excites the electromechanical modes. TLS-ESPRIT with a stabilization diagram identifies the frequency and damping ratio of the inter-area mode (tie-line power P79) and of the local mode of Area 2 (rotor speed of G3).
2. **Transient stability (Figs. 3 and 4):** a three-phase fault at bus 9, cleared after 12 cycles; inter-area angle separation Δδ(t) and tie-line power P79.

---

## Repository structure

```
.
├── README.md
├── run_all.m                  # Reproduces Table I and Figs. 3-4 (entry point)
├── tls_esprit_modes.m         # TLS-ESPRIT mode identification (Section III, Table I)
├── run_tlsesprit_case.m       # Runs tls_esprit_modes.m on one record, saves its outputs
├── plot_fault_response.m      # Figs. 3 and 4
├── tools/
│   └── slim_record.m          # Extracts the signals used here from a saved simulation workspace
├── data/
│   ├── README.md              # Variables, units and provenance
│   ├── small_signal/          # Vref pulse at G3: 4 scenarios (Table I)
│   └── three_phase_fault/     # Fault at bus 9: 4 scenarios (Figs. 3-4)
├── models/
│   └── README.md              # Simulink models of the four scenarios
├── CITATION.cff
└── LICENSE
```

| File | Paper item | Description |
|---|---|---|
| `tls_esprit_modes.m` | Section III, Table I | TLS-ESPRIT on the Hankel matrix of a ringdown window, stabilization diagram over model orders 2–60, least-squares mode energy, window sweep (30 windows) and Monte Carlo noise test (40/30/20 dB SNR, 200 runs). The header documents every setting and its reference. |
| `run_all.m` | Table I, Figs. 3–4 | Runs the four small-signal scenarios, prints the identified modes next to Table I and writes `results/table1.csv`; then draws Figs. 3 and 4. |
| `plot_fault_response.m` | Figs. 3–4, Eq. (5) | Δδ(t) = δ_Area1 − δ_Area2 (centre of inertia, H from Table II) and P79 after the fault. |
| `data/small_signal/*.mat` | Table I | `t1`, `PB79`, `DwG3` (+ speeds of G1, G2, G4). |
| `data/three_phase_fault/*.mat` | Figs. 3–4 | `t1`, `DELTAT`, `PB79` (+ speeds, electrical power and terminal voltages of G1–G4). |

---

## Requirements

| Software | Needed for |
|---|---|
| MATLAB R2018b or later | All scripts. No toolboxes. |
| Simulink + Simscape Electrical (Specialized Power Systems) | Only to re-run the models in `models/` |

---

## Quick start

Open MATLAB in the repository root and run

```matlab
run_all                    % full run: Table I with window sweep and noise test, then Figs. 3-4
run_all('noise', false)    % skips the Monte Carlo noise test (about a minute)
```

`run_all` changes to the repository root while it runs, so it can be called from any folder once the repository is on the MATLAB path. The Monte Carlo noise test (200 runs × 3 SNR levels × 2 signals × 4 scenarios) is the slowest part.

### Outputs (`results/`, created on the first run)

| File | Content |
|---|---|
| `table1.csv` | Identified f and ζ for each scenario next to the values of Table I, with the window-sweep ranges and the 5–95 % damping interval at 30 dB SNR |
| `<case>/summary.txt` | Full TLS-ESPRIT summary of the scenario and the settings used |
| `<case>/PB79_modes.csv`, `<case>/DwG3_modes.csv` | Every physical mode found in each signal |
| `<case>/tlsesprit_modes.png` | Window fit and stabilization diagram |
| `fig3_angle_separation.png/.pdf` | Fig. 3 (a) 150–200 s and (b) 150–161 s |
| `fig4_tieline_power.png/.pdf` | Fig. 4 |

---

## Reproducing Table I

`run_all` prints the identified modes and, below each row, the values published in Table I (f in Hz, ζ per unit):

| Case | Inter-area f (Hz) | Inter-area ζ | Local Area 2 f (Hz) | Local Area 2 ζ |
|---|---|---|---|---|
| Fully synchronous | 0.612 | 0.256 | 1.490 | 0.318 |
| PV – P-control | 0.624 | 0.228 | 1.491 | 0.319 |
| PV – Q-control | 0.621 | 0.234 | 1.490 | 0.319 |
| PV – V-control | 0.636 | 0.216 | 1.498 | 0.315 |

To analyse a single scenario interactively:

```matlab
load(fullfile('data', 'small_signal', 'Kundur_PVcontrolV.mat'))
tls_esprit_modes           % set caseName at the top of the script first
```

### Method in brief

| Step | Setting | Value |
|---|---|---|
| Window | Start after the end of the Vref pulse (150.1 s) | +0.5 s for PB79, +0.1 s for DwG3 |
| | Length | 4 periods of 0.62 Hz = 6.45 s (388 samples at 60 Hz) |
| Preprocessing | Detrending; scaling | Linear; unit variance |
| Poles | TLS-ESPRIT on the Hankel matrix | M = N/2 rows, model orders 2–60 |
| Physical modes | Stabilization diagram | Δf/f < 1 %, Δζ/ζ < 5 %, stable in ≥ 30 % of the orders, band 0.1–2 Hz |
| Reported value | Median of the stable poles of the mode | |
| Dominance | Normalized pseudo-energy from a least-squares fit | NE ≥ 0.10 |
| Reported mode | Largest NE in the signal's range | PB79: 0.1–1 Hz (inter-area); DwG3: 1–2 Hz (local) |
| Robustness | Window sweep | Start +0…0.5 s, length 3–4 periods (30 windows) |
| | Additive white noise | 40, 30, 20 dB SNR, 200 runs each, fixed seed |

The basis and references for every setting are in the header of `tls_esprit_modes.m`.

---

## Reproducing Figs. 3 and 4

```matlab
plot_fault_response        % reads data/three_phase_fault, writes results/
```

Δδ(t) follows Eq. (5): δ_Area2 is the centre of inertia of G3 and G4, δ_Area1 the centre of inertia of G1 and G2 in the fully synchronous case and G1 alone once G2 is replaced by the PV plant. Fig. 3(a) spans 150–200 s and Fig. 3(b) 150–161 s; Fig. 4 shows P79 from 149 to 165 s.

---

## System and study parameters

| Item | Value |
|---|---|
| Network | Kundur two-area, four-machine system, 230 kV, 60 Hz; data in the Appendix of the paper (Tables II and III) |
| Synchronous machine controls | IEEE Type-1 exciter (gain 200), thermal-plant governor, Δω PSS (gain 30, 15 ms transducer), from `power_PSS` [13] |
| PV plant | WECC REGC_A, REEC_A, REPC_A with the field-validated parameter set of [17]; only the P/Q setpoints and the control mode change between scenarios |
| Initialization | 150 s before every disturbance |
| Small-signal disturbance | 0.02 pu pulse on Vref of the AVR of G3, 150.0–150.1 s |
| Large disturbance | Three-phase fault at bus 9, 150 s, cleared after 12 cycles (200 ms) |
| Simulation length, output rate | 200 s, 60 Hz |
| Software | MATLAB/Simulink R2018b, Simscape Electrical (Specialized Power Systems) |

---

## Third-party components

- The Kundur two-area implementation with its AVR, governor and PSS settings is the Simscape Electrical example `power_PSS` (I. Kamwa, The MathWorks, Inc.).
- The WECC PV plant model and parameters come from [jonlesage/Renewable-PPMV](https://github.com/jonlesage/Renewable-PPMV) (The MathWorks, Inc., BSD-3-Clause).

---

## Citation

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

---

## Authors

- **Ángel González Domínguez** — Ph.D. student
- **Héctor García Viveros**
- **Marco A. Arjona López**
- **Concepción Hernández**

Tecnológico Nacional de México – Instituto Tecnológico de La Laguna, Torreón, Coahuila, México.
Contact: m.agonzalezd@correo.itlalaguna.edu.mx

## Acknowledgment

Tecnológico Nacional de México – Instituto Tecnológico de La Laguna, and the Secretaría de Ciencia, Humanidades, Tecnología e Innovación (SECIHTI).

## License

Code and data are released under the BSD 3-Clause License (see `LICENSE`). Third-party components keep their own licenses.
