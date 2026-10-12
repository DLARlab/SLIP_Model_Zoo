# Legacy P1 seed recovery and model compatibility

> Cleanup note (2026-10-11): this report preserves its historical scientific scope. Selected final evidence is indexed in [Scientific_Evidence](../Audits_v3/Scientific_Evidence/README.md). Per-probe intermediates and campaign scripts were removed; historical claims do not imply a retained complete rerun workspace. The unchanged original report is also in the evidence bundles.


The complete v2 BG, BE, FG, FE, HG, HE, GG and GE source branches have been copied and losslessly converted to v3 state, parameter, mode and named-event conventions. They are recovery inputs, not newly admitted autonomous branches. The authoritative numerical work below is native MATLAB R2025b; an initial noncompliant saved-data diagnostic was superseded as described below. The protected legacy source/data files and the four exhausted research masters retain their recorded hashes. The final filesystem audit separately records two Finder metadata differences.

This follow-up is explicitly source-informed. The user authorized using the previously held-out daughter datasets as seeds; their use here does not retroactively change the information barrier or discovery claims of the frozen v2 Floquet experiments.

## Complete copies and conversion

The authoritative inputs come from the protected local `SLIP_Quadruped/3_Numerical_Continuation/2_Floquet_Analysis_v2/reference_experiments` packages. All eight byte identities match previously preserved legacy fixtures, so this is a new adaptation/validation method rather than new source content. Source inventory and known tree (historical intermediate removed).

| Gait hypothesis | Complete columns | Initially eligible native flight/apex columns | Converted seed file |
|---|---:|---:|---|
| BG | 474 | 330 | [C1_BG_10_20_2.mat](../P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Legacy_Seed_Recovery/Converted_Seeds/20261009T105131428/C1_BG_10_20_2.mat) |
| BE | 443 | 265 | [C1_BE_10_20_2.mat](../P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Legacy_Seed_Recovery/Converted_Seeds/20261009T105131428/C1_BE_10_20_2.mat) |
| FG | 212 | 51 | [C1_FG_10_20_2.mat](../P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Legacy_Seed_Recovery/Converted_Seeds/20261009T105131428/C1_FG_10_20_2.mat) |
| FE | 228 | 21 | [C1_FE_10_20_2.mat](../P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Legacy_Seed_Recovery/Converted_Seeds/20261009T105131428/C1_FE_10_20_2.mat) |
| HG | 538 | 50 | [C1_HG_10_20_2.mat](../P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Legacy_Seed_Recovery/Converted_Seeds/20261009T105131428/C1_HG_10_20_2.mat) |
| HE | 180 | 26 | [C1_HE_10_20_2.mat](../P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Legacy_Seed_Recovery/Converted_Seeds/20261009T105131428/C1_HE_10_20_2.mat) |
| GG | 277 | 40 | [C1_GG_10_20_2.mat](../P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Legacy_Seed_Recovery/Converted_Seeds/20261009T105131428/C1_GG_10_20_2.mat) |
| GE | 200 | 31 | [C1_GE_10_20_2.mat](../P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Legacy_Seed_Recovery/Converted_Seeds/20261009T105131428/C1_GE_10_20_2.mat) |

The 2,552 columns retain literal 29-row originals, source commit/path/hash/variable/column, modulo-period schedules, explicit old/new event-name orders, and separate converted state/mode/parameter arrays. No source height, velocity, angle, rate, mode or phase is silently changed. The native filenames identify source gait hypotheses, not classifications proved by those names. Initial eligibility tests geometry, stance-rate constraints, downward-apex acceleration and baseline parameters; it is not periodic admission. All current source modes are flight; no modulo regulation changes their initial modes.

[Conversion manifest](../P1_Single_Flight_Phase_Continua/Bifurcation_Audits/Legacy_Seed_Recovery/Converted_Seeds/20261009T105131428/conversion_manifest.json): native process **25909, exit 0**. The independent literal-permutation/direct-parameter audit **58243, exit 0** checked every column against the protected source and copied fixture, including event timetables and all no-projection/no-retraction labels. Independent preservation evidence (historical intermediate removed).

GG column 277 and GE column 1 are identical in all 29 raw entries; their two filenames do not establish two different cycles. Alternate columns are included in the native validation. Exact source-pair evidence (historical intermediate removed).

## What is shared, and what differs

Under the explicit `v2-exact` parameter adapter, the continuous force/torque/swing equations and leg-rate resets agree algebraically. The model difference is contact execution and admissibility: v2 integrates prescribed touchdown/liftoff intervals and solves surface/periodicity equations; principal v3 uses first directed roots, compressive stance, swing clearance, a downward leg-orientation domain and the BL-marked downward-apex chart. The maintained v2 Floquet map does check the downward apex and timetable topology; those checks are not the same as continuous unilateral validity or first-contact eligibility. Source-bound model contract (historical intermediate removed).

## Native source validation

The first new native experiment selected two algebraically eligible columns per gait: an eligible interval endpoint and the largest ranked initial clearance. Every exact input and all 47 bound numerical source hashes are retained. The original shared periodic solver, full thirteen-coordinate closure and nine admission gates remain in force. No source event schedule is imposed.

Native process **13019, exit 0** completed all 16 tasks in 18.2274 seconds. Each failed with `ContinuousDynamics_v3:TensileStance` during initial autonomous evaluation, before an initial residual or nonlinear correction could be established. These are failed initialization attempts, not sixteen optimizer convergence results. Failed maps have no invented residual. [Registration, exact inputs and per-case results (archived evidence)](../Audits_v3/Scientific_Evidence/README.md).

| Family | Source columns | Reported tensile legs |
|---|---|---|
| BG | 12, 204 | FL, FR |
| BE | 12, 147 | BL, BR |
| FG | 162, 212 | FL |
| FE | 208, 228 | BL, BR |
| HG | 50, 1 | FL, FR |
| HE | 155, 180 | BR |
| GG | 238, 277 | BL |
| GE | 31, 1 | FR for 31; BL for 1 |

The subsequent [all-eligible-column autonomous screen (archived evidence)](../Audits_v3/Scientific_Evidence/README.md) completed **814 / 814** source columns in native process **32990, exit 0**, taking 137.8178 seconds. Every exact seed failed with the original `ContinuousDynamics_v3:TensileStance` identifier before a valid map return. No per-map or total budget limit was reached. All 47 existing numerical sources, the audit driver/recorder, source registry and eight protected originals/copied fixtures retained their registered hashes. Every column has exact input and original partial simulator/exception evidence; no failed map was assigned a residual. There were no root solves, Floquet evaluations, admissions, canonical publications or original-master writes.

This finite census covers every initially eligible column in these eight particular source datasets. It does not prove that the native families do not exist elsewhere. It establishes that copying/reordering their saved states alone supplies no usable principal native correction seed. A root-method adjustment cannot fix a missing initial physical return; a successful strict-model recovery needs a separately recorded feasible predictor, not a different stopping tolerance.

## Full-cycle phase adaptation

An admissible saved apex is not the only possible recovery input. The phase method literally replays the legacy scheduled cycle, converts every trajectory sample and its cyclic mode, selects an admissible interior phase away from resets, preserves its nonzero vertical velocity, and integrates that exact phase autonomously to a genuinely observed descending apex. Such an apex would still require BL-marking qualification, coupled correction, fresh physical replay, primitive identity and gait classification. Rephasing cannot certify the full scheduled cycle as an autonomous orbit.

The first two BG diagnostics completed in native process **57906, exit 0**. BG column 11 closes under its stored schedule with nongauge error about 5.44e-13 and timing error about 2.55e-13, but 241 of 2,435 sampled interior points violate native geometry; minimum swing clearance is approximately -0.01675. Its exact admissible upward phase later fails native compressive stance. BG column 204 starts with valid geometry, but 2,934 of 3,567 sampled interiors are invalid and minimum swing clearance is approximately -0.28906; its native phase ingestion leaves the downward-orientation domain. These are sampled finite observations, not interval proofs or family nonexistence results.

The remaining seven scheduled replays and exact native ingestions completed in **20107, exit 0**, taking 15.6308 seconds. The largest scheduled closure error was 3.8329e-12. Every selected phase was initially valid and was copied without state retraction, vertical-velocity projection, mode rewriting or imposed native schedule. None reached a usable native downward apex. [Seven-family phase results (archived evidence)](../Audits_v3/Scientific_Evidence/README.md).

| Source | Native-invalid sampled interiors / checked interiors | Native ingestion outcome |
|---|---:|---|
| BE 147 | 2,021 / 3,415 | Leaves downward leg-orientation domain, BL/BR |
| FG 212 | 711 / 2,785 | Tensile stance, BL/BR |
| FE 228 | 515 / 2,621 | Tensile stance, FR |
| HG 1 | 594 / 2,593 | Tensile stance, BL |
| HE 180 | 636 / 2,901 | Tensile stance, FL/FR |
| GG 277 | 616 / 2,867 | Tensile stance, BR |
| GE 1 | 616 / 2,867 | Same source state as GG 277; tensile stance, BR |

The initial BG event-report helper treated nearly coincident paired events as separate scalar cohorts, producing misleading diagnostic mode-agreement flags. Its original source/results are preserved. A saved-data MATLAB cohort reaudit (historical intermediate removed) grouped events at the native 1e-9 tolerance and confirmed all four cohort modes in each cycle, with reset-state errors at most 2.66e-15. It made no new integrations or admissions. The subsequent seven-family execution used the corrected helper. This diagnostic repair does not remove the recorded trajectory inequalities or failed native ingestions.

## Located contacts and the correction obstruction

A fresh saved-data MATLAB audit **85963, exit 0** reproduces all sixteen pre-root failures and their actual touchdown evidence. In every retained trial the incoming foot guard derivative is negative, the located touchdown/reset is executed, and the newly contacting leg's post-reset stance guard derivative is positive. The following rejected accepted-segment sample has negative compression. For example, BG column 12 touches down at approximately 0.00146860875: FL/FR derivatives change from -0.74268346 to +0.76783230; the first rejected raw sample at approximately 0.00147600516 has compression -5.7756e-6. This is an observed extending stance after a located touchdown, not an observed nonlinear optimizer failure or proof that the root finder missed the contact.

The same native saved-data audit records positive-to-negative swing-foot guard brackets in BG 11 and 204 away from scheduled event boundaries, during unchanged swing mode. BG 11 has extra BL/BR brackets at approximately [1.276329543, 1.277083062] and FL/FR brackets at [1.365033135, 1.365858441]. These are sampled sign brackets rather than refined roots. Phase translation cannot remove an extra contact from the same closed scheduled trajectory. Native failure and guard evidence (historical intermediate removed).

*Historical diagnostic image removed during cleanup.*

The lower panel isolates the final all-flight interval: the negative guards there are swing-foot penetration. A negative rest-length guard during **stance** elsewhere in the upper panel is normal spring compression and is not itself a swing violation. The standalone PDF figure (historical intermediate removed) retains export quality.

An initial saved-data Python/SciPy diagnostic violated the requested MATLAB-only numerical workflow. It is explicitly superseded and preserved as provenance; its public helper is archived as `.py.txt`. The fresh native audit reproduces the reported witnesses from the original inputs with zero new RHS evaluations, maps, integrations or solves. The source conversion, independent preservation audit, scheduled replays and native integrations were already MATLAB executions.

## Final preservation and working-path check

The strict working-path audit (historical intermediate removed) checked 37,852 files outside Git metadata after all numerical writers stopped. No file was at or above 100,000,000 bytes; the largest remained 88,398,547 bytes. There were no modifiable cache candidates or new files outside v3. The six canonical dataset hashes and four frozen research master hashes all match their recorded values.

The strict byte-for-byte preservation predicate is **false**, not relabeled as a pass: 532 of 534 protected file hashes match, while `SLIP_Quadruped/.DS_Store` and `SLIP_Quadruped/3_Numerical_Continuation/.DS_Store` differ from the earlier baseline. Both are Finder metadata; all protected source/data files match. The cause of these metadata changes was not established, and neither file was restored, deleted or written by the audit. The separate interpretation (historical intermediate removed) retains this distinction and leaves the original strict audit untouched. No preservation assertion or scientific threshold was weakened.

No physical-rule change or v2-compatible GUI replay is assumed without resolving the model choice presented to the user. The original strict principal model remains the target in the absence of a revised model instruction; no source schedule or invalid state has been admitted under its name. The eight converted collections remain explicitly unaccepted seeds in the independent study audit folder. They establish full data preservation and a reproducible recovery starting point, not a native branch or bifurcation certificate.
