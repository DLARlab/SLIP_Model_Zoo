# Quantitative section and event-phase audit

> Results-only layout. Numerical conclusions and evidence are retained. Historical filenames and run instructions refer to the [original numerical workspace](../../../P2_Numerical_Run_Archive/P2_original_layout_20261007.tar.gz). Use the [result path map](../Provenance/result_path_map.json) and [branch tree index](../../README.md) for current locations.


The stored G and E B2 arrays are descriptions of the same labeled full cycles at two different apex phases. Mapping both to the gauge `t_BL_TD/T = 0.25` removes this phase multiplicity in all **1358** paired attempts: the largest difference in the 13 state variables is **3.063e-10**, and the largest circular event-schedule difference is **1.256e-15**. No horizontal reflection or leg permutation is applied.

## Data and scope

The active `B2_10_20_2_G.mat` contains 1,358 columns. The active `B2_10_20_2_E.mat` contains 1,307 accepted other-apex records plus all 1,358 attempted rephasings. Its hash matches the earlier artifact named `B2_10_20_2_OtherApex.mat`; the current name is respected. The E artifact records 55 fixed-period corrections of the source G data, with maximum correction 1.240e-05. Comparisons use `allSourceResultsUsed`, preserve these corrections explicitly, and verify that `allSourceOriginalResults` exactly equals the active G matrix. There is no hidden correction of the other-apex representation.

The event schedules of B2 (1,358), BS (213), PK_B2_Parent (259), PIP (228), and BIP (904) were inspected in full. Every column has exactly one labeled TD and one labeled LO per leg **by construction of the stored shooting schema**. This is not a proof that a geometric foot-height guard has only one zero during a cycle. Native replay covers all these columns except the 36 PK outer columns already marked outside the validated angular chart (native PK columns 19–241 are replayed).

## Why a physical first-touchdown section is not a drop-in replacement

For hind-left leg angle `a_BL`, body pitch `phi`, body height `y`, resting length `l`, and hind COM offset `lb`, the scheduled touchdown guard is

`g = y - lb*sin(phi) - l*cos(phi + a_BL)`.

The pre-event derivative is

`g_dot = dy - lb*cos(phi)*dphi + l*sin(phi+a_BL)*(dphi+da_BL)`.

The scan evaluates this derivative on the pre-reset event state. It also checks interior sign changes of `g` inside every existing integration segment; those counts are detected crossings, not a rigorous count of tangencies or unresolved roots. Scheduled event roots within `1e-7*T` are excluded from the interior count.

| Family | Native columns replayed / stored | TD derivative positive >1e-8 | Initial dy=0 is a minimum (ddy>1e-8) | Columns with extra swing guard crossings | Columns with GRF_y < -1e-8 |
|---|---:|---:|---:|---:|---:|
| B2 | 1358/1358 | 164 | 0 | 1283 | 542 |
| BS | 213/213 | 0 | 202 | 154 | 144 |
| PK | 223/259 | 0 | 0 | 197 | 223 |
| PIP | 228/228 | 0 | 0 | 0 | 0 |
| BIP | 904/904 | 0 | 904 | 133 | 751 |

For B2 the scheduled TD derivative ranges from -6.55915 to 0.0896999. Enforcing a negative direction would exclude 164 currently stored mathematical solutions. There are four sign-change brackets, recorded in `transversality_summary.json`. Because the current model advances an explicitly chosen contact itinerary, replacing it by the first state-triggered guard crossing would change the model and its branches. This particularly affects the already permitted negative-GRF regime and delayed-liftoff branches.

At BS column 1, the TD derivative is approximately -3.515e-10 and the minimum swing duration is 5.6003e-9. Thus an event-triggered section approaches grazing and the TD/LO pair approaches coincidence. A strict negative-direction test or finite event-separation threshold would truncate this family. There must be an explicit chart/boundary diagnosis, not silent rejection based on velocity or GRF sign.

All B2 stored initial extrema are downward apexes, so adding `ddy<0` alone does not remove the two-apex duplication. All 904 BIP stored initial extrema are upward minima. The current scalar residual `dy=0` is therefore an extremum phase condition, not consistently a downward-apex section across the data catalog.

## Timing gauge tested

Let `t_h` be the unique scheduled hind-left TD time modulo `T`. Shift the stored initial phase by

`tau = mod(t_h - eta*T, T)`, with `eta = 0.25`.

Evaluate the same hybrid trajectory at `tau`, remove the horizontal translation, and set all eight event times to `mod(t_i - tau, T)`. This makes `t_h/T=eta` while preserving the full cycle and labeled contact itinerary. The phase choice is unique modulo `T` as long as there is exactly one labeled hind-left TD per stored full cycle. If future models allow repeated TDs of the same leg, the representation needs an explicit primitive cycle and an event occurrence index; this schema-based uniqueness no longer follows automatically.

For the current B2 data the gauge is strictly inside an event interval: the smallest circular gap between the new section and any scheduled event is **0.000457908 T**. This is a measured margin for these samples, not a global guarantee along every possible continuation. A continuation can cross another event at its chosen phase and then needs consistent hybrid boundary ownership or a changed chart.

This timing gauge is a shooting phase condition, not a new state-only Poincare surface. A corresponding map or Floquet calculation must retain the complete labeled cycle definition, including event order, simultaneous batches and reset ownership.

## Exact TD boundary experiment

An independent 48-orbit sample compares both pre- and post-event TD anchors and an interior anchor `TD + 0.1*(next distinct event gap)`. Simultaneous TD events are treated as a batch and the right state is sampled after the whole batch. The maximum same-orbit difference at exact right TD across all paired B2 records is 1.532e-08; the maximum circular schedule difference is 8.308e-16.

Naively passing a post-TD state into the unchanged v2 solver at `TD=0` is not equivalent to constructing a consistently post-event return map. At current B2 column 1212 its residual excluding the old apex component is about **3.24e-6**, whereas the pre-event version is about **9.84e-12** and the strict-interior experiment about **1.59e-10**. The v2 initial trace row, event reset and final periodic closure have different boundary ownership. Interior timing phases avoid this immediate ambiguity; a true event-section implementation must explicitly apply the same boundary convention at both ends.

## Numerical acceptance is separate from phase identity

Although all 1,358 pairs agree after the eta=0.25 transformation to 3.063e-10, direct uncorrected native replay of the transformed source passes a 1e-8 residual threshold for only **1254/1358** records. The residual here contains the eight native physical guard equations and thirteen periodicity equations; **old apex residual component 9 is deliberately excluded**, because the new phase need not have dy=0. The new timing equation is checked separately by construction.

The maximum transformed replay residual is **7.277e-07**; among the 1,307 previously accepted E records it is **2.270e-08**, with 83 records above 1e-8. Phase transport changes numerical conditioning, especially near the compressed-leg ends. These records must be corrected and revalidated in the new phase before they are used as replacement solution data. This experiment makes no such replacement and does not delete failures.

