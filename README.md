# Impact of Photovoltaic Power Plant Control Modes on Small-Signal and Transient Stability in Low-Inertia Power Systems

**Journal:** IEEE Latin America Transactions, 2026  
**Authors:** Ángel González Domínguez, Héctor García Viveros, Marco A. Arjona López, Concepción Hernández  
*Tecnológico Nacional de México – Instituto Tecnológico de La Laguna, Torreón, Coahuila, México*

This repository contains the Simulink models, the simulation records and the MATLAB code that reproduce the small-signal (Table I) and transient-stability results of the paper.

## Overview

Generator G2 of the Kundur two-area system is replaced by a grid-following photovoltaic (PV) plant modeled with the WECC generic models REGC_A, REEC_B and REPC_A. The plant injects at bus 6 the same steady-state power that G2 delivered through its transformer, so the four scenarios start from the same operating point. G1, G3 and G4 keep their exciter, steam turbine governor and Δω power system stabilizer.

| Scenario | Record prefix | PV plant control |
|---|---|---|
| Fully synchronous | `sync` | None (G1–G4 synchronous) |
| P-control | `pv_p` | Constant local power factor (REEC_B, PfFlag = 1) |
| Q-control | `pv_q` | Plant-level reactive power control at bus 6 (REPC_A, RefFlag = 0) |
| V-control | `pv_v` | Plant-level voltage control at bus 6 (REPC_A, RefFlag = 1, VcompFlag = 1, Rc = Xc = 0) |

In the three PV scenarios the active power is constant (FrqFlag = 0) and reactive current has priority. Two disturbances are applied at t = 150 s:

- **Small signal:** a 0.02 pu pulse on the AVR voltage reference of G3, 150.0–150.1 s. TLS-ESPRIT identifies the inter-area mode in the tie-line power P79 and the local mode of Area 2 in the rotor speed of G3 (Table I).
- **Large signal:** a three-phase fault at bus 9 cleared after 12 cycles (200 ms) or 9 cycles (150 ms), without line tripping.

## Repository contents

```
.
├── run_all.m                 Main script: operating point, Table I and figures
├── tls_esprit_modes.m        TLS-ESPRIT mode identification of one record
├── plot_responses.m          Tie-line power and inter-area angle after each disturbance
├── simulate_cases.m          Regenerates data/ with the Simulink models
├── models/
│   ├── kundur_sync.slx       Fully synchronous Kundur two-area system
│   ├── kundur_pv.slx         G2 replaced by the WECC PV plant
│   └── SolarInverter_Params.m  PV plant parameters (run by the models)
├── data/                     Simulation records, <scenario>_<event>.mat
├── CITATION.cff
└── LICENSE
```

| File | Paper | Description |
|---|---|---|
| `run_all.m` | Table I, fault figures | Checks the pre-disturbance operating point of every record, runs TLS-ESPRIT on the four pulse records, writes `results/table1.csv` and draws all figures. |
| `tls_esprit_modes.m` | Section III, Table I | Hankel matrix, TLS-ESPRIT poles for model orders 2–60, stabilization diagram, least-squares mode energy, window sweep and Monte Carlo noise test. |
| `plot_responses.m` | Fault figures | P79 and the inter-area angle separation Δδ = δ<sub>Area 1</sub> − δ<sub>Area 2</sub> (centres of inertia) for the pulse and the fault records. |
| `simulate_cases.m` | — | Sets the event (pulse or N-cycle fault) and, in the PV model, the control flags and plant references, simulates and saves the record. |
| `models/kundur_sync.slx` | Section II | Network, machines and controls of the reference case. The PV plant blocks are present but commented out. |
| `models/kundur_pv.slx` | Section II | Same network with G2 and its transformer commented out and the PV plant connected to bus 6. |

### Simulation records (`data/`)

Outputs of the Simulink models from 0 to 200 s, sampled at 60 Hz (12 001 samples). Event: `pulse`, `fault12` or `fault9`.

| Record | Scenario | Event |
|---|---|---|
| `sync_pulse.mat`, `pv_p_pulse.mat`, `pv_q_pulse.mat`, `pv_v_pulse.mat` | All four | AVR pulse at G3 |
| `sync_fault12.mat`, `pv_p_fault12.mat`, `pv_q_fault12.mat`, `pv_v_fault12.mat` | All four | Fault at bus 9, 12 cycles |
| `sync_fault9.mat`, `pv_p_fault9.mat`, `pv_q_fault9.mat`, `pv_v_fault9.mat` | All four | Fault at bus 9, 9 cycles |

| Variable | Unit | Description |
|---|---|---|
| `t1` | s | Time |
| `PB79` | MW | Active power on the tie-line from bus 7 to bus 9 (P79) |
| `DwG3` | pu | Rotor speed deviation of G3 |
| `dwT` | pu | Rotor speed deviations of G1–G4 |
| `dthetaT` | rad | Rotor angle deviations of G1–G4 with respect to the synchronous reference frame |
| `VB79` | pu | Voltage magnitudes at buses 7 and 9 |
| `PB2`, `QB2` | MW, MVAr | Power delivered by G2 to bus 6 (`sync` records) |
| `PB5`, `PB5Q`, `V5` | MW, MVAr, pu | Power injected by the PV plant at bus 6 and voltage at bus 6 (`pv` records) |

In the PV records the second column of `dwT` and `dthetaT` (G2) is zero.

## Requirements

- Analysis (`run_all`): MATLAB R2018b or later, no toolboxes.
- Simulation (`simulate_cases`, `run_all('simulate', true)`): MATLAB/Simulink R2023b or later with Simscape Electrical (Specialized Power Systems) and Stateflow.

## How to run

1. Clone or download the repository and open MATLAB in its folder.
2. Run
   ```matlab
   run_all
   ```
   The results are written to `results/`. The Monte Carlo noise test is the slowest part; `run_all('noise', false)` skips it.

To regenerate the records with Simulink before the analysis:

```matlab
run_all('simulate', true)
simulate_cases({'pv_q_fault9'})        % one record only
```

To identify the modes of a single record:

```matlab
rec = load(fullfile('data', 'pv_q_pulse.mat'));
res = tls_esprit_modes(rec, 'Q-control');
```

## Expected results

Table I (f in Hz, ζ per unit):

| Case | Inter-area f | Inter-area ζ | Local Area 2 f | Local Area 2 ζ |
|---|---|---|---|---|
| Fully synchronous | 0.6124 | 0.2566 | 1.4965 | 0.3180 |
| P-control | 0.6229 | 0.2276 | 1.4946 | 0.3200 |
| Q-control | 0.6245 | 0.2316 | 1.4971 | 0.3201 |
| V-control | 0.6337 | 0.2179 | 1.4945 | 0.3198 |

Before the disturbances every record has P79 = 400.4 MW, 699.9 MW and 131.5–131.6 MVAr injected at bus 6 and a frequency of 60.000 Hz. With V-control, G1 loses synchronism after the 12-cycle fault; with the 9-cycle fault it remains stable.

| Output in `results/` | Content |
|---|---|
| `operating_point.csv` | P79, power at bus 6, V7, V9 and frequency at t = 149 s for every record |
| `table1.csv` | Identified f and ζ, window-sweep ranges and 5–95 % ζ interval at 30 dB SNR |
| `<scenario>/summary.txt`, `PB79_modes.csv`, `DwG3_modes.csv`, `tlsesprit.png` | TLS-ESPRIT details of each scenario |
| `figures/damping_comparison.png` | Damping ratios of Table I with their window-sweep and noise intervals |
| `figures/pulse_P79.png` | P79 after the AVR pulse |
| `figures/fault12_P79`, `fault12_angle`, `fault9_P79`, `fault9_angle` (.png, .pdf) | P79 and Δδ after the 12- and 9-cycle faults |

## Notes for reproducibility

- Each simulation runs 150 s before the disturbance so that all scenarios reach steady state.
- Operating point: the reference case uses the load flow of the Kundur system (Kundur, Example 12.6) with constant-PQ loads; in the time domain the loads are constant impedance. Transformers have no magnetizing branch (Rm = Lm = 10⁴ pu) and machine saturation is not modeled. Governor references equal the initial mechanical power, so the frequency is 60 Hz.
- The PV plant references are P0 = 699.909 MW, Q0 = 131.641 MVAr and V0 = 0.98054 pu, the values measured at bus 6 in the reference case (`simulate_cases.m`). The plant is connected directly to bus 6, as in the examples of the WECC model repository. Do not run the load flow on `kundur_pv.slx`; it keeps the initial conditions of the reference case.
- TLS-ESPRIT uses the same settings in every scenario: windows starting 0.5 s (P79) and 0.1 s (ΔωG3) after the pulse and lasting 4 periods of 0.62 Hz (6.45 s), linear detrending, Hankel matrix with M = N/2 rows, model orders 2–60, stabilization criteria Δf/f < 1 % and Δζ/ζ < 5 %, band 0.1–2 Hz and dominant modes with normalized energy NE ≥ 0.10.
- Robustness checks: 30 windows (start shifted 0–0.5 s, length 3–4 periods) and white noise at 40, 30 and 20 dB SNR, 200 runs per level, with a fixed random seed.
- Δδ uses the inertia constants H = 6.5 s (G1, G2) and 6.175 s (G3, G4). Area 1 is G1 and G2 in the synchronous case and G1 alone in the PV scenarios.
- The synchronous-machine controls follow the Simscape Electrical example `power_PSS` (Excitation System, Steam Turbine and Governor, Generic Power System Stabilizer). The PV plant models and parameters come from [jonlesage/Renewable-PPMV](https://github.com/jonlesage/Renewable-PPMV), with ratings of 900 MVA and 230 kV, plant-controller gains Kp = 0.6, Ki = 1.8, Kpg = 0.1 and Kig = 0.5, and plant reactive power limits of ±0.435 pu.

## Method references

1. NERC, "Recommended Oscillation Analysis for Monitoring and Mitigation Reference Document," Nov. 2021.
2. R. Roy and T. Kailath, "ESPRIT—Estimation of signal parameters via rotational invariance techniques," *IEEE Trans. Acoust., Speech, Signal Process.*, vol. 37, no. 7, pp. 984–995, 1989.
3. P. Tripathy, S. C. Srivastava and S. N. Singh, "A modified TLS-ESPRIT-based method for low-frequency mode identification in power systems utilizing synchrophasor measurements," *IEEE Trans. Power Syst.*, vol. 26, no. 2, pp. 719–727, 2011.
4. M. Sahoo and S. Rai, "An improved TLS-ESPRIT-based mode identification technique for low-frequency oscillations in power system using synchrophasor measurements," *Electrical Engineering*, vol. 107, no. 4, pp. 4103–4123, 2025.
5. Y. Hua and T. K. Sarkar, "Matrix pencil method for estimating parameters of exponentially damped/undamped sinusoids in noise," *IEEE Trans. Acoust., Speech, Signal Process.*, vol. 38, no. 5, pp. 814–824, 1990.
6. R. Kuiava, E. Z. dos Passos, G. H. da C. Oliveira and R. Schumacher, "Separating low-frequency electromechanical modes from spurious modes in ambient data analysis by means of modal stabilization diagrams," *Electr. Power Syst. Res.*, vol. 201, 107502, 2021.
7. M. He, P. Liang, J. Liu and Z. Liang, "Review and comparison of methods and benchmarks for automatic modal identification based on stabilization diagram," *J. Traffic Transp. Eng. (Engl. Ed.)*, vol. 11, no. 2, pp. 209–224, 2024.
8. E.-H. Djermoune and M. Tomczak, "Perturbation analysis of subspace-based methods in estimating a damped complex exponential," *IEEE Trans. Signal Process.*, vol. 57, no. 11, pp. 4558–4563, 2009.
9. MathWorks, "modalsd: Generate stabilization diagram for modal analysis," Signal Processing Toolbox documentation.
10. J. Follum, F. Tuffner, L. Dosiek and J. Pierre, "Power system oscillatory behaviors: Sources, characteristics, & analyses," PNNL-26375, May 2017.

## Citation

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

## Contact

Ángel González Domínguez — m.agonzalezd@correo.itlalaguna.edu.mx

## License

Code and data are released under the BSD 3-Clause License (see `LICENSE`). The PV plant models derive from jonlesage/Renewable-PPMV (The MathWorks, Inc., BSD 3-Clause).

## Acknowledgment

Tecnológico Nacional de México – Instituto Tecnológico de La Laguna and the Secretaría de Ciencia, Humanidades, Tecnología e Innovación (SECIHTI).
