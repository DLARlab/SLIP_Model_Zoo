# B2 upper retry and independently validated stopping point

> Results-only layout. Numerical conclusions and evidence are retained. Historical filenames and run instructions refer to the [original numerical workspace](../../../../../P2_Numerical_Run_Archive/P2_original_layout_20261007.tar.gz). Use the [result path map](../../../../Audit/Provenance/result_path_map.json) and [branch tree index](../../../../README.md) for current locations.


The exact reversible8 pseudo-arclength retry extends the frozen upper checkpoint
from 102 to 168 native-accepted columns. Independent full-cycle replay retains the
continuous prefix **1:148**. The first excluded column 149 has a refined full 22-equation
residual above the declared 1e-8 tolerance. This is a numerical reproducibility
limit of this shooting implementation, not a demonstrated mathematical endpoint.

## Files and counts

- `upper_jointly_validated.mat`: 29×148 `results`, 8×148 `q`, 146×14 numeric
  `metrics`, seven parameters, and explicit `continuationInfo.terminationReason`.
  Its first two columns are the corrected original upper seeds; 146 columns are
  new upper continuation points, including 46 produced by the fail-fast retry.
- `upper_failfast_combined.mat`: all 168 raw native-accepted columns, including
  the 20 excluded near-singular tail candidates. It is preserved unchanged.
- `upper_failfast_retry.mat`: two frozen resumption seeds and 66 retry points,
  per-attempt backtracking records, and detailed geometry. The process was
  stopped by supervised TERM after its last atomic checkpoint; the verified
  output and this report provide the final stop reason.
- `joint_tight_validation.mat`: all raw upper/low snapshots and every individual
  replay result. All 362 low columns pass, so all 360 new low points are retained.
- `retry_validation_summary.json`: compact endpoint values, maxima, and hashes.

## Independent replay

Every one of 168 upper and 362 low columns was replayed at native tolerance,
1e-13, and 3e-14: 1590 full prescribed-cycle integrations. No orbit parameters
were corrected at the refined tolerances. The copies differ from the frozen
native function only in their callable names and `odeset` tolerances; equations,
contact schedules, touchdown resets, and residual definitions are unchanged.
`ode45` failure warnings are errors. Acceptance requires both the Euclidean
full 22-equation residual and the 13-state return norm (excluding translational drift) to
be below 1e-8, with the complete period reached.

The native code selects 1e-12 whenever initial velocity is less than 15, including
large negative velocity; otherwise it selects 1e-13. The refined copies apply
the same tighter tolerance to both signs. All low columns pass even after this
asymmetry is removed: the maximum retained full 22-equation residual over all three
settings is 5.1093e-12.

| Quantity | Last retained upper 148 | First excluded upper 149 |
|---|---:|---:|
| Initial velocity | 4.76045564108 | 4.7548984326 |
| Mean velocity, 3e-14 replay | 3.83647121167 | 3.82618592169 |
| Initial height | 0.112079174906 | 0.112244179606 |
| Full period | 1.3495272208 | 1.35226977611 |
| Native full 22-equation residual | 9.26969e-11 | 1.96579e-12 |
| Full22 residual at 1e-13 | 8.94306e-09 | 9.34061e-09 |
| Full22 residual at 3e-14 | 9.55527e-09 | 1.00723e-08 |
| 13-state return at 3e-14 | 8.19513e-09 | 8.63926e-09 |

The retained upper maximum full 22-equation residual over all three settings is
9.55527e-09. This is close to the requested
numerical threshold, so it should not be described as uniform 1e-10 accuracy.
The last raw candidate 168 reaches a 3e-14 residual of
3.09154e-08, despite its small native residual.
The progressive disagreement is consistent with native-integrator error being
absorbed by the native corrector near very short stance legs.

## Geometry and interpretation

At retained upper 148, refined adaptive trajectory samples give minimum stance
leg length 0.00336558064099, minimum stance hip height
0.0032921756835, minimum absolute stance-angle cosine
0.0219590494034, and minimum body height
0.0117239826897. These are sampled minima, not rigorous
continuous-time bounds. Stance leg length has decreased from about .00599 at
the frozen upper checkpoint 102 to about .00337 here. Neither an exact zero leg
nor an exact event collision is attained. The initial section remains a flight
apex, with vertical acceleration −1; apex flattening does not cause this stop.

The low endpoint remains regular at initial velocity -8.73907158012,
mean velocity -8.52943856147, period 0.95598069997, and sampled
minimum stance leg length 0.0257340609312. Its independent
phase/reflection overlap with the other B2 representation is documented by the
separate apex audit. It was stopped to avoid duplicating an already followed
family segment, not because this local low orbit reached a singularity.

Reproducing the retry uses `retry_upper_failfast(maxNewPoints,startStep,resumeExisting)`.
Failed ODE predictions trigger immediate backtracking; every accepted orbit is
atomically checkpointed. Reproducing the final cutoff uses
`validate_b2_tight_prefix`, then `python3 summarize_retry_validation.py`.
Further mathematical extension would require a tighter or better conditioned
shooting implementation plus renewed independent checks. No continuation beyond
this validated prefix is implied by the retained raw candidates.
