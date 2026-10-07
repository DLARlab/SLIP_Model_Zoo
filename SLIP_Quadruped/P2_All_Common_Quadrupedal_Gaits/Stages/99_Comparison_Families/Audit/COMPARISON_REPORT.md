# BIP comparison against every current P2 branch

> Results-only layout. Numerical conclusions and evidence are retained. Historical filenames and run instructions refer to the [original numerical workspace](../../../../P2_Numerical_Run_Archive/P2_original_layout_20261007.tar.gz). Use the [result path map](../../../Audit/Provenance/result_path_map.json) and [branch tree index](../../../README.md) for current locations.


The 904 stored BIP orbits do not supply an intersection with any of the other
five current P2 branches. This conclusion uses full state, period and contact
information. Crossings of projected curves in a two-coordinate diagram do not
establish a bifurcation.

This audit reads the six frozen MAT snapshots listed in
`full_branches/source_manifest.json`, verifies their exact SHA-256 hashes and
preserves all result columns in `comparison.mat`. Original P2 branch names are
retained from the manifest's `sourceFile` fields; snapshot paths resolve relative
to the manifest. The comparison script requires no external P2 files. Original
MAT files are not modified. Distances below use the nondimensional coordinates as stored;
they are screening measurements, not normal-form or continuation certificates.

## Period and contact tests that survive a phase change

BIP has periods 2.476936235883–2.982224683529. Its period range is separated
from each stored moving synchronous branch and B2:

| Other current branch | Period range | Minimum gap to the BIP range |
|---|---:|---:|
| B2_10_20_2_G | 1.144569903822–2.381886791472 | 0.095049444411 |
| PK_B2_Parent | 2.123276736327–2.440936446440 | 0.035999789442 |
| PK_20_2 | 0.896710786377–1.564520214497 | 0.912416021386 |

A fixed shift of phase, left/right relabelling, or horizontal reflection with
front/hind relabelling leaves the period unchanged. Therefore these saved
full cycles cannot be the same orbit under those transformations.

Every BIP column has exactly one nondegenerate stance interval and one swing
interval for each labelled leg. The shortest stance is 1.736706904174 and the
shortest swing is 0.428851379543. All 904 have zero all-leg-flight intervals.
The circular front/hind touchdown separation is
0.411612335826–0.499998545503 of the period; liftoff gives the same range to
numerical precision. A phase shift changes neither separation. Relabelling
only exchanges the two event clusters and cannot make them synchronous.

All stored PK, PK_B2_Parent, PIP and PIP_Spread orbits instead have simultaneous
four-leg events and one all-leg-flight interval. Their contact itinerary cannot
match BIP. The period ranges of PIP and PIP_Spread overlap BIP, so period alone
is not used to exclude those two families.

Repeated covers were considered explicitly. Repeating a nondegenerate cycle
twice would produce two touchdown/liftoff pairs for each labelled leg. BIP has
only one of each and positive stance and swing durations throughout the file.
Consequently it is not a doubled or higher cover of any of the saved cycles,
which also have one stance/swing interval per leg. In particular, the BIP
period being approximately twice a PK period does not imply a period-doubling
connection. This argument does not exclude an uncomputed limit where event
intervals collapse or the contact itinerary changes.

## State and symmetry checks

Synchronous pronking remains in the linear state subspace with zero body pitch
and pitch rate and four equal leg angles/rates throughout the hybrid orbit.
The minimum Euclidean distance of any initial BIP state to that subspace is
0.125879112126, at BIP column 217. This lower bound holds even if a pronking
trajectory is compared at a different phase.

The corresponding minimum distance to the stationary vertical PIP subspace
is 0.256207127981 at column 242. The weaker stationary zero-pitch condition
u=phi=dphi=0 is already separated by 0.129418018826 at column 227. Including
the stationary spread family's opposing front/hind angle and rate symmetry
gives minimum distance 0.177630110962 at column 252. These finite separations
also exclude phase-equivalent stationary PIP and spread orbits among the
saved BIP states.

BIP has two pitch-rate sign-change brackets, but neither restores pronking
symmetry:

| BIP bracket | Interpolated u | Interpolated height | Hind leg angle at dphi=0 | Period |
|---|---:|---:|---:|---:|
| 134:135 | 0.451852734 | 0.834876813 | 0.333428170 | 2.48772873 |
| 345:346 | −0.434163985 | 0.852945677 | −0.289892059 | 2.48965891 |

These are linear interpolation candidates, not corrected solutions. They were
sent for independent dynamics checks. Nonzero opposite front/hind angles and
asynchronous event clusters remain, so a pitch-rate zero by itself is not a
PK connection. Likewise the initial-speed zero at source column 228 retains
pitch rate approximately 0.129687503; zero translation at one section does not
make the orbit PIP.

## Nearest stored states are not intersections

Every pair of BIP and other-branch columns was compared in the full 13-state
coordinates. A second distance includes circular normalized event times and
the full period. Both direct coordinates and the permitted horizontal
reflection/front-hind relabelling were tested. Left/right exchange has no
effect on these pair-synchronous data to their stored numerical precision.

The nearest direct BIP–B2 states are BIP 174 and B2 column 401, distance
0.123654689691, with a period difference of 0.423480008680. Reflection produces
a closer state comparison at BIP 240 versus reflected B2 column 22:
distance 0.042343842565. That pair still differs in period by 0.634226545739 and
in circular normalized event coordinates by 0.135545339697. It is not a
matching orbit. The smallest joint state/event/period distance to B2 is
0.437506623241 at BIP 167/B2 column 400.

`nearest_comparisons.csv` records all five branch comparisons and both symmetry
orientations without discarding unsuccessful candidates. These stored-section
nearest-neighbour distances are not called phase-invariant; the period,
contact-lag and invariant-subspace tests above are the phase-invariant evidence.

## Coverage and interpretation

The current BIP MAT explicitly reports
`entireMathematicalBranchEstablished=false` and `closedComponentDetected=false`.
Its two directions stopped at the configured height cutoff 0.3 and numerical
issues. Those stopping rules do not prove mathematical endpoints. The diagram
can therefore show the entire **stored** BIP branch, with no verified edge to
the PIP→PK→B2 route. It cannot establish that the global continuation component
is disconnected, or that BIP will never meet another branch after extension.

Reproduce with `python3 compare_current_bip.py` from any working directory,
passing the script's path as needed. `summary.json` contains the
manifest-based inventory, snapshot hashes, period/contact bounds, all candidate brackets and
nearest-pair measurements. `bip_all_columns.csv` preserves all 904 column-wise
symmetry/contact diagnostics. Independent dynamics validation is provided by
the companion `bip_dynamics` audit; this geometric script does not substitute
metadata for fresh periodic-orbit validation.
