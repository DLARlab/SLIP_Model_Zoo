# Roadmap secondary-bifurcation robustness experiment

This package tests the reduced Poincare-map Floquet-v2 implementation on four
non-pronking parent branches and six historically known secondary gait
connections:

| parent experiment | targeted transition | symmetry broken | expected daughter |
|---|---|---|---|
| BG | BG -> HG | hind left/right | hind-spread half-bound, gathered |
| BG | BG -> FG | front left/right | front-spread half-bound, gathered |
| BE | BE -> FE | front left/right | front-spread half-bound, extended |
| BE | BE -> HE | hind left/right | hind-spread half-bound, extended |
| FG | FG -> GG | remaining hind left/right | gallop, gathered |
| HE | HE -> GE | remaining front left/right | gallop, extended |

The two signs at each simple pitchfork are symmetry-equivalent orientations of
the same gait class. Thus six critical points produce twelve corrected local
branch rays: two per transition.

## Scientific scope

This is a **retrospective targeted-window robustness test**, not an exhaustive
blind search of every parent column. The six scan windows were fixed from the
historical roadmap before Floquet computation. For each transition, candidate
selection, critical refinement, timing lift, and nonlinear correction receive
only that transition's parent branch; its specified daughter is used only by
the later validation call.

FG and HE necessarily have two roles in the complete six-case run: each is a
held-out daughter for a bounding transition and a parent for a later galloping
transition. The isolation claim is therefore per transition, not a claim that
the MATLAB process never opens an FG or HE file during any Stage-A case.

The isolation is made auditable by saving
`results/intermediate/parent_only_predictions.mat` before Stage B begins. Every
parent analysis also records `daughterDataLoaded=false` and
`parentOnlyValidation.daughterDataUsed=false`.

## Reference result

The packaged MATLAB R2025b reference run accepted all six parent-only
predictions and all six held-out daughter checks:

| transition | refined `dx` | exact nullity of `M-I` | accepted signed corrections | Floquet/daughter alignment |
|---|---:|---:|---:|---:|
| BG -> HG | 4.50616189521 | 2 | 4/4 | 0.999918 |
| BG -> FG | 5.64566295496 | 2 | 4/4 | 0.999063 |
| BE -> FE | 4.83363821441 | 2 | 4/4 | 1.000000 |
| BE -> HE | 6.04807025559 | 2 | 4/4 | 0.999257 |
| FG -> GG | 5.91164917105 | 2 | 4/4 | 0.999791 |
| HE -> GE | 6.13622289546 | 2 | 4/4 | 0.999819 |

Thus the algorithm recovered the two requested gathered-suspension half-bound
attachments, the two extended-suspension half-bound attachments, and the two
galloping attachments. The two corrected signs at each point are symmetry
orientations of the same daughter gait, not two additional gait classes.

Across the six scans, the worst reported central-difference convergence error
was `1.889e-7`, the worst forward/backward mismatch was `2.429e-4`, and the
worst event-timing residual was `3.431e-11`. The minimum held-out linear
alignment was `0.999063`.

## Floquet object being tested

At the apex section

\[
\Sigma=\{x:\dot y=0,\;\ddot y<0\},
\]

the code differentiates the reduced one-stride return map

\[
M=DP(X^\star),\qquad
M_i=\frac{P(X^\star+h_i e_i)-P(X^\star-h_i e_i)}{2h_i}.
\]

The reduced coordinates are `X([1 2 4:13])`: horizontal translation and the
apex-normal state are excluded. The production timing solver is called for
every perturbed state and determines all nine event times. Those times are
needed to evaluate the hybrid map and later to lift a state eigenvector into a
complete `[deltaX;deltaE]` predictor, but they are never Floquet coordinates.

Each expected transition must satisfy all of the following:

1. all five reduced finite-difference matrices pass periodic-orbit, timing,
   event topology, derivative convergence, and forward/backward checks;
2. multiplier tracking finds one persistent additional +1 crossing in the
   predeclared window;
3. `RefineCriticalOrbit` verifies the exact SVD nullity of `M-I` is two: one
   parent tangent plus one unique additional direction;
4. the critical vector is odd under the expected front/hind leg swap, the
   parent tangent is even, and `M` numerically commutes with that swap;
5. one-sided sector timing lifts and canonical nonlinear corrections succeed
   for both signs at multiple decreasing amplitudes;
6. the two signs map into one another under the appropriate full state/event
   leg swap;
7. after predictions are frozen, a saved daughter secant aligns with the
   reduced Floquet direction and has the expected gait and broken symmetry.

The five-point detector scans use four perturbation levels
`[8 4 2 1]*5e-7`. Safeguarded critical refinement recomputes every trial map
with three levels `[4 2 1]*5e-7`; it therefore retains a decreasing-step
convergence estimate without paying for a redundant coarsest map at every
bracket iteration.

`DetectBifurcation.NullMultiplicity` is deliberately not treated as exact
nullity. The detector uses a loose candidate radius and can count nearby but
noncritical multipliers. Refinement uses the uncertainty-aware singular values
of `M-I` and is authoritative.

## Run the complete experiment

Start MATLAB from the repository root:

```matlab
experimentRoot = fullfile( ...
    'SLIP_Quadruped','3_Numerical_Continuation', ...
    '2_Floquet_Analysis_v2','experiments', ...
    'roadmap_bifurcation_robustness');
addpath(experimentRoot);

report = main_Test_RoadmapBifurcationRobustness();
assert(report.summary.accepted);
```

To rerun one transition while developing:

```matlab
report = main_Test_RoadmapBifurcationRobustness(struct( ...
    'TransitionIDs',{{'fg_to_gg'}}, ...
    'MakePlots',false));
```

When `TransitionIDs` is nonempty and no paths are supplied explicitly, the
driver writes into `results/subsets/` so a development run cannot overwrite
the canonical six-transition reference artifacts. Explicit output,
intermediate, and log paths remain supported.

## Independent hand replay

The hand replay reevaluates canonical periodic residuals, calls the production
return map for every critical and corrected orbit, reclassifies gaits, reruns
the held-out daughter validation from the frozen parent analysis, and writes a
flat CSV:

```matlab
replay = main_HandValidate_RoadmapBifurcations();
assert(replay.accepted);
```

For a fully independent Floquet recomputation, rerun the complete experiment;
the hand replay intentionally avoids recomputing the expensive finite
differences.

If only validation or artifact formatting code changes after a completed
Stage-A run, refresh the derived diagnostics and held-out checks without
claiming a new Floquet computation:

```matlab
report = main_Refresh_RoadmapReferenceArtifacts();
assert(report.summary.accepted);
```

The refreshed report records this limited scope explicitly. It is not a
substitute for the complete production rerun.

## Tests

```matlab
suite = testsuite(fullfile(experimentRoot,'tests'), ...
    'IncludeSubfolders',true);
results = run(suite);
assert(~any([results.Failed]));
```

The packaged-result tests are fast. The production recomputation test is
reported as incomplete unless explicitly enabled. To additionally recompute
BE -> FE from the production dynamics and require every test to pass, run:

```matlab
setenv('SLIP_RUN_LONG_ROADMAP_TESTS','1');
results = run(suite);
assert(all([results.Passed]));
```

Reference verification on MATLAB R2025b:

- roadmap suite with production BE -> FE recomputation: **13 passed, 0
  failed, 0 incomplete** (`352.5 s` in the packaged final log; an earlier
  independent run also passed in `366.6 s`);
- independent hand replay: **6/6 transitions passed**, with the largest
  corrected canonical residual `1.217e-13`;
- existing pronking-package cross-regression: **21 passed, 0 failed, 0
  incomplete** (`9.87 s`).

## Output layout

```text
data/branch_library/
  BD1_20_2_{BG,BE,FE,FG,HE,HG,GG,GE}.mat
results/intermediate/
  parent_only_predictions.mat
  parent_only_predictions_checkpoint.mat
results/final/
  roadmap_bifurcation_robustness_results.mat
  roadmap_bifurcation_robustness_summary.csv
  roadmap_branch_switch_corrections.csv
  roadmap_hand_validation_replay.csv
  roadmap_bifurcation_robustness_report.md
  roadmap_floquet_crossings.{png,fig}
  roadmap_held_out_validation.{png,fig}
  cases/<transition>/<transition>_result.mat
results/subsets/<transition-id-set>/
  final/, intermediate/, logs/
logs/
  roadmap_robustness_full_experiment.log
  roadmap_robustness_hand_validation.log
  roadmap_robustness_tests_fast.log
  roadmap_robustness_tests.log
  pronking_cross_regression.log
  roadmap_package_integrity.log
```

Generated MAT files use MATLAB's compressed `-v7` format. The complete report
remains self-contained while avoiding the multi-gigabyte duplication that the
HDF5 representation produced for these nested scan diagnostics.

From this experiment directory, verify every packaged file before manual
inspection with:

```bash
shasum -a 256 -c SHA256SUMS
```

## Fold limitation and the next algorithmic extension

All four parent branches fold in `dx`. The six selected adjacent brackets are
explicitly checked for a locally monotone `X(1)=dx` chart before the existing
critical refiner is allowed to fix `dx`; this makes the targeted calculations
safe. It does not make `dx` a valid global branch coordinate.

An exhaustive branch-wide discovery tool should parameterize stored points by
scaled cumulative arclength and correct trial critical orbits with a local
pseudo-arclength hyperplane. Until that extension is implemented, this package
does not claim blind whole-branch coverage.

The usual hybrid limitations also remain: grazing, a true event-topology
change, or a nonsmooth simultaneous-impact map must cause rejection rather than
be interpreted as a Floquet crossing.
