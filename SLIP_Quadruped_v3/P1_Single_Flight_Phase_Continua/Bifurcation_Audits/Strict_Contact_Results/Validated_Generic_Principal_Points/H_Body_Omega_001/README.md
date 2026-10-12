# Generic H point at body pitch rate approximately 0.01

In `SLIP_Quadruped_GUI_v3`, click **Select Folder** and select:

`/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped_v3/P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Strict_Contact_Results/Validated_Generic_Principal_Points/H_Body_Omega_001`

Choose [C1_H_10_20_2.mat](C1_H_10_20_2.mat), plot it and select its sole point to inspect or animate the saved trajectory. Native process 67952 admitted this principal-parameter cycle at `[10;10;20;20;1;1;0;0;2;.5]`: linear stiffness 10, torsional stiffness 20 and pitch inertia 2.

Native hind amplitude is 0.3608992497064219 and body pitch rate is 0.009999999999863661. The three flight spreads are `[+0.3940414512552538,−0.5325287211036337,+0.3512567602497567]`. Actual class is mixed H (`HB_hind`), unqualified as HG or HE. Original BL1 admission passed all nine gates and both independent plain fine replays, with primitive cover 1 and one flight.

The saved-only GUI export preserves the admitted orbit/trajectory exactly. Native folder discovery, current-solution selection, classification/color and animation-frame preparation passed with no new dynamics, integration, correction, classification or admission calls. This is an unordered diagnostic single point with imported `accepted=false`, requiring fresh qualification for further numerical operations. C1 supplies no branch, bifurcation attachment or ancestry.

Selected original admission/service records, both independent fine replays and final GUI export audits are retained in the [scientific evidence manifest](../../../../../Audits_v3/Scientific_Evidence/manifest.json). Its `original_path`, `archive`, `member` and SHA256 fields locate the exact evidence bytes. Preparation/probe intermediates and campaign scripts were removed; a complete numerical rerun workspace is not retained.

Original admission is indexed under `Projected_Warm_H_FirstReturn_correction_20261011T085906031/native_acquisition/native_admission`; its evidence is the separately admitted original BL1 cycle. The final GUI export is `admitted_warm_principal_H_GUI_export_20261011T100611339`, actual exit 0/chunk `55e1de`. An auxiliary saved-only interpretation receipt was omitted during cleanup; the original admission and fine replay proof bundles remain.

Original native admission receipt SHA256: `301c73f755421fd956eea1568308769568fa5c85ce43c5d926f3c463c3ce8d7c`.
Final GUI export/audit receipt SHA256: `5ca0d62374a82a44e79b5c4c5c871f3147303a1cbaf1e3288ed30431ef7f670c`.
Dataset SHA256: `b3d9074591c65cb83a0e15adac91b47d0be29f873d6627c6fb4c2d1a2702d12d`.
