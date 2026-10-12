# GUI defaults and strict P1 recovery follow-up

> Cleanup note (2026-10-11): this report preserves its historical scientific scope. Selected final evidence is indexed in [Scientific_Evidence](../Audits_v3/Scientific_Evidence/README.md). Per-probe intermediates and campaign scripts were removed; historical claims do not imply a retained complete rerun workspace. The unchanged original report is also in the evidence bundles.


The GUI default-setting defects are repaired. The scientific follow-up uses the user's final choice of strict autonomous v3 contact rules. It produced six freshly admitted PK samples in research epochs and no admitted BG/BE/FG/FE/HG/HE/GG/GE daughter. The requested full P1 network remains unresolved; no compatibility branch was published.

## GUI behavior

`SLIP_Quadruped_GUI_v3` and `BuildQuadrupedGUILayout_v3` now preserve the measured v2 defaults:

- Box off and X/Y/Z grids off, including after plotting.
- Automatic initial limits and tick-aligned limit calculation.
- The independent manual X/Y/Z limits remain set when an axis-variable selection changes, matching v2.
- Plotting flushes pending graphics updates before synchronizing the six limit input boxes. Previously, reading the unrendered axes prematurely fixed limits at `[0,1]` and clipped the first branch plot.
- **Select Folder** immediately restores the GUI after the native picker returns, including cancellation and an invalid-folder error. Hidden programmatic instances stay hidden.

The native v2/v3 comparison (historical intermediate removed) checks initial state, a representative BG plotting fixture and manual-bound changes. Both implementations produce initial `[0,1]` automatic limits with box/grid off. Both produce automatic plotted bounds `X=[4,22]`, `Y=[0,0.04]`, `Z=[0,1]` for that fixture. The source fixture is used for GUI parity, not as a newly admitted strict BG branch.

The actual native picker audit (historical intermediate removed) records P1 selection listing `C1_PIP_10_20_2.mat`, `C1_PK_10_20_2.mat` and `C1_USBL1_10_20_2.mat`. After selection and cancellation, the GUI is visible and MATLAB's current figure. The invalid-folder path also restores focus, hidden instances remain hidden, and the audit leaves zero additional timers. The earlier failed picker-audit preparations are retained separately; they are not successful product checks.

The delegated native CUA observation also identified `SLIP Quadruped GUI v3` as the foreground window after selection. The GUI audit findings (historical intermediate removed) and completion receipt (historical intermediate removed) distinguish completing the interactive audit from terminating the MATLAB desktop.

The plotting comparison and native picker audit bind their exact executed source snapshots. The subsequent focus-only change does not modify the plotted-default path. Folder selection restores focus immediately after `uigetdir`, following the v2 visibility/draw/figure sequence.

## Strict contact search

The [strict recovery findings (archived evidence)](../Audits_v3/Scientific_Evidence/README.md) document the completed native corrections, coupled shooting, qualified return derivatives and failures. A reduced periodic residual is not sufficient for admission. Six additional PK samples passed independent strict replay and all nine unchanged service gates; the asymmetric nominees did not converge to an admitted daughter.

The missing legacy gaits are not hidden by the GUI. Their exact converted source cycles violate the strict autonomous contact contract. The diagnosis checks the reset kinematics and the complete scheduled cycles independently: their sampled scheduled stance intervals are compressive, while earlier virtual swing-foot crossings cause a different contact sequence under strict v3. The [contact-policy explanation](V2_and_V3_Contact_Policies_v3.md) gives the precise v2/v3 distinction and the touchdown calculation.

The equations, reset signs, physical contact gates and principal return semantics were kept unchanged. The vector-field-only evaluator now omits unrequested diagnostic-report construction. Native differential checks and all six grouped periodic-solver validation cases passed. A separately verified correction fixes swapped front/hind spectrum labels without changing any matrix or eigenvalue.

## Preservation and working path

The filesystem audit (historical intermediate removed) checked 38,311 files outside Git metadata. No file was at or above 100,000,000 bytes; the largest was 88,398,547 bytes. It found no modifiable cache candidates or new files outside v3. All six canonical datasets, four frozen masters and 30 bound scientific-core sources match their recorded hashes; `git diff --check` passed.

The protected baseline has two pre-existing Finder metadata differences: `SLIP_Quadruped/.DS_Store` and `SLIP_Quadruped/3_Numerical_Continuation/.DS_Store`. All other protected baseline files match. Those protected metadata files were retained, so this is not an exact whole-tree byte-equality certificate.

Failed nominees, source epochs, partial derivatives and actual process outcomes remain as numerical audits. The interrupted compatibility conversion is explicitly cancelled and its unused public driver removed. No tests, caches or empty gait placeholder datasets were introduced to imply recovery.
