# Saved generic principal points

Open `SLIP_Quadruped_GUI_v3`, click **Select Folder**, and select:

`/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped_v3/P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Strict_Contact_Results/Validated_Generic_Principal_Points`

This folder lists the F, G and H MAT files directly. For the four additional points below, select the corresponding subfolder. Plot a dataset, select its sole point, then inspect or animate the saved trajectory.

| Dataset | Actual class | Additional recorded coordinate |
| --- | --- | --- |
| [C1_F_10_20_2.mat](C1_F_10_20_2.mat) | F (`HB_front`) | See [F/G/H evidence](README_FG_v3.md) |
| [C1_G_10_20_2.mat](C1_G_10_20_2.mat) | G (`GP`) | See [F/G/H evidence](README_FG_v3.md) |
| [C1_H_10_20_2.mat](C1_H_10_20_2.mat) | H (`HB_hind`) | Original session 99497 |
| [H_Amplitude_005/C1_H_10_20_2.mat](H_Amplitude_005/C1_H_10_20_2.mat) | H (`HB_hind`) | Native hind amplitude 0.005 |
| [H_Amplitude_02/C1_H_10_20_2.mat](H_Amplitude_02/C1_H_10_20_2.mat) | H (`HB_hind`) | Native hind amplitude approximately 0.02 |
| [H_Body_Omega_001/C1_H_10_20_2.mat](H_Body_Omega_001/C1_H_10_20_2.mat) | H (`HB_hind`) | Body pitch rate 0.009999999999863661 |
| [B_Amplitude_06505/C1_B_10_20_2.mat](B_Amplitude_06505/C1_B_10_20_2.mat) | B (`BD`) | Native B amplitude 0.6505000000000001 |

All seven have literal principal parameters `[10,10,20,20,1,1,0,0,2,0.5]`: common linear stiffness 10, common torsional stiffness 20 and pitch inertia 2. Their original nine admission gates and both independent fine replays passed. Their measured suspension geometry is mixed, so none qualifies as a requested gathered/extended gait branch. These are unordered diagnostic single points; C1 establishes no family connection, critical point, bifurcation attachment or ancestry. Imported `accepted=false` requires fresh replay/qualification for later numerical operations.

The parent-folder H file preserves the original primary `HybridOrbit_v3` and `Trajectory_v3` from native session 99497. Its full 13-component closure was 2.63199045891227e-11. Its three stored flight spreads are `[0.013126459934961088,-0.01631693025452363,0.013100647593792814]`, so its actual classification is H (`HB_hind`), unqualified as HG or HE. Native folder/list/load/color/frame checks used the saved trajectory with zero new RHS, energy, integration, map, optimization, classification or admission calls.

Selected original admission/service records, both independent fine replays and final GUI export audits are retained in the [scientific evidence manifest](../../../../Audits_v3/Scientific_Evidence/manifest.json). Its `original_path`, `archive`, `member` and SHA256 fields locate the exact evidence bytes. Preparation/probe intermediates and campaign scripts were removed; a complete numerical rerun workspace is not retained.

Parent-folder H export receipt SHA256: `3f6d647158b90166e9a312c444c46bfa05e79cb204cc4726f2da1606b29386d7`.
Original H native completion SHA256: `1c69fe360e5007d36bd465270289b539eef437ccba508608076b3dd21e5a539b`.
Parent-folder H dataset SHA256: `935f042628d7d38a3e719f51d637822d9d5f9fe399feac192504757c8da6deae`.
