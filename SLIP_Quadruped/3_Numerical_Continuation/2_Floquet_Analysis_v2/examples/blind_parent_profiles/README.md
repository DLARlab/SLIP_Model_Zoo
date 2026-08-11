# Blind parent-branch workflows

These packages treat each input as an unlabeled periodic-solution branch. They
run the reusable Floquet-v2 stages over the complete parent branch before any
candidate is selected or any independent reference data are considered.

The historical experiment packages remain separate as frozen targeted
regressions. These blind folders reference the existing Roadmap parent MAT
files at runtime; they do not copy branch data, historical results, or reusable
MATLAB functions.

| Workflow | Parent input | SHA-256 | Initial branch-switch policy |
|---|---|---|---|
| `PK_parent` | `PK_20_2.mat` | `45835bb5024b1dc9b875c7b8f7b205769f537a4ff4144c763058537f44dbf401` | Repeated-space callbacks deliberately unset; unresolved groups are recorded and stop before arbitrary mode selection. |
| `BE_parent` | `BD1_20_2_BE.mat` | `3ab8e1f47ea788a95faa541bed9bf02ad53b5e4107f5601a19f96f5464b87d0c` | Simple modes use topology-derived one-sided timing and oriented-amplitude correction. |
| `BG_parent` | `BD1_20_2_BG.mat` | `ccff690f6a6b468ee623259f68dfe71dc077dcf552e35869324bc39c132b2be0` | Simple modes use topology-derived one-sided timing and oriented-amplitude correction. |
| `FG_parent` | `BD1_20_2_FG.mat` | `231895dbb454f914a6f9bd269d2108e761728f3e1cc7a5548be7f0b6a1b6cbf3` | Simple modes use topology-derived one-sided timing and oriented-amplitude correction. |
| `HE_parent` | `BD1_20_2_HE.mat` | `c3f7bd53f05729cada19cdb8b074e91d6861849d13c0555b2e5a1812a532c892` | Simple modes use topology-derived one-sided timing and oriented-amplitude correction. |

These Roadmap source files were verified byte-for-byte against the
corresponding frozen parent copies. Each config stores the same value in
`ExpectedParentSHA256`, and Stage 1 rejects the run if the Roadmap bytes no
longer match; the table is therefore human-readable provenance, not the only
guard.

## Information barrier

Stages 1 through 4 may read only:

- the parent branch referenced by its uniquely named
  `<GAIT>ParentWorkflowConfig.m` function;
- numerical tolerances and workflow controls;
- model symmetry or event-topology rules declared independently of any
  desired outcome.

They must not read or encode expected crossing columns or coordinates,
expected gait labels, daughter paths or indices, historical direction vectors,
or hand-selected scan windows. `Selection.CandidateIDs` therefore starts empty
and `Selection.Confirmed` starts false. Stage 2 remains locked until the
frozen candidate inventory has been reviewed and confirmation is explicit.
Freeze `artifacts/01_discovery/floquet_analysis.mat` and its CSV inventory before
selecting any IDs, and base selection only on that frozen numerical evidence.

The `Validation` field is intentionally empty. Independent references, if
used later, belong in a separate Stage-5-only configuration copy and must never
be passed to discovery, refinement, seed search, or continuation.

Execution is deliberately staged: run and freeze discovery; select stable
candidate IDs; run and inspect refinement plus seed search; enable continuation
only for accepted same-ray seed pairs; then validate from the separate config
copy. Stage 4 starts with `Confirmed=false` and empty `RaySelections`. Use
`floquet.workflow.inspect(config).Continuation.RayCatalog` after Stage 3 and
explicitly bind each chosen
two-attempt pair to the returned seed SHA before enabling continuation. Do not
invoke disabled continuation merely to complete a five-command sequence
because that writes an immutable dry-stop inventory. Replacing a stage artifact
requires `OverwriteResults=true`; replacing existing per-ray branch files
requires both that gate and `Continuation.Overwrite=true`.

## One reusable command sequence

Add the Floquet-v2 root and one profile folder, construct the uniquely named
configuration once, and use the package workflow API. For example:

```matlab
addpath(floquetRoot)
addpath(fullfile(floquetRoot,'examples','blind_parent_profiles', ...
    'BE_parent'))
config = BEParentWorkflowConfig();

[analysis,state,config] = floquet.workflow.runStage(config,1);
% Review the frozen Stage-1 MAT/CSV evidence before choosing IDs.
[config,state] = floquet.workflow.confirmCandidates(config,candidateIDs);
[refinement,state,config] = floquet.workflow.runStage(config,2);
[seeds,state,config] = floquet.workflow.runStage(config,3);
% Review Stage 3 and construct SHA-bound raySelections.
[config,state] = floquet.workflow.confirmRays(config,raySelections);
config.Continuation.Enabled = true;
[daughters,state,config] = floquet.workflow.runStage(config,4);

validationConfig = config; % only this copy may receive held-out references
[validation,state] = floquet.workflow.runStage(validationConfig,5);
```

Replace `BE` by `PK`, `BG`, `FG`, or `HE` and use that profile's matching
constructor. Candidate and ray confirmation update the in-memory config but
do not silently rewrite a MAT file. Save `config` explicitly if the choices
must persist between MATLAB sessions, or use the GUI's atomic confirmation
persistence.

## Checkpoint semantics

Each config writes `checkpoints/floquet_scan_checkpoint.mat` every five
completed points. `ResumeFromCheckpoint` is evaluated as
`isfile(checkpointFile)`: a first run starts clean, while an interrupted run
resumes automatically. A successful full scan deletes its checkpoint after
the final analysis is assembled. An incompatible checkpoint is rejected rather
than silently reused.

Stage 4 has a separate `checkpoints/daughter_continuation_checkpoint.mat`. It saves
the ordered, SHA-bound ray plan before and after each ray. A GUI control callback
may pause only between rays; resume re-hashes every completed branch file and
requires unchanged seed bytes, selections, and continuation options.

## Canonical versus GUI data

The canonical numerical authority is the Stage-1 `floquet_analysis.mat`. A GUI
dataset is optional and must be derived from that frozen artifact; it is not a
required input and is never a second detector authority.

Each child README identifies its constructor and frozen parent. The public
operations live in `floquet.workflow.*`; their implementation is owned by
`+floquet/+workflow/+internal/`. Former unqualified global names have been
retired; add only the Floquet-v2 root and use the qualified package APIs.
