# Simulation records

Time-domain outputs of the Simulink model of the Kundur two-area system (MATLAB/Simulink R2018b, Simscape Electrical Specialized Power Systems). Every record spans 0–200 s and is sampled at 60 Hz (12 001 samples, uniform). The first 150 s are the initialization interval; the disturbance is applied at **t = 150 s**, the origin of the time axes in Figs. 3 and 4 of the paper.

## `small_signal/` — Table I

Disturbance: 0.02 pu pulse on the voltage reference of the AVR of G3, from 150.0 s to 150.1 s.

| File | Scenario |
|---|---|
| `Kundur_FullSync.mat` | Fully synchronous system (G1–G4 with AVR, governor and Δω PSS) |
| `Kundur_PVcontrolP.mat` | G2 replaced by the PV plant, P-control (constant active power) |
| `Kundur_PVcontrolQ.mat` | G2 replaced by the PV plant, Q-control (constant reactive power) |
| `Kundur_PVcontrolV.mat` | G2 replaced by the PV plant, V-control (constant voltage) |

| Variable | Size | Unit | Description |
|---|---|---|---|
| `t1` | 12001×1 | s | Time |
| `PB79` | 12001×1 | MW | Active power on the tie-line from bus 7 to bus 9 (P79) |
| `DwG3` | 12001×1 | pu | Rotor speed deviation of G3 |
| `dwG1`, `dwG2`, `dwG4` | 12001×1 | pu | Rotor speed deviations of G1, G2 and G4 (`dwG2` is zero in the PV scenarios, where G2 is removed) |

`tls_esprit_modes.m` uses `t1`, `PB79` (inter-area mode) and `DwG3` (local mode of Area 2).

## `three_phase_fault/` — Figs. 3 and 4

Disturbance: balanced three-phase fault at bus 9, applied at 150 s and cleared after 12 cycles (200 ms).

| File | Scenario |
|---|---|
| `Kundur_Fault_FullSync.mat` | Fully synchronous system |
| `Kundur_Fault_PVcontrolP.mat` | PV plant, P-control |
| `Kundur_Fault_PVcontrolQ.mat` | PV plant, Q-control |
| `Kundur_Fault_PVcontrolV.mat` | PV plant, V-control |

| Variable | Size | Unit | Description |
|---|---|---|---|
| `t1` | 12001×1 | s | Time |
| `DELTAT` | 12001×4 | deg | Angle δ of G1–G4 from the Simscape machine measurement (column 2 is zero in the PV scenarios) |
| `dwT` | 12001×4 | pu | Rotor speed deviations of G1–G4 |
| `PeT` | 12001×4 | pu (900 MVA) | Electrical power of G1–G4 |
| `Vt` | 12001×4 | pu | Terminal voltage magnitudes of G1–G4 |
| `PB79` | 12001×1 | MW | Active power on the tie-line from bus 7 to bus 9 (P79) |

## Provenance

After each run the full MATLAB workspace was saved. The files here keep only the variables listed above, with their values unchanged; `tools/slim_record.m` performs this step. The P-, Q- and V-control small-signal files already contained only these variables and are the original files.
