# Simulink models

Place here the Simulink models that generate the records in `data/`:

| Model | Scenario | Produces |
|---|---|---|
| `Kundur_FullSync.slx` | Fully synchronous system | `small_signal/Kundur_FullSync.mat`, `three_phase_fault/Kundur_Fault_FullSync.mat` |
| `Kundur_PV.slx` | G2 replaced by the WECC PV plant (REGC_A, REEC_A, REPC_A); control mode selected in the plant controller | `small_signal/Kundur_PVcontrol{P,Q,V}.mat`, `three_phase_fault/Kundur_Fault_PVcontrol{P,Q,V}.mat` |

Requirements: MATLAB/Simulink R2018b or later with Simscape Electrical (Specialized Power Systems).

To regenerate a record: open the model, select the scenario (PV control mode and disturbance: Vref pulse at G3 or three-phase fault at bus 9), run the 200 s simulation, and reduce the saved workspace with `tools/slim_record.m`.

## Origin of the components

- Network, synchronous machines, AVR, governor and Δω PSS: the Kundur two-area implementation distributed with Simscape Electrical Specialized Power Systems, `power_PSS` (I. Kamwa, The MathWorks, Inc.) [13 in the paper].
- PV plant: WECC generic models REGC_A, REEC_A and REPC_A with the parameter set of J. LeSage, *Renewable energy system model validation with MATLAB/Simulink*, The MathWorks, Inc., BSD-3-Clause, <https://github.com/jonlesage/Renewable-PPMV> [17 in the paper]. Redistributed parts must keep that repository's copyright notice and license text.
