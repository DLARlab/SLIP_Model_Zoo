# Six validated lower-stiffness points

Open `SLIP_Quadruped_GUI_v3`, click **Select Folder**, and select:

`/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped_v3/P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Strict_Contact_Results/Validated_Intermediate_Points`

Choose a MAT file, plot it, select its sole point, then open Visualization to inspect or animate its saved trajectory. Each dataset contains one independently validated point. Common linear stiffness is 10, pitch inertia is 2, and the literal parameter vector is `[10;10;ks;ks;1;1;0;0;2;.5]`.

| Actual gait | Dataset | Common torsional stiffness ks |
| --- | --- | --- |
| BG | [C1_BG_10_18.70361328125_2.mat](C1_BG_10_18.70361328125_2.mat) | 18.70361328125 |
| BE | [C1_BE_10_18.642058372497559_2.mat](C1_BE_10_18.642058372497559_2.mat) | 18.642058372497559 |
| FG | [C1_FG_10_18.59375_2.mat](C1_FG_10_18.59375_2.mat) | 18.59375 |
| FE | [C1_FE_10_17.5_2.mat](C1_FE_10_17.5_2.mat) | 17.5 |
| HG | [C1_HG_10_17.5_2.mat](C1_HG_10_17.5_2.mat) | 17.5 |
| HE | [C1_HE_10_18.59375_2.mat](C1_HE_10_18.59375_2.mat) | 18.59375 |

Each file preserves the original primary orbit and full trajectory, measured classification, all nine original admission gates, primitive one-flight identity and both independent plain fine replays. Native GUI checks passed folder discovery, single-point loading, exact saved orbit/trajectory and classification values, class color and saved-trajectory animation, with no connecting curves. Packaging performed zero new RHS, energy, ODE, map, derivative, optimizer or admission calls.

These are unordered diagnostic points below principal torsional stiffness 20. They establish no complete branch, bifurcation attachment, family connection or ancestry. C1 is an organizational convention. Imported `accepted=false` requires fresh qualification for later numerical operations while retaining the original historical admission evidence. GG and GE have no qualified dataset here.

Selected original admission/service records, both independent fine replays and final GUI export audits are retained in the [scientific evidence manifest](../../../../Audits_v3/Scientific_Evidence/manifest.json). Its `original_path`, `archive`, `member` and SHA256 fields locate the exact evidence bytes. Preparation/probe intermediates and campaign scripts were removed; a complete numerical rerun workspace is not retained.

The archived final checkpoint recorded 111 qualifying admission records and zero requested principal-parameter gaits; this is a historical record count, not 111 distinct branches. Full direct proof bundles remain for the thirteen published diagnostic points. The checkpoint's saved-state energy/RHS evaluations are separate from the zero-physics export.

Final checkpoint receipt SHA256: `fe8fc32ddbd87ac3a9d73a221c92dcc3b8ac5b8f6048f233dfaf924c0e41d6de`.
Final export receipt SHA256: `66444073f8a71c9e9dc2be6c5f61d302918674c503686e13a6f576b874f427b2`.
