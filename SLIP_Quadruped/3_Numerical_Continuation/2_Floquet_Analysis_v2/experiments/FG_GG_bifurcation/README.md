# FG-to-GG bifurcation experiment

This independent package reproduces the symmetry-breaking attachment from
front-spread half-bounding with gathered suspension (`FG`) to galloping with
gathered suspension (`GG`). The refined reference point is
`dx = 5.91164917105`; the remaining hind left/right symmetry is broken.

Stage A receives only the packaged FG parent. The GG branch is a held-out
Stage-B validation input loaded after the Floquet direction and both signed
nonlinear corrections are frozen.

## Packaged-reference provenance

The supplied result artifacts are a frozen one-transition projection of the
verified combined six-transition roadmap run. Exporting selected the FG->GG
record and rebound saved branch paths and experiment provenance locally; it
did not recompute Stage-A finite differences, critical refinement, or branch
corrections. `main_Test_FGGGBifurcation` performs an independent package-local
dynamics recomputation and replaces the projected reference outputs.

## Layout

```text
FG_GG_bifurcation/
├── README.md, MANIFEST.md, RUN_METADATA.md, SHA256SUMS
├── FGGGExperimentPaths.m
├── main_Test_FGGGBifurcation.m
├── main_HandValidate_FGGGBifurcation.m
├── main_Refresh_FGGGReferenceArtifacts.m
├── data/parent_branch/BD1_20_2_FG.mat
├── data/held_out_daughter_branches/BD1_20_2_GG.mat
├── tests/
├── results/{intermediate,final}/
└── logs/
```

## Reproduce and audit

```matlab
experimentRoot = fullfile('SLIP_Quadruped','3_Numerical_Continuation', ...
    '2_Floquet_Analysis_v2','experiments','FG_GG_bifurcation');
addpath(experimentRoot);

report = main_Test_FGGGBifurcation();
assert(report.summary.accepted);
assert(strcmp(report.transitions.ID,'fg_to_gg'));

replay = main_HandValidate_FGGGBifurcation();
assert(replay.accepted);
```

Use `main_Refresh_FGGGReferenceArtifacts()` only to regenerate derived
validation and presentation files from a frozen Stage-A result.

Run the package tests with:

```matlab
results = run(testsuite(fullfile(experimentRoot,'tests'), ...
    'IncludeSubfolders',true));
assert(~any([results.Failed]));
```

Set `SLIP_RUN_LONG_FGGG_PACKAGE_TESTS=1` for a temporary production rerun.
Verify the package with `shasum -a 256 -c SHA256SUMS`.

The package-local final MAT is authoritative. The calculation is a fixed historical-window
test on a locally monotone segment of a folded parent, not a global blind
search. Shared Floquet and dynamics functions are deliberately not copied.
