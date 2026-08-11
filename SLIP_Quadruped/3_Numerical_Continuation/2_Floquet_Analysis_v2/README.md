# Floquet analysis v2 for the quadrupedal SLIP model

This directory is the clean-root implementation of reduced-Poincare Floquet
analysis, persistent bifurcation detection, and daughter-branch construction.
It is an adapter around the existing quadrupedal SLIP dynamics and event-time
solver. It does not copy, redesign, or modify the dynamics core.

The computed stability matrix is

\[
M=DP_\Sigma(q^\star)\in\mathbb R^{12\times12},
\qquad q=X([1,2,4{:}13]),
\]

where \(P_\Sigma\) is one complete apex-to-apex hybrid stride on
\(\Sigma=\{X:\dot y=0,\ \ddot y<0\}\). Horizontal translation and the
section-normal coordinate `X(3)=dy` are excluded. The nine event times are
re-solved for every perturbation, but they are not Floquet coordinates.

## Start here

Add only this directory to the MATLAB path:

```matlab
floquetRoot = fullfile(repoRoot,'SLIP_Quadruped', ...
    '3_Numerical_Continuation','2_Floquet_Analysis_v2');
addpath(floquetRoot)
```

Open the two-tab workbench with:

```matlab
FloquetAnalysisGUI()
```

The **Analyze Workflow** tab creates or resumes the five-stage process. The
**Analysis Viewer** tab inspects canonical analyses or derived visualization
datasets. `SLIP_Quadruped_GUI.m` is not modified.

For a new parent branch, the programmatic entry point is:

```matlab
[config,configFile] = floquet.workflow.create( ...
    parentBranchFile,outputRoot);
[analysis,state,config] = floquet.workflow.runStage(configFile,1);
```

Stage 1 always scans the original continuation columns in their stored order.
Passing `[]` as the branch selection means all columns; the branch is never
sorted by a display coordinate such as `dx`.

After inspecting the Stage-1 candidate inventory, explicitly confirm the
candidate IDs to refine:

```matlab
[config,state] = floquet.workflow.confirmCandidates( ...
    config,{'plus1_c0195_c0196'});
[refinement,state,config] = floquet.workflow.runStage(config,2);
[seeds,state,config] = floquet.workflow.runStage(config,3);
```

`confirmCandidates` and `confirmRays` return updated configurations; they do
not silently rewrite a supplied MAT file. The GUI provides persistent manual
confirmation controls. In scripts, continue with the returned in-memory
configuration or deliberately save an audited configuration snapshot.

## Public API

The supported numerical entry points are:

| Function | Purpose |
| --- | --- |
| `floquet.computeFDM` | Differentiate the validated reduced apex return map with scaled, multi-level central differences. |
| `floquet.analyzeBranch` | Analyze an ordered parent branch, track multipliers, and detect persistent crossings. |
| `floquet.detectBifurcations` | Detect signed `+1`, `-1`, and complex unit-circle crossings on reliable tracked intervals. |
| `floquet.refineCriticalOrbit` | Correct periodic orbits inside a spectral bracket and refine the critical crossing. |
| `floquet.predictBranchDirection` | Lift a verified reduced direction to a complete `[deltaX;deltaE]` predictor. |
| `floquet.correctBranchSwitch` | Correct a same-stride real-`+1` predictor, or dispatch to an explicit custom corrector. |
| `floquet.continueDaughterBranch` | Continue two validated, distinct-amplitude seeds on the same signed ray. |
| `floquet.validatePeriodicOrbit` | Check timing, section orientation, topology, stride completeness, and closure. |
| `floquet.inspectAnalysis` | Validate and summarize a saved analysis, dataset, or workflow without recomputation. |

The supported workflow entry points are:

```text
floquet.workflow.create
floquet.workflow.load
floquet.workflow.inspect
floquet.workflow.runStage
floquet.workflow.confirmCandidates
floquet.workflow.confirmRays
floquet.workflow.migrate
floquet.workflow.Session
```

Dataset and GUI APIs live under `floquet.io.*` and `floquet.gui.*`. Functions
under `floquet.internal.*` and `floquet.workflow.internal.*` are implementation
details and are not stable extension points.

## Canonical workflow

The standardized workflow has two deliberate human review gates:

1. **Discovery** validates every parent orbit, computes accepted reduced FDMs,
   tracks multipliers, and detects persistent crossings.
2. **Critical-orbit refinement** runs only for explicitly confirmed candidate
   IDs and recomputes the periodic orbit and Floquet matrix inside each
   bracket.
3. **Seed search** resolves admissible critical directions, obtains their
   induced timing response, and nonlinearly corrects signed, multi-amplitude
   seeds.
4. **Daughter continuation** runs only for explicitly confirmed pairs of
   accepted seeds at distinct amplitudes on the same signed ray.
5. **Validation** independently revalidates continued output and is the first
   stage allowed to use held-out daughter branches or gait-specific validators.

There is intentionally no automatic “run all” scientific path. A multiplier
crossing is not by itself a daughter branch, and a raw Floquet eigenvector is
not a periodic-orbit solution.

The built-in generic switch is for a simple, real, additional `+1` direction.
A repeated `+1` kernel needs an independently justified invariant-subspace
resolver, usually based on symmetry or a normal form. A `-1` crossing needs a
two-stride period-doubled formulation. A complex unit-circle crossing needs a
torus or invariant-circle formulation. Those cases are never silently sent to
the same-stride corrector.

## Output layout

Every new workflow uses schema `floquet-workflow-config-v2` and artifact layout
`numbered-artifacts-v1`:

```text
<workflow-output>/
  workflow_config.mat
  artifacts/
    01_discovery/
      floquet_analysis.mat
      candidate_inventory.csv
      rejected_points.csv
      rejected_intervals.csv
    02_refinement/
      refined_candidates.mat
      refinement_summary.csv
    03_seed_search/
      daughter_seed_search.mat
      daughter_seed_attempts.csv
    04_daughter_branches/
      inventory.mat
      inventory.csv
      <candidate>/<ray>/branch.mat
    05_validation/
      validation_report.mat
      validation_summary.csv
  checkpoints/
  views/
  logs/
```

The five numbered MAT artifacts are the sole numerical authorities for a new
workflow. `workflow_config.mat` contains configuration only. CSV files are
derived flat audit views and are not read by later stages. Each downstream
artifact is bound to its upstream canonical path and SHA-256. A combined
report or GUI cache may exist only as a derived `views/` product and cannot
feed the chain. Artifacts are immutable by default; overwrite and checkpoint
resume are explicit and provenance-checked.

## Directory structure

```text
2_Floquet_Analysis_v2/
  README.md
  FloquetAnalysisGUI.m
  +floquet/
    computeFDM.m
    analyzeBranch.m
    detectBifurcations.m
    refineCriticalOrbit.m
    predictBranchDirection.m
    correctBranchSwitch.m
    continueDaughterBranch.m
    validatePeriodicOrbit.m
    inspectAnalysis.m
    +internal/
    +workflow/
    +io/
    +gui/
  docs/
  templates/new_branch_workflow/
  examples/blind_parent_profiles/
  reference_experiments/
  reference_data/viewer_datasets/
  tests/
```

`+floquet` owns reusable production code. `templates` and `examples` show how
to start from an unlabeled parent. `reference_experiments` contains frozen,
targeted reproductions used for regression and hand validation. It is not the
template for a new blind workflow.

## Scientific acceptance and rejection

An FDM is rejected rather than partially trusted when any required condition
fails, including:

- the base periodic-orbit residual exceeds tolerance;
- the existing event-time solve fails its nine-equation residual or
  repeatability checks;
- the initial or returned point is not a descending apex;
- the trajectory does not cover one complete stride;
- a finite-difference perturbation changes the required event topology;
- multi-level central derivatives do not converge; or
- the finest forward/backward directional derivatives disagree.

Rejected branch points remain explicit gaps. Multiplier tracking restarts
after a rejected point, a nonadjacent source-column selection, or an invalid
topology interval. Detection never creates a crossing across such a gap.

The detector uses signed brackets and neighboring-point persistence. It does
not use `abs(lambda-target)<threshold` as its sole criterion. At `+1`, the
state direction is compared with a valid fixed-parameter continuation tangent.
Near a repeated root, individual eigensolver columns are treated as
basis-dependent until invariant-subspace refinement resolves them.

## Analysis, datasets, and reference evidence

`floquet.analyzeBranch` produces the canonical scientific artifact. A
`FloquetData` file is a derived visualization cache, not a required second
analysis. Create one only when repeated GUI loading or interchange needs it:

```matlab
[FloquetData,outputFile] = floquet.io.exportDataset(analysis,options);
```

The nine checked-in files under `reference_data/viewer_datasets` are reusable
schema-1.0 viewer datasets. They were computed with the production reduced-
Poincare FDM evaluator and retain their matrices, solved event times,
acceptance masks, and eigendata, so renaming the catalog does not require a
numerical rerun. They remain derived, non-authoritative visualization data:
their historical screening annotations are not canonical v2 bifurcation
detections and they do not supersede an experiment's Stage-1 artifact.

The five independent packages under `reference_experiments` reproduce
previously known pronking, half-bounding, and galloping transitions. They are targeted,
retrospective evidence with local scan/refinement choices and held-out gait
comparisons. Their numbered artifacts are packaged for inspection, but they
are not generic resumable `floquet.workflow.*` chains and must not be used to
pre-label a new parent branch.

In those reference packages, the specialized result MAT in Stage 5 is the
authoritative complete record. The adjacent `validation_report.mat` is a
compact `floquet-reference-validation-index-v3` record containing validation
metrics plus paths and SHA-256 identities; it deliberately does not duplicate
the complete experiment report. This differs from a generic workflow, where
the normal Stage-5 report is itself part of the canonical artifact chain.

## Historical data and configuration migration

New sessions need only `addpath(floquetRoot)` and qualified `floquet.*` calls.
The former unqualified global entry points have been retired; there is no
compatibility path or setup mode to enable. The current-name mapping is
recorded in `docs/compatibility.md` for updating old external scripts.

This API retirement does not discard historical numerical evidence. Completed
v1 artifacts may still be inspected as read-only data. V1 checkpoints are not
resumable. Only an empty v1 workflow can be explicitly converted with
`floquet.workflow.migrate`; a nonempty v1 chain must be preserved and a new v2
output root used for recomputation.

## Regression tests

Run the routine suite from the repository root with:

```matlab
floquetRoot = fullfile(pwd,'SLIP_Quadruped', ...
    '3_Numerical_Continuation','2_Floquet_Analysis_v2');
results = run(testsuite(fullfile(floquetRoot,'tests'), ...
    'IncludeSubfolders',true));
assert(~any([results.Failed]));
```

Expensive production checks are discovered but assumption-filtered unless
their environment gate is set to `1` before the MATLAB run:

- `SLIP_RUN_LONG_FLOQUET_TESTS`: production return-map/FDM checks;
- `SLIP_RUN_LONG_FLOQUET_GUI_TESTS`: production analysis-to-view export;
- `SLIP_RUN_BRANCH_SWITCH_TESTS`: complete PK critical-orbit validation;
- `SLIP_RUN_PRONKING_GAIT_CORRECTOR_TESTS`: two-radius six-ray correction;
- `SLIP_RUN_LONG_ROADMAP_TESTS`: independent targeted roadmap recomputation.

Frozen reference-result checks and hand-replay contracts remain in the
routine suite; these gates control only fresh dynamics-heavy recomputation.

## Documentation

- [Mathematical foundation](docs/mathematics.md)
- [Five-stage workflow](docs/workflow.md)
- [Artifact and provenance schema](docs/artifact_schema.md)
- [Historical API and data migration](docs/compatibility.md)
- [New-branch template](templates/new_branch_workflow/README.md)
- [Test organization](tests/README.md)

## Known limitations

The derivative assumes a locally smooth, fixed-topology return map. Grazing
events, topology changes, and simultaneous impacts can make the derivative
nonsmooth or sector-dependent. Clustered event comparison permits documented
reordering only within an existing simultaneous-event cluster; it does not
prove differentiability. A branch segment that folds in `X(1)=dx` also cannot
be refined safely by the current fixed-`dx` critical-orbit chart and needs a
pseudo-arclength or hyperplane formulation.
