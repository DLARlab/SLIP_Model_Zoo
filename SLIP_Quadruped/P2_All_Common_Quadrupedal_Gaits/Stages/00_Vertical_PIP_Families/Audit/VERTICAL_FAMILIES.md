# Entire regular delayed PIP family: analytic construction

> Results-only layout. Numerical conclusions and evidence are retained. Historical filenames and run instructions refer to the [original numerical workspace](../../../../P2_Numerical_Run_Archive/P2_original_layout_20261007.tar.gz). Use the [result path map](../../../Audit/Provenance/result_path_map.json) and [branch tree index](../../../README.md) for current locations.


`vertical_families.mat` stores **1586 finite samples** of the exact analytic
family on the open energy interval **1<E<20**. The formula defines the entire
regular family; no finite file can contain its continuum of points. The
sampled energy interval is `1.0000000001 ≤ E ≤ 19.99999`.
Neither the exact zero-flight nor the zero-leg-length endpoint is included.

The main `results` array is 29×1586, in the existing model's state/event/parameter
order. It starts at a tensile, four-leg **stance apex**, matching the phase of
`PK_B2_Parent` column 132. `ordinaryPIPResults` contains the equal-energy ordinary
family, beginning at its **flight apex**. Those two heights must not be treated
as a common section coordinate. Use `E` or the explicitly labeled phases.

## Equations

Set `w=√40`, `yeq=.975`, `v=√(2(E−1))`,
`A=√(.025²+v²/40)`, `θ=atan2(v/w,.025)`. Then

- Delayed initial height: `h=yeq+A`.
- Liftoff `LO=(2π−θ)/w`, touchdown `TD=LO+2v`, period `T=LO+TD`.
- Ordinary initial height: `E`; touchdown `v`, stance `(2π−2θ)/w`.
- Both have flight duration `2v` and minimum height/leg length `yeq−A`.
- Delayed minimum force per leg: `10(1−h)`; total minimum: `40(1−h)`.
- At equal energy `T_delayed−T_ordinary=2π/√40` exactly.

The full delayed cycle has one flight interval and two compression minima.
The intervening flight apex is not a full-state/contact return. The two
families have different contact schedules even though they share conserved
energy. No regular ordinary-PIP→delayed-PIP connection is claimed.

## Endpoints and coverage

At `E→1+`, delayed `T→4π/√40`; its limiting all-stance orbit has minimal period
`2π/√40`, so the delayed limit is a double cover. Contact events graze and
flight collapses; the exact endpoint is not in the regular timing chart.
At `E→20−`, the minimum leg length tends to zero, where the original stance
model is singular. The finite upper sample uses `E=20−1e−5`, with minimum leg
length `2.56410290111e-07`. Boundary values are analytic limits,
not validated regular samples. Dense energy sampling surrounds the PK
bifurcation at `E=1.087455508685840`.

## Validation

All columns pass forward analytic segment composition. Maximum delayed
full-state return norm is `1.93e-13` and contact
residual norm `5.685e-14`; ordinary maxima are
`1.081e-14` and
`1.49e-14`.

An independent DOP853 replay integrates the radial Cartesian force law over
all three complete segments for 36 representative columns
of each family, at tolerances 1e−12 and 3e−14 (144 replays). It uses
neither reflected trajectory construction nor timing correction. Maximum
full-state return norm is `3.975e-12`, maximum contact residual is
`1.284e-12`. The critical 29-vector differs from the frozen source by
`1.601e-15`. All reports, including upper
and lower finite endpoint samples, are retained in MAT/JSON.

`validate_native_samples.m` additionally replays selected columns through the
frozen production model, saving its independent report separately. Its outcome
must be read from `native_sample_validation.json` after that script runs;
the Python construction does not imply native validation of every sample.
See `NATIVE_REPLAY.md` for the interpretation of near-collision native failures.

## Main MAT fields

`results`, `ordinaryPIPResults`, `E`/`energy`, `period`, `initialHeight`,
`meanVelocity` (all zero), `minimumHeight`, `minimumStanceLegLength`,
`minimumVerticalGRF` (per leg), `minimumTotalVerticalGRF`, `flightDuration`,
`stanceDuration`, `criticalColumn` (MATLAB one-based), `branchInfo`, `validation`.

Reproduce with `python3 generate_vertical_families.py`. The Python file reads
only this audit's frozen snapshots and writes only this directory. No original
branch or production source files are changed.
