# BG half-bounding bifurcation experiment

This independent package reproduces the two symmetry-breaking attachments of
the bounding-with-gathered-suspension (`BG`) branch:

| transition | broken pair | daughter gait | reference refined `dx` |
|---|---|---|---:|
| BG -> HG | hind left/right | hind-spread half-bound, gathered | 4.50616189521 |
| BG -> FG | front left/right | front-spread half-bound, gathered | 5.64566295496 |

For each transition, Stage A constructs and refines the reduced apex
Poincare-map crossing using only the packaged BG parent. Stage B loads the
corresponding held-out daughter after the parent prediction is frozen.

Reusable Floquet, roadmap-analysis, hybrid-dynamics, and continuation code is
not duplicated here. The package is independently runnable inside this
repository and owns its input copies, result files, tests, and logs.

## Packaged-reference provenance

The supplied final and intermediate MAT files are a frozen two-transition
projection of the already verified combined six-transition roadmap run.
Exporting the projection did not recompute finite differences, refinement, or
branch corrections; it selected the BG records and rebound all saved branch
paths and experiment provenance to this local package. Running
`main_Test_BGHalfBoundingBifurcation` is the independent package-local
recomputation and replaces these outputs with a new local dynamics run.

## Layout

```text
BG_half_bounding_bifurcation/
├── README.md, MANIFEST.md, RUN_METADATA.md, SHA256SUMS
├── BGHalfBoundingExperimentPaths.m
├── main_Test_BGHalfBoundingBifurcation.m
├── main_HandValidate_BGHalfBoundingBifurcation.m
├── main_Refresh_BGHalfBoundingReferenceArtifacts.m
├── data/
│   ├── parent_branch/BD1_20_2_BG.mat
│   └── held_out_daughter_branches/BD1_20_2_{HG,FG}.mat
├── tests/
├── results/{intermediate,final}/
└── logs/
```

## Reproduce

From the repository root in MATLAB:

```matlab
experimentRoot = fullfile('SLIP_Quadruped','3_Numerical_Continuation', ...
    '2_Floquet_Analysis_v2','experiments', ...
    'BG_half_bounding_bifurcation');
addpath(experimentRoot);

report = main_Test_BGHalfBoundingBifurcation();
assert(report.summary.accepted);
assert(isequal({report.transitions.ID},{'bg_to_hg','bg_to_fg'}));
```

The wrapper pins the package root and transition IDs. It defaults outputs and
the log to this folder, while allowing a caller to override those paths (for
example, to run a non-destructive test in a temporary directory). Numerical
options such as `MakePlots`, `Verbose`, and nested analysis tolerances may be
supplied in a scalar structure.

## Independent hand replay

```matlab
replay = main_HandValidate_BGHalfBoundingBifurcation();
assert(replay.accepted);
```

This reloads the package-local final MAT, reevaluates periodic residuals and
production return maps, reclassifies corrected gaits, and recomputes the
held-out daughter comparisons. It does not recompute Floquet matrices.

If only derived validation or presentation code changes, refresh projections
without claiming a new Stage-A computation:

```matlab
report = main_Refresh_BGHalfBoundingReferenceArtifacts();
```

## Tests and integrity

```matlab
suite = testsuite(fullfile(experimentRoot,'tests'),'IncludeSubfolders',true);
results = run(suite);
assert(~any([results.Failed]));
```

Set `SLIP_RUN_LONG_BG_PACKAGE_TESTS=1` to add a production recomputation in a
temporary output directory. Verify packaged files from this directory with:

```bash
shasum -a 256 -c SHA256SUMS
```

The package-local final MAT is authoritative; CSV, Markdown, PNG, and FIG files are manual
inspection projections. This is a targeted historical-window validation on a
folded parent branch, not a blind global bifurcation search. Grazing, changed
event topology, and nonsmooth simultaneous impacts remain rejection cases.
