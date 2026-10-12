# Single-flight phase continua

Open `SLIP_Quadruped_GUI_v3`, click **Select Folder**, and select this folder. The dataset dropdown lists the direct MAT files automatically. Use **Plot** for the selected dataset or **Plot All** for the folder. Click a plotted point or branch line to select its stored solution; open Visualization to inspect the saved trajectory. A fresh replay/correction is required before treating an imported record as newly validated.

| Dataset | Stored records | Components | Scope |
|---|---:|---:|---|
| [C1_PK_10_20_2.mat](C1_PK_10_20_2.mat) | 177 | 39 | Accepted PK source groups and ordered continuation components. |
| [C1_USBL1_10_20_2.mat](C1_USBL1_10_20_2.mat) | 1 | 1 | One unclassified standing BL1 sample; no named gait claim. |
| [C1_PIP_10_20_2.mat](C1_PIP_10_20_2.mat) | 18 | 6 | One-flight PIP parent samples. |

Counts come from the [current catalog](Branch_Catalog_v3.json). They count stored records, including repeated seeds/source records, rather than distinct cycles or gait families. Ordered components and source groups remain separate inside each file; sharing a file or continuum prefix establishes no attachment.

The required naming is `C1_<gait>_<linear stiffness>_<torsional stiffness>_<pitching inertia>.mat`. Every dataset in this study uses C1. Validated low/high F2 branches additionally use `_L`/`_H` after the parameters.

The requested network is **PIP → PK → BG/BE → FG/FE/HG/HE → GG/GE**. **BG, BE, FG, FE, HG, HE, GG and GE are not currently published as admitted native branches.** Their absence is a numerical research gap, rather than a folder-catalog visibility issue. Failed corrections and unclassified motions are retained under their actual status and are not renamed as these targets. See the [four-tranche scientific status](../Audits_v3/Scientific_Evidence/README.md) and the current [GUI and branch follow-up](../Docs_v3/GUI_Defaults_and_Strict_P1_Recovery_v3.md).

Final publication records, numerical matrices, figures and indexed historical raw results remain under [Bifurcation_Audits](Bifurcation_Audits/). The [current catalog](Branch_Catalog_v3.json) retains the original dataset hashes and source identities. Disposable acquisition attempts, launchers, caches and repeated source snapshots have been removed. Selected final mathematical and admission evidence is indexed in [Scientific_Evidence](../Audits_v3/Scientific_Evidence/README.md).

The strict-contact search additionally retained [six lower-stiffness points](Bifurcation_Audits/Strict_Contact_Results/Validated_Intermediate_Points/README.md) and [seven generic principal diagnostic points](Bifurcation_Audits/Strict_Contact_Results/Validated_Generic_Principal_Points/README.md). Select those folders directly in the GUI. They remain unordered diagnostic points, without new branch/ancestry claims. The [final search audit](../Docs_v3/Strict_P1_30h_Search_Audit_20261010_v3.md) explains their parameter and validation scope.

[Legacy_Seed_Recovery](Bifurcation_Audits/Legacy_Seed_Recovery/README.md) preserves the eight source branches and native-coordinate initial guesses. They remain explicitly unaccepted under strict-v3 contact rules.
