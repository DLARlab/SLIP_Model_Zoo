# Historical API and data migration

Clean-root v2 has one authoritative reusable implementation: the qualified
`floquet.*` package. Historical unqualified global-function adapters have been
retired and removed from the repository.
The quadrupedal dynamics and event-time solver remain outside this directory
and are reused unchanged.

## Path policy

New code adds only the Floquet-v2 root:

```matlab
addpath(floquetRoot)
```

MATLAB then resolves package calls such as:

```matlab
floquet.computeFDM(...)
floquet.analyzeBranch(...)
floquet.workflow.create(...)
floquet.gui.launch()
```

Do not rely on `addpath(genpath(floquetRoot))`. Recursive path setup makes
implementation details appear to be supported public entry points and can
silently select unrelated functions from stale MATLAB paths.

The public numerical functions add only the existing external dynamics,
continuation, and solution paths they need at run time. They do not modify the
dynamics implementation.

## Retired global names

The following mechanical substitutions migrate historical callers to the
current API. The names in the right column no longer ship as callable files.

| Current API | Removed global name |
| --- | --- |
| `floquet.computeFDM` | `ComputeFloquetFDM` |
| `floquet.analyzeBranch` | `AnalyzeFloquetBranch` |
| `floquet.detectBifurcations` | `DetectBifurcation` |
| `floquet.refineCriticalOrbit` | `RefineCriticalOrbit` |
| `floquet.predictBranchDirection` | `PredictBranchDirection` |
| `floquet.correctBranchSwitch` | `CorrectBranchSwitch` |
| `floquet.continueDaughterBranch` | `ContinueDaughterBranch` |
| `floquet.validatePeriodicOrbit` | `ValidatePeriodicOrbit` |
| `floquet.workflow.create` | `CreateFloquetWorkflowConfig` |
| `floquet.workflow.load` | `LoadFloquetWorkflowConfig` |
| `floquet.workflow.inspect` | `InspectFloquetWorkflowState` |
| `floquet.workflow.Session` | `FloquetWorkflowController` |
| `floquet.io.exportDataset` | `BuildFloquetDatasetFromAnalysis` |
| `floquet.io.loadDataset` | `LoadFloquetDataset` |
| `floquet.io.trackDisplayMultipliers` | `TrackFloquetMultipliers` |
| `floquet.gui.launch` | `FloquetAnalysisGUIImpl` |
| `floquet.gui.plot.BranchPlotAdapter` | `SLIPBranchPlotAdapter` |

Former global aliases for Poincare-map, event-topology, tracking, plotting, and
workflow-internal helpers have no public replacement. Reusable callers should
use the public operations above. Code maintained inside this package may use
the explicitly qualified `floquet.internal.*` or
`floquet.workflow.internal.*` implementation when an internal unit boundary
must be tested.

The convenient root function `FloquetAnalysisGUI` is not a legacy numerical
implementation. It is a stable launcher that delegates to
`floquet.gui.launch`.

The secondary `floquet.io.generateDiagnosticDataset` computation path and its
internal `GenerateFloquetDataset` implementation are also retired. They
duplicated branch scanning, event-topology screening, tracking, and detection
already owned by the canonical analyzer. Replace one-step generation with the
explicit authority chain:

```matlab
analysis = floquet.analyzeBranch(branchFile,[],analysisOptions);
[FloquetData,viewFile] = floquet.io.exportDataset(analysis,exportOptions);
FloquetData = floquet.io.loadDataset(viewFile);
```

Only `analyzeBranch` evaluates the reduced Poincare map. `exportDataset` is a
lossless visualization projection and `loadDataset` only validates/loads.
The retained `floquet.io.trackDisplayMultipliers` utility is not another
scientific tracker: it controls GUI ordering/colors only and never detects or
authorizes a bifurcation.

## Recommended caller migration

Replace global calls mechanically, then remove legacy setup from the caller:

```matlab
% Before
[M,lambda,V,d] = ComputeFloquetFDM(z,para,options);
candidates = DetectBifurcation(data,s,detectorOptions);

% After
[M,lambda,V,d] = floquet.computeFDM(z,para,options);
candidates = floquet.detectBifurcations(data,s,detectorOptions);
```

For workflows, replace hand-added shared-script paths with
`floquet.workflow.*`. Keep experiment-specific direction resolvers and
validators in the experiment package; they are configuration callbacks, not
reasons to duplicate the workflow engine. Remove any call to the retired
`floquet.setup` function: adding `floquetRoot` is the complete setup.

## Implementation ownership

Reusable code is divided by responsibility:

- `+floquet/*.m` owns the public scientific functions;
- `+floquet/+internal` owns reduced-map, event, tracking, option, and
  provenance details;
- `+floquet/+workflow` owns the public five-stage controller;
- `+floquet/+workflow/+internal` owns stage execution and artifact-chain
  validation;
- `+floquet/+io` owns canonical-analysis projections and dataset loading;
- `+floquet/+gui` owns the workbench and plots.

Tests use the same qualified names as production callers. No test or reference
experiment should add a compatibility directory or depend on an unqualified
Floquet function being visible.

## Workflow configuration migration

Current workflows use:

```text
SchemaVersion        = floquet-workflow-config-v2
ArtifactLayoutVersion = numbered-artifacts-v1
```

Legacy v1 configurations use explicit artifact paths and may omit a schema.
Loading them is read-only and never rebases those paths beneath a new
`ExperimentRoot`.

The supported cases are:

1. **Empty v1 config, no artifacts or checkpoints.** Convert explicitly:

   ```matlab
   [config,newFile,metadata] = floquet.workflow.migrate( ...
       oldConfig,struct('SaveConfig',true, ...
       'ConfigFile',newConfigFile,'Overwrite',false));
   ```

2. **Nonempty v1 artifact chain.** Preserve it for historical inspection and
   create a new v2 workflow root for recomputation. It is not rewritten.

3. **Any v1 checkpoint.** Do not resume it. The clean-root implementation,
   evaluator identity, and checkpoint fingerprint differ. Start a v2 scan or
   continuation checkpoint.

4. **Current v2 config.** Run and inspect it through
   `floquet.workflow.runStage` and `floquet.workflow.inspect`.

This is a hard scientific boundary, not only a filename change. Silent resume
or path rebasing could attach current provenance to computation performed by a
different evaluator and layout contract.

## Completed analyses and datasets

`floquet.inspectAnalysis` can inspect supported completed artifacts without
recomputation. A completed v1 analysis remains historical, read-only evidence;
it does not acquire v2 production authority by being loaded.

The nine checked-in files under `reference_data/viewer_datasets` remain
reusable visualization datasets. Each validates as schema 1.0 and records the
production `reduced-poincare-fdm-v2` evaluator; the stored reduced matrices,
internally solved event times, acceptance masks, and eigendata therefore do
not need to be recomputed solely because the directory was renamed. These
files are still derived, non-authoritative views rather than canonical Stage-1
artifacts, and their historical screening annotations must not be the sole
source for refinement or branch switching.

Use `floquet.io.exportDataset` to derive a current viewer cache from a
canonical analysis. The export must preserve the accepted/rejected masks,
tracked spectra, candidate metadata, and provenance; it does not rerun finite
differences or redetect candidates.

Schema 1.0 support is deliberately read-only. No current writer emits that
schema. `floquet.io.loadDataset` accepts it solely so the nine frozen viewer
datasets remain inspectable, forces `scientific_authority=false` in memory,
and labels the result as a historical diagnostic cache. New exports use
schema `1.1-analysis-view` and must originate from a canonical analysis.

## Scientific difference from historical `FDM_v2`

The old result is not equivalent merely because both outputs are called
Floquet multipliers. The historical implementation may differ in one or more
of these ways:

- differentiating a full state or algebraic residual instead of the reduced
  apex return map;
- retaining the apex-normal coordinate;
- including or manually perturbing event-time variables;
- using one-sided or single-step differences;
- applying a timing response different from the production event solver;
- omitting periodicity, section, timing, topology, or convergence rejection;
  and
- detecting untracked near-target values by a distance threshold.

Clean-root v2 uses the 12 independent section coordinates, re-solves timing at
every perturbed state, validates multiple step levels and both one-sided
derivatives, tracks modes across reliable adjacent intervals, and requires a
persistent signed crossing. A numerical disagreement with old `FDM_v2` is
therefore not automatically a regression. Compare map definitions, dimensions,
accepted point masks, event topology, finite-difference convergence, and mode
tracking before comparing spectra.

## Reference-experiment compatibility

The directories under `reference_experiments` were reorganized into the same
numbered evidence layout for consistent inspection. They are intentionally
labeled by `reference_experiment_config.mat`, not by a generic writable
`workflow_config.mat`.

These packages are targeted retrospective reproductions. Some use known local
windows, repeated-kernel symmetry resolution, or held-out historical daughter
branches. They demonstrate that the reusable numerical components reproduce
specific prior results, but they do not satisfy the parent-only information
barrier of a new blind workflow and are not generally resumable through
`floquet.workflow.Session`.

To analyze a new branch, create a fresh workflow or copy
`templates/new_branch_workflow`. Do not rename a reference package's config
to make it appear generic.

## Completed API retirement

Repository-wide caller searches found no use of the removed global names
outside this Floquet-v2 tree. The bundled tests and reference scripts were
migrated to qualified package calls before the adapter directory was removed.
External scripts that still call an old global name will now fail immediately
instead of silently acquiring a compatibility implementation; update them with
the mapping above.

The package API, numbered artifact schema, and dynamics-core boundary are the
long-term contracts. Historical visualization caches remain nonauthoritative
data and are not part of the numerical API contract.
