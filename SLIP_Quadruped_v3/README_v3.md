# SLIP Quadruped v3

The v3 implementation contains autonomous hybrid dynamics, periodic-orbit correction, continuation, Floquet/bifurcation analysis and the MATLAB GUI. The protected `../SLIP_Quadruped` implementation is separate.

## Start MATLAB

From the repository root:

```matlab
addpath(fullfile(pwd,'SLIP_Quadruped_v3'));
V3AddPaths_v3();
SLIP_Quadruped_GUI_v3();
```

Click **Select Folder**, choose [P1](P1_Single_Flight_Phase_Continua/README.md) or [P2](P2_Double_Flight_Phase_Continua/README.md), then **Plot** or **Plot All**. The folder dropdown lists its available datasets. Select a plotted point to inspect its stored solution, edit axis limits in the separate input boxes, or open Visualization. Stored trajectories support viewing without a fresh numerical solve. Imported records require fresh validation before a new acceptance claim.

A native solver example uses the retained PK dataset directly:

```matlab
[orbit, report, framework] = QuadrupedalExample_v3();
QuadrupedalGraphicsExample_v3(orbit);
```

`QuadrupedalContinuationStudy_v3` and `QuadrupedalProductionStudy_v3` provide reusable numerical workflows. Examples can create new outputs; the historical campaign launchers and test-only scripts have been removed.

## Implementation and results

| Folder | Purpose |
|---|---|
| `1_Dynamic_Frameworks` | Coordinate schema, explicit legacy adapters, dynamics, guards, resets and hybrid integration. |
| `2_Graphic_ToolBox` | GUI, animation, state/force/phase plots and geometry. |
| `3_Numerical_Continuation` | Root correction, continuation, Floquet and bifurcation diagnostics. |
| `4_Solution_Management` | Sections, return policies, residuals, orbit data, gait classification, result I/O and examples. |
| `P1_Single_Flight_Phase_Continua` | C1 datasets and independent P1 audits. |
| `P2_Double_Flight_Phase_Continua` | C2 datasets and independent P2 audits. |
| `Docs_v3` | Model, algorithm and final scientific explanations. |
| `Audits_v3` | Runtime path maps, cleanup verification and selected final evidence. |

The six main datasets retain their original bytes and catalogs. Every P1 filename starts with C1; every P2 filename starts with C2, followed by gait abbreviation, linear stiffness, torsional stiffness and pitching inertia. The shared C2 PIP file is the intentional exact C1 PIP copy. A shared prefix or file does not establish branch connectivity.

The [30-hour strict-contact search audit](Docs_v3/Strict_P1_30h_Search_Audit_20261010_v3.md) found six validated lower-stiffness BG/BE/FG/FE/HG/HE points and seven generic principal diagnostic points. These are unordered points, not complete requested branches or validated bifurcation attachments. Use Select Folder with:

- [Validated lower-stiffness points](P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Strict_Contact_Results/Validated_Intermediate_Points/README.md).
- [Generic principal points](P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Strict_Contact_Results/Validated_Generic_Principal_Points/README.md), including separate amplitude folders.

BG/BE/FG/FE/HG/HE/GG/GE at `[10;10;20;20;1;1;0;0;2;.5]`, and the requested P2 B2/F2/G2 network, remain unresolved. The [closed experiment casebook](Docs_v3/Closed_Experiment_Casebook_v3.md) records the attempted methods and failures. [Legacy seed collections](P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Legacy_Seed_Recovery/README.md) remain available as explicitly unaccepted initial guesses.

The disposable `Research_v3` run trees have been removed. Final proof files, matrices and historical reports are preserved in [selected scientific evidence](Audits_v3/Scientific_Evidence/README.md), with original paths and SHA256 identities. The [cleanup audit](Audits_v3/Working_Path_Cleanup_v3.md) records what was removed and verified. No bulk archive of the discarded run workspace is retained.

## Model and numerical conventions

The [coordinate contract](Docs_v3/State_Parameter_Event_Conventions_v3.md) defines the 14 states, four contact modes and ten parameters. [Equations of motion](Docs_v3/Quadruped_EOM_v3.md) and [contact policies](Docs_v3/V2_and_V3_Contact_Policies_v3.md) explain the physical model. v3 detects the earliest enabled directional contact event; scheduled v2 contact sequences are not native-v3 acceptance evidence.

The [section and cycle definition](Docs_v3/Poincare_and_Cycle_Definition_v3.md) separates the downward apex section from full-cycle completion. See the [periodic solver](Docs_v3/Periodic_Solution_Solver_v3.md), [gait classification](Docs_v3/Gait_Classification_and_BL_Section_v3.md), [stability/bifurcation analysis](Docs_v3/Stability_and_Bifurcation_v3.md), and [mathematical theory](Docs_v3/Periodic_Orbit_and_Bifurcation_Theory_v3.md).

`V3AddPaths_v3` adds only the live core modules. `V3Path_v3` resolves retained historical aliases. `V3ReadDatasetPath_v3` still resolves all 27 indexed historical raw datasets with exact SHA256 validation; these remain study audit results. The GUI uses the named datasets directly.
