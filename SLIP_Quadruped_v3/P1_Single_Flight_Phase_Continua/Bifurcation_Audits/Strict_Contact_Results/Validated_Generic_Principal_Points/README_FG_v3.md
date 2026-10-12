# Three saved generic principal F/G/H points

In `SLIP_Quadruped_GUI_v3`, click **Select Folder** and select:

`/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped_v3/P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Strict_Contact_Results/Validated_Generic_Principal_Points`

Each file contains one validated saved point and its original native trajectory. Plot the dataset and select its sole point to inspect or animate it.

| Dataset | Actual stored class | Full 13-component closure |
| --- | --- | --- |
| [C1_F_10_20_2.mat](C1_F_10_20_2.mat) | F (`HB_front`) | 3.0164142017508055e-11 |
| [C1_G_10_20_2.mat](C1_G_10_20_2.mat) | G (`GP`) | 2.7611303000940612e-11 |
| [C1_H_10_20_2.mat](C1_H_10_20_2.mat) | H (`HB_hind`) | 2.63199045891227e-11 |

All three use literal principal parameters `[10,10,20,20,1,1,0,0,2,0.5]`: linear stiffness 10, torsional stiffness 20 and pitch inertia 2. Their original nine admission gates and both independent fine replays passed. Suspension geometry is mixed; these points establish no FG, FE, HG, HE, GG or GE branch, ordered connecting curve, critical attachment or ancestry. C1 is an organizational convention. Imported `accepted=false` requires fresh qualification before later numerical operations.

The native F/G GUI checks passed loading, current-point selection, colors and saved animation frames with zero new RHS, energy, ODE, map, optimizer or admission calls. The existing H MAT file was preserved during those exports. The three datasets remain separate from the six lower-stiffness named gait points.

Selected original admission/service records, both independent fine replays and final GUI export audits are retained in the [scientific evidence manifest](../../../../Audits_v3/Scientific_Evidence/manifest.json). Its `original_path`, `archive`, `member` and SHA256 fields locate the exact evidence bytes. Preparation/probe intermediates and campaign scripts were removed; a complete numerical rerun workspace is not retained.

The combined F/G final audit is in `generic_principal_G_GUI_export_20261011T041404936`; F has no separate final `audit.mat` sibling. F/G export receipt SHA256: `4a94173feaa237c1cc9349c409dc5fc8c6ac9318bb6c1fd2067b124afd7f0a89`. H export receipt SHA256: `3f6d647158b90166e9a312c444c46bfa05e79cb204cc4726f2da1606b29386d7`.

Dataset SHA256 values:

- F: `60e7987eba4514dc57c9d79812af4f7ddb599171c509ca4f166c78ac31336f27`.
- G: `d4d37aa3db32c34298b8e6db13a756e46fba3f6995087f185434545f15e785bb`.
- H: `935f042628d7d38a3e719f51d637822d9d5f9fe399feac192504757c8da6deae`.

[All seven generic points](README.md) include additional H/B subfolders.
