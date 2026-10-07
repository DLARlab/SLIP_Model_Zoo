# v3 folder organization audit

The October 7 organization follows the user's requested legacy-style functional
layout. All numerical modules remain MATLAB-native. The two study directories
are `P1_Single_Flight_Phase_Continua` and
`P2_Double_Flight_Phase_Continua`, with branch datasets directly in their roots
and supporting evidence under independent `Bifurcation_Audits/` directories.

## Preserved evidence and location compatibility

[before_manifest.json](before_manifest.json) records 2,285 files from the
working v3 tree before organization, including existing uncommitted research.
[locations.json](locations.json) records retained file locations, historical
aliases and directory relocation rules. Scientific MAT/JSON/FIG/PNG bytes
remain unchanged; their embedded original paths and source hashes are retained.
`V3Path_v3` resolves those recorded paths for native readers and writers.
`V3Dir_v3` resolves saved wildcard searches, including new output within moved
task directories. Flat continuation datasets retain their original task IDs
in the branch comparison reader.

The 68 schema, adapter, dynamics, simulation, orbit, numerical, stability and
graphics source files were moved byte-for-byte. The 112 path-bound source
edits are recorded separately in
[source_relocations.json](source_relocations.json). Their original bytes are
archived as `.m.txt` under `Original_Path_Bound_Sources/`, so MATLAB path setup
cannot execute or shadow them. The edits resolve input/output filenames,
module bootstrap paths, moved GUI default paths, original reporting IDs,
historical source checks and the explicit cleanup protection epoch described
below. `RoundSHA256_v3` always hashes actual bytes.
`V3HashMatches_v3` accepts either exact bytes or an explicitly journaled source
epoch after checking both the current source and archived original hashes.
The journal alone does not prove numerical equivalence; the unchanged numerical
core and actual loading/replay checks provide the relevant additional evidence.

Ten new convenience datasets collect already accepted signed samples, bridge
points and standing cycles. They contain `branch` and GUI-compatible
`solutions`, with JSON summaries and original source provenance. The
[export manifest](../Organized_Branch_Exports_v3.json) records their hashes,
counts and meanings. Exporting them added zero shooting simulations or new
campaign records. Signed samples are not ten distinct continued branches;
opposite opposed-spread signs can be phases of the same labeled cycle.

## Executed verification

[report.json](report.json) records the native MATLAB preservation audit:

- All 1,791 retained scientific MAT/JSON/FIG/PNG artifacts match the before
  manifest, and all 68 numerical core source files match their original bytes.
- Both research checkpoints retain their original hashes, statuses, counters,
  task queues and budgets. The full campaign still has 227 unfinished tasks
  and status `total_budget_exhausted`.
- All seven saved solver gates still reference exact current numerical source
  hashes. Six historical full-profile continuation wildcard locations resolve
  to the current study evidence.
- The 112 changed path-bound sources match their archived and current epochs.

[Functional_Loading/summary.json](Functional_Loading/summary.json) records
actual GUI-controller loading of 23 PK continuation points, ten signed samples,
five standing campaign records and four standing theory records. The direct P1
catalog has 17 loadable MAT datasets. Independent PIP and PK replays through
the shared periodic solver passed with full closures approximately
`3.0611e-11` and `3.0269e-11`; tolerances and full diagnostics are retained in
[known_orbit_replays.mat](Functional_Loading/known_orbit_replays.mat).
These are organization checks, not added campaign continuation progress.

[Final_Path_Checks.json](Final_Path_Checks.json) records the final MATLAB syntax
and live mapped-directory discovery checks. The temporary discovery probe was
removed. No general unit-test runner or test suite was recreated.

## Cleanup and protected files

[removed_files.json](removed_files.json) records only Finder caches,
count-only test summaries and redundant static/schema/export-check output.
The mixed historical report was renamed to
[Round4_Prechange_Audit_v3.md](../../Docs_v3/Round4_Prechange_Audit_v3.md), retaining
platform, preservation-baseline and pre-existing missing-manifest evidence.
Numerical validation, failed candidates, derivative failures, replay histories,
source fixtures, GUI recording evidence and actual bifurcation audits remain.

[protected_paths.json](protected_paths.json) verifies the 534 retained files
outside v3 against the earlier research reference. Ten historical paths were
already absent at the start of this task; they are listed explicitly and were
not restored. The old research protection manifest remains unchanged.
[protection_epoch.json](protection_epoch.json) explicitly registers the current
534-file working state. The native protection driver checks the original
manifest hash, the exact ten absent paths and every retained reference checksum
before using this epoch; it continues rejecting new, missing or changed
protected files. [protected_verification.json](protected_verification.json)
records its successful actual execution. This avoids false violations from
earlier cleanup without replacing the original ledger. A full campaign
invocation was not used for organization verification; its exhausted budget
and checkpoint remain unchanged. [root_cache_removal.json](root_cache_removal.json)
records the repository-root Finder cache removed under the latest cleanup
instruction. Nothing inside `SLIP_Quadruped/` was changed.

[working_tree_scan.json](working_tree_scan.json) records the final size and
cache scan. Retained files are below the requested 100 MB limit. Legacy caches
inside the protected `SLIP_Quadruped/` folder are intentionally untouched.
