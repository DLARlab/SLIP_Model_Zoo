# BE half-bounding bifurcation experiment

This independent package reproduces the two symmetry-breaking attachments of
the bounding-with-extended-suspension (`BE`) branch:

| transition | broken pair | daughter gait | reference refined `dx` |
|---|---|---|---:|
| BE -> FE | front left/right | front-spread half-bound, extended | 4.83363821441 |
| BE -> HE | hind left/right | hind-spread half-bound, extended | 6.04807025559 |

Stage A uses only the packaged BE branch. Each held-out daughter is loaded in
Stage B after its parent prediction, timing lift, and signed nonlinear
corrections are frozen. Shared numerical and dynamics functions are not
duplicated in this package.

## Packaged-reference provenance

The supplied results are a frozen two-transition projection of the verified
combined six-transition roadmap run. The export selected the BE records and
rebound saved data paths and experiment provenance to this folder; it did not
recompute the Stage-A Floquet maps, refinement, or corrections.
`main_Test_BEHalfBoundingBifurcation` performs the independent package-local
dynamics recomputation and replaces the projected reference outputs.

## Layout

```text
BE_half_bounding_bifurcation/
├── README.md, MANIFEST.md, RUN_METADATA.md, SHA256SUMS
├── BEHalfBoundingExperimentPaths.m
├── main_Test_BEHalfBoundingBifurcation.m
├── main_HandValidate_BEHalfBoundingBifurcation.m
├── main_Refresh_BEHalfBoundingReferenceArtifacts.m
├── data/
│   ├── parent_branch/BD1_20_2_BE.mat
│   └── held_out_daughter_branches/BD1_20_2_{FE,HE}.mat
├── tests/
├── results/{intermediate,final}/
└── logs/
```

## Reproduce and audit

```matlab
experimentRoot = fullfile('SLIP_Quadruped','3_Numerical_Continuation', ...
    '2_Floquet_Analysis_v2','experiments', ...
    'BE_half_bounding_bifurcation');
addpath(experimentRoot);

report = main_Test_BEHalfBoundingBifurcation();
assert(report.summary.accepted);
assert(isequal({report.transitions.ID},{'be_to_fe','be_to_he'}));

replay = main_HandValidate_BEHalfBoundingBifurcation();
assert(replay.accepted);
```

To refresh only derived validation and presentation artifacts:

```matlab
report = main_Refresh_BEHalfBoundingReferenceArtifacts();
```

The package wrapper pins its local input root and transition IDs. Output and
log paths default locally but remain caller-overridable for non-destructive
temporary reruns; ordinary numerical options use the same scalar structure.

## Tests and integrity

```matlab
suite = testsuite(fullfile(experimentRoot,'tests'),'IncludeSubfolders',true);
results = run(suite);
assert(~any([results.Failed]));
```

Set `SLIP_RUN_LONG_BE_PACKAGE_TESTS=1` for a production recomputation in a
temporary directory. Run `shasum -a 256 -c SHA256SUMS` from this package to
verify the frozen record.

The package-local final MAT is authoritative. This experiment validates fixed historical
windows on a folded parent branch; it is not a blind global search. Hybrid
grazing, topology changes, and simultaneous-impact nonsmoothness cause
rejection.
