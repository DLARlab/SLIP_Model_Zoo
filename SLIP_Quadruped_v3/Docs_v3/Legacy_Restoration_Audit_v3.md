# Legacy restoration audit

The latest pre-v3 repository change unintentionally removed
`SLIP_Quadruped/3_Numerical_Continuation/2_FloquetAnalysis/`. The directory
was restored verbatim from the immediate parent commit (`HEAD^`). No restored
file was converted, renamed, or edited.

Verification performed on 2026-08-05:

- files in the parent tree: 70;
- files in the restored directory: 70;
- parent-versus-working-tree Git blob hash mismatches: 0;
- other tracked v1/v2 source modifications: 0.

The pre-existing untracked sibling directory
`2_Floquet_Analysis_v2/` is separate and was left untouched.

## Restored files

All paths below are relative to
`SLIP_Quadruped/3_Numerical_Continuation/2_FloquetAnalysis/`.

```text
1e-12/BD1_20_2_BE_1e-12.mat
1e-12/BD1_20_2_BE_1e-12_sorted.mat
1e-12/BD1_20_2_BG_1e-12.mat
1e-12/BD1_20_2_BG_1e-12_sorted.mat
1e-12/BD1_20_2_FG_1e-12.mat
1e-12/BD1_20_2_FG_1e-12_sorted.mat
1e-12/BD1_20_2_HE_1e-12.mat
1e-12/BD1_20_2_HE_1e-12_sorted.mat
1e-12/BD1_20_2_PK_1e-12.mat
1e-12/BD1_20_2_PK_1e-12_sorted.mat
1e-6/BD1_20_2_BE.mat_1e-06.mat
1e-6/BD1_20_2_BE.mat_1e-06_sorted.mat
1e-6/BD1_20_2_BG.mat_1e-06.mat
1e-6/BD1_20_2_BG.mat_1e-06_sorted.mat
1e-6/BD1_20_2_FG_1e-06.mat
1e-6/BD1_20_2_FG_1e-06_sorted.mat
1e-6/BD1_20_2_HE_1e-06.mat
1e-6/BD1_20_2_HE_1e-06_sorted.mat
1e-6/BD1_20_2_PK_1e-06.mat
1e-6/BD1_20_2_PK_1e-06_sorted.mat
1e-7/BD1_20_2_BE_1e-07.mat
1e-7/BD1_20_2_BE_1e-07_sorted.mat
1e-7/BD1_20_2_BG_1e-07.mat
1e-7/BD1_20_2_BG_1e-07_sorted.mat
1e-7/BD1_20_2_FG_1e-07.mat
1e-7/BD1_20_2_FG_1e-07_sorted.mat
1e-7/BD1_20_2_HE_1e-07.mat
1e-7/BD1_20_2_HE_1e-07_sorted.mat
1e-7/BD1_20_2_PK_1e-07.mat
1e-7/BD1_20_2_PK_1e-07_sorted.mat
1e-9/BD1_20_2_BE.mat_1e-09.mat
1e-9/BD1_20_2_BE.mat_1e-09_sorted.mat
1e-9/BD1_20_2_BG.mat_1e-09.mat
1e-9/BD1_20_2_BG.mat_1e-09_sorted.mat
1e-9/BD1_20_2_FG_1e-09.mat
1e-9/BD1_20_2_FG_1e-09_sorted.mat
1e-9/BD1_20_2_HE_1e-09.mat
1e-9/BD1_20_2_HE_1e-09_sorted.mat
1e-9/BD1_20_2_PK_1e-09.mat
1e-9/BD1_20_2_PK_1e-09_sorted.mat
BD1_20_2_BD.mat
BD1_20_2_BE.mat
BD1_20_2_BG.mat
BD1_20_2_FG.mat
BD1_20_2_HE.mat
BD1_20_2_PK.mat
Constraint_Test/BD1_20_2_BD_1e-06_BLBR.mat
Constraint_Test/BD1_20_2_BD_1e-06_BLBR_sorted.mat
Constraint_Test/BD1_20_2_BD_1e-06_FLFR.mat
Constraint_Test/BD1_20_2_PK_1e-06_BLBR.mat
Constraint_Test/BD1_20_2_PK_1e-06_FLFR.mat
Constraint_Test/BD1_20_2_PK_1e-06_FLFRBLBR.mat
Constraint_Test/BD1_20_2_PK_1e-06_FLFRBLBR_sorted.mat
EigenValuePlot_GUI.m
FDM_v2.m
Legacy/EV_PK_20_2.5_v2.5_1e-03.mat
Legacy/EV_PK_20_2.5_v2.5_1e-04.mat
Legacy/EV_PK_20_2.5_v2.5_1e-05.mat
Legacy/EV_PK_20_2.5_v2_1e-03.mat
Legacy/EV_PK_20_2.5_v2_1e-06.mat
Legacy/EV_PK_20_2.5_v2_1e-09.mat
Legacy/EV_PK_20_2.5_v3_1e-03.mat
Legacy/EV_PK_20_2.5_v3_1e-04.mat
Legacy/EV_PK_20_2.5_v3_1e-05.mat
Legacy/EV_PK_20_2.5_v4_1e-02_1e-05.mat
Legacy/EV_PK_20_2.5_v4_1e-02_1e-06.mat
Legacy/EV_PK_20_2.5_v4_1e-03_1e-05.mat
Legacy/FDM.m
Quadrupedal_ZeroFun_v2_FDM.m
log.text
```
