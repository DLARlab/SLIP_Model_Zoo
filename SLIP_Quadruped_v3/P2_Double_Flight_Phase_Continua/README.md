# Double-flight phase continua

Open `SLIP_Quadruped_GUI_v3`, click **Select Folder**, and select this folder. The dataset dropdown lists the direct MAT files automatically. Use **Plot** for the selected dataset or **Plot All** for the folder. Click a plotted point or branch line to select its stored solution; open Visualization to inspect the saved trajectory. A fresh replay/correction is required before treating an imported record as newly validated.

| Dataset | Stored records | Components | Scope |
|---|---:|---:|---|
| [C2_OSBL2_10_20_2.mat](C2_OSBL2_10_20_2.mat) | 29 | 8 | Opposed standing BL2 components and samples; no B2 claim. |
| [C2_UBL2_10_20_2.mat](C2_UBL2_10_20_2.mat) | 3 | 3 | Unclassified standing BL2 samples; no B2 claim. |
| [C2_PIP_10_20_2.mat](C2_PIP_10_20_2.mat) | 18 | 6 | Exact C1 PIP copy for the shared parent reference; it remains one-flight. |

Counts come from the [current catalog](Branch_Catalog_v3.json). They count stored records, including repeated seeds/source records, rather than distinct cycles or gait families. Ordered components and source groups remain separate inside each file; sharing a file or continuum prefix establishes no attachment.

The required naming is `C2_<gait>_<linear stiffness>_<torsional stiffness>_<pitching inertia>.mat`. Every dataset in this study uses C2. Validated low/high F2 branches additionally use `_L`/`_H` after the parameters.

The requested network is **PIP → B2 → F2_L/F2_H → G2 through F2**. **B2, F2_L, F2_H and G2 are not currently published as admitted native branches.** Their absence is a numerical research gap, rather than a folder-catalog visibility issue. Failed corrections and unclassified motions are retained under their actual status and are not renamed as these targets. See the [four-tranche scientific status](../Audits_v3/Scientific_Evidence/README.md) and the current [GUI and branch follow-up](../Docs_v3/GUI_Defaults_and_Strict_P1_Recovery_v3.md).

Final publication records, numerical matrices, figures and indexed historical raw results remain under [Bifurcation_Audits](Bifurcation_Audits/). The [current catalog](Branch_Catalog_v3.json) retains the original dataset hashes and source identities. Disposable acquisition attempts, launchers, caches and repeated source snapshots have been removed. Selected final mathematical and admission evidence is indexed in [Scientific_Evidence](../Audits_v3/Scientific_Evidence/README.md).
