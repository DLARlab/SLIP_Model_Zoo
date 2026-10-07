# Why the saved B2 endpoints stopped, and how to continue them

> Results-only layout. Numerical conclusions and evidence are retained. Historical filenames and run instructions refer to the [original numerical workspace](../../../../../P2_Numerical_Run_Archive/P2_original_layout_20261007.tar.gz). Use the [result path map](../../../../Audit/Provenance/result_path_map.json) and [branch tree index](../../../../README.md) for current locations.


**Both endpoints were stopped deliberately. Neither is a demonstrated model
singularity or maximum branch extent.** The frozen source MAT metadata says:

- Low end: `Crossed both initial and cycle-mean zero velocity with a negative-side margin.`
- High end: `300-second checkpoint boundary; further continuation remains possible.`
- Both recorded termination reasons: `Algorithm stopped by user.`

The input snapshot fixes source columns `[1,2,3,850,851,852]` of the 852-column
B2 file. Its SHA256 and copied runtime hashes are in `provenance.json`; later
edits to the active B2 file do not alter this audit. No continuation or edit to
the active branch/algorithm was performed here.

## Endpoint geometry and event margins

These values are from independent full native replay after exact bounding
symmetry correction at unchanged initial velocity:

| Quantity | Low endpoint, source column 1 | High endpoint, source column 852 |
|---|---:|---:|
| Initial velocity | -0.0289311926929 | 19.5160169368 |
| Mean velocity | -0.0490147963288 | 19.4965808408 |
| Initial vertical acceleration | -1.05919369116 | -1 |
| Minimum body height | 0.934881984255 | 0.295977871827 |
| Minimum stance hip height | 0.905334005193 | 0.286298704426 |
| Minimum stance leg length | 0.905971392137 | 0.286310077452 |
| Minimum absolute stance-angle cosine | 0.996448149752 | 0.295619563688 |
| Minimum distinct event gap | 0.169842988504 | 0.0984465085525 |
| All-leg flight intervals per cycle | 0 | 2 |
| Full periodic residual norm | 4.609e-13 | 3.969e-14 |

Both stored sections are genuine downward-curvature apices. Neither is near
zero apex curvature, zero stance leg length, a vanishing stance duration, or
a collision of distinct front/hind events. Simultaneous left/right paired
events are structural to B2, not a failure of the contact sequence. The low
endpoint has no all-leg flight and includes tensile force; the high endpoint
has two flights. Signed force and velocity remain allowed.

The native leg coordinate uses stance length
`(y ± .5 sin(phi))/cos(alpha+phi)`. A future small stance cosine/hip height can
therefore signal angular-chart conditioning; it must be distinguished from
actual zero leg length. These margins are comfortably nonzero at the saved
endpoints. Minima here use adaptive native trajectory samples, not a certified
continuous-time minimization.

## Exact reversible bounding chart

Use eight variables

`q=[u,y,p,a,da,td,lo,T]`

with full model vector

`x=[u,y,0,0,p,a,da,-a,da,a,da,-a,da,td,lo,T-lo,T-td,td,lo,T-lo,T-td,T]`.

This fixes bilateral leg pairing, `phi=dy=0`, opposite front/hind initial leg
angles, common initial leg rates, and the time-reversal event identities
`TD_h+LO_f=T`, `LO_h+TD_f=T`. These identities hold on the source B2 family
to numerical precision. The corrector still evaluates **all 22 native
periodic/contact residuals**; no equation is silently discarded.

At fixed source initial velocity, this chart corrects the low endpoint by
`4.678e-12` and the high endpoint by
`1.345e-05` in the full 22-vector norm. The
high source's approximately 7.4e−8 pitch-angle drift is removed. The corrected
high residual is `3.969e-14`. Exact pairing also
removes the former event-adjacent bilateral mismatch; corrected trajectory
pair differences are at roundoff, with zero measured away-event mismatch.

## Conditioning evidence

Both full22 and reduced8 Jacobians were evaluated using the same copied native
model at three normalized steps `[8e-6,4e-6,2e-6]`, with explicit state scales.
The expected continuation tangent is excluded from the nonzero-condition
estimate below:

| Quantity | Low endpoint | High endpoint |
|---|---:|---:|
| Full22 nonzero condition estimate | 5215.16 | 2.35713e+08 |
| Reduced8 nonzero condition estimate | 1248.52 | 20096 |
| Full22 next singular value | 0.0165455 | 4.43188e-07 |
| Full22 finest matrix change | 1.33336e-06 | 1.03345e-07 |
| Reduced8 smallest nonzero singular value | 0.0690684 | 0.00627663 |
| Reduced8 finest matrix change | 1.33336e-06 | 5.62689e-07 |

The high-speed full22 chart has a very weak extra direction, partly outside
the exact reversible chart (normalized outside-chart component approximately
0.1025). It can amplify small
symmetry errors. The reduced chart improves the estimated nonzero condition
number by roughly four orders of magnitude. Its smallest nonzero singular
value is well above the measured derivative change. This supports the exact
chart for following B2 efficiently.

The full22 weak singular value is only a few times the full finite-difference
change. It is **not** presented as a certified zero singular value, a new
bifurcation, or a physical endpoint. The actual branch geometry needs continued
tracking beyond these saved points.

## Seeds and continuation recommendation

`symmetry_corrected_seeds.mat` provides:

- `corrected`: 29×6, source columns `[1,2,3,850,851,852]`.
- `reducedResults`: 8×6, the chart above.
- `lowOutwardSeeds`: 29×2, source columns `[2,1]`.
- `upperOutwardSeeds`: 29×2, source columns `[851,852]`.

Use scaled pseudo-arclength with all native residuals, not velocity as a
globally monotone continuation coordinate. Fixed velocity was used here only
to correct the starting seeds. Retain signed forces/velocities and monitor
actual geometric/contact margins and periodic residuals. A phase change to
the other apex must shift the entire state and event schedule and preserve
the full contact cycle; the separate `../apex_audit/` component owns that
identity check and its alternate-apex seeds.

Legacy source contains future policy guards at **initial** `y<0.3*l` and
initial `dx>25` (the speed message incorrectly says 15). These are not
singularity tests and did not cause the recorded stops. In particular,
the saved high orbit already has trajectory minimum body height below .3,
while its initial height is about .33955; the guard checks the latter.

Reproduce using `check_endpoints.m`, then `python3 summarize_endpoints.py`.
Raw matrices: `endpoint_jacobians.mat`; full data: `endpoint_diagnostics.mat`;
compact machine-readable assessment: `conditioning_summary.json`.
