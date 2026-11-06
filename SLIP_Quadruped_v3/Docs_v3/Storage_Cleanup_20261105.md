# v3 storage consolidation — 5 November 2026

Cleanup and verification are complete. The final v3 tree contains **610 files / 999,240,521 logical bytes** (about 999.24 MB decimal). The approximate 500 MB target is not met for the whole tree: **507,654,286 bytes** remain in historical catalogues and three uncertain raw snapshots. Excluding that historical category, the retained working content is **491,586,235 bytes**. No uncertain scientific payload was discarded to meet a size target.

## Measured result

The baseline below was taken immediately before the final administrative pass, after native conversion had closed. It is not the start of the whole multi-phase cleanup.

| Measure | Before final retirement | Final, including this report |
|---|---:|---:|
| Regular file names | 1,509 | 610 |
| Named logical bytes | 4,084,550,181 | 999,240,521 |
| Unique device/inode pairs inside v3 | 1,508 | 610 |
| Logical bytes counted once per in-tree inode | 4,079,104,688 | 999,240,521 |
| Allocated blocks counted once per in-tree inode | 4,134,293,504 | 1,000,513,536 |

The final pass retired **910 file names / 3,088,759,536 logical bytes** and created the selected-method ZIP and final ledger. Earlier retirements are recorded in the same ledger; their totals should not be added blindly across phases or hardlinks. Physical free-space reclamation was not measured. External hardlinks, filesystem clones/compression, snapshots and staging may retain allocation. 16 retained names still have multiple links, although the final in-tree inode count equals its file-name count.

| Final category | Logical bytes |
|---|---:|
| Published C1 solution MATs: two current PK cores, 43 partials, five unmatched | 6,944,586 |
| Historical catalogues plus three raw exceptions, detailed below | 507,654,286 |
| C1 method/source archives | 1,829,432 |
| Other C1 essential proofs, six APIs and metadata | 66,111,815 |
| Content outside C1, including this report | 416,700,402 |

The four framework directories contain **1,960,043 bytes of MATLAB source**. The existing P1/P2 datasets account for 335,879,535 bytes; the separate existing `Audits_v3` evidence accounts for 70,736,447 bytes. These are distinct from framework code. Unrelated six-file `Tests_v3` content (59,934 bytes), other edits, and the 6,884,080-byte production-study example were left unchanged.

## Usable methods and results

The canonical reusable function is `3_Numerical_Continuation/2_Continuation_Algorithms/ContinuePeriodicBranch_v3.m`. It preserves coupled state/energy correction and the original nine PSS checks. Its direct source formats are native Branch schema 2 and Essential schema 4; WorkingCore29 remains a separate viewing/results format. Supported native apex charts, complete BL1 policy and certain one-flight scope, optional PK whole-flight check, restart and failure contracts are documented in the [usage guide](Reusable_Branch_Continuation_v3.md).

Only six loose C1 runtime APIs remain: `RunC1Continuation_v3`, `ReadC1WorkingCoreSetSnapshot_v3`, `PKFlightPointCheck_v3`, `CheckC1PKOrbitFlights_v3`, `CheckC1PKFlightInterval_v3`, and `AllFlightClearanceBounds_v3`. The legacy shim clearly refuses retired default budgets; the public engine uses a fresh bounded invocation. Selected final scientific/consolidation methods are preserved once in `Research_v3/C1/Methodology_20261030/Selected_Final_Methods_20261105.zip` (28 members, 202,131 bytes), with readback hashes in the ledger. Existing source/compatibility packs remain.

Published C1 data locations:

- `Compact_Exports_20261030/PK15h_20261104_FinalCurrentWorkingCoreSet01/`: frozen LONG core 1,275,419 bytes and SHORT core 1,070,142 bytes, byte-for-byte unchanged.
- `Results/Partial_Components/`: 43 Essential MAT files, 4,438,595 bytes, with catalog and role evidence.
- `Results/Condensed_Connected_Unmatched_20261105/` and `Results/Condensed_Private_Results_Unmatched_20261105/`: two plus three unmatched stores, 160,430 bytes.
- `Audits/`: essential numerical resolution, study, closure, validation, timing and storage authorities.

Saved admission flags remain historical. A new continuation segment performs its declared literal source intake. The two frozen cores still exceed the strict **554,305-byte per-file** target; no strict-cap success is claimed. They already omit dense trajectory/Root/FD tapes and retain literal cores, parameters, policy/section, identities, status and typed relation evidence. Their small working exception was retained rather than redesigning the frozen format.

## Historical custody and limits

The following files are under `Research_v3/C1/Audits/`. They are historical retention, not additional current branch solutions or newly validated ancestry.

| Retained store | Bytes | Scope |
|---|---:|---|
| `V3_Historical_Essential_Audit_Facts_20261105.mat.parts/` | 303,226,596 | Seven parts plus manifest, restoring the exact original MAT; 464 sources: 419 projected historical observations, 41 exact-byte snapshots, three raw exceptions and one intentionally kept finite-resolution authority |
| `V3_Remaining53_Essential_Native_Facts_20261105.mat` | 25,480,251 | 36 previous projected rows unchanged; 17 exact-byte entries (four previous holds plus source slots 41–53) |
| `PK_0193_GateA_Pilot_GateAPilot01_20261029.raw.mat` | 101,066,440 | Final-fact cap reached; no recovered producer contract proves that the small summary supersedes this raw snapshot |
| `PK_Round_Start_20261027.mat` | 52,162,473 | Structural visit bound reached; original retained |
| `PK_Unit_Height_From_Reference_PKUnitFromRef01.raw.mat` | 25,718,526 | Unknown embedded `MException` content; original retained |

The 41 exact-byte inputs total **233,485,233 original bytes** before catalogue compression. Native independent `fread` copies, source SHA/length checks and whole-catalogue readbacks passed. Their original MAT streams can be restored and checked before an appropriate historical reader is used. This provides byte custody, not current runtime compatibility, periodicity, qualification or ancestry. The three raw exceptions total **178,947,439 bytes** and remain explicitly protected.

Known dense diagnostic/runtime/iteration detail was omitted under the declared projection contracts. Literal core29/p/q, policy/section, saved gates, selected final matrices and pending/transaction facts were retained; unknown payloads were held or copied exactly. This is **not a lossless archive of every old execution tape** and does not promise that retired private workflows can still run. No new Root, map, replay, classifier or physical branch-search campaign was performed during final conversion/retirement.

## Executed checks and accounting

The public-function [validation report](Reusable_Branch_Continuation_Validation_20261105.md) records two fresh source intakes and exactly two new PK correction services across restart, callback error/mutation custody, retired-origin resume, exact controller restoration, mismatch refusal and unknown-intent HOLD. Strict PSS services took **85.594 and 85.956 seconds**. The sub-five-second target was not achieved; there is no measured v2 speedup claim.

The saved-data smoke loaded representative frozen-core, relocated Essential and unmatched records. Public condensation preserved four literal cores and **two earned P edges**, reducing 75,155 to 38,359 bytes in 11.332 seconds. The body took 309.903 seconds and passed. Concise validation/smoke/timing authorities remain; temporary test data were removed.

Main historical conversion finished at cursor 465 with source posthash true. The 64 MiB projection cap failed with completed returned stages preserved; measured scientific-head reduction and an explicit capacity-only increase to 128 MiB then completed the scan. The final two byte-custody groups used an explicit 512 MiB capacity bound and completed in 1,271.286 body seconds / 1,277.57 process seconds. That is storage-only cost, not continuation performance. No 64 MiB final-audit-cap success is claimed.

`Audits/V3_Final_Cleanup_Authority_20261105.json` binds actual closed-worker observations, native coverage and protected references. `Audits/V3_Final_Cleanup_Ledger_20261105.json` records the reviewed 905-file pass, exact five-log consolidation, 910 actual removals, original 185-reference check and post-cleanup 180-reference protected set. The cleanup-phase protected SHA/size checks and 28 archived member hashes passed. Exact log bytes are retained in the ledger; no loose log remains. No owned `.work` directory, temporary stage or test payload remains in C1. The unrelated 29-day Desktop MATLAB session was untouched.

## GitHub storage and restoration

GitHub blocks ordinary Git files larger than 100 MiB (104,857,600 bytes).
The 303,225,245-byte historical audit catalog is stored as seven opaque byte
parts, each at most 48 MiB, with an ordered SHA256/length manifest. Its logical
MAT content is unchanged. The 101,066,440-byte GateA snapshot is 96.38 MiB,
below the hard limit. Files above 50 MiB can still produce a size warning;
see [GitHub's file-size guidance](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github).

The core PK and partial-branch files remain ordinary MAT files. Routine
continuation still writes one branch MAT and its checkpoint; this transport
applies to the closed historical catalog. To inspect that aggregate, run these
commands from the repository root:

```sh
python3 SLIP_Quadruped_v3/4_Solution_Management/ByteArchive_v3.py verify \
  SLIP_Quadruped_v3/Research_v3/C1/Audits/V3_Historical_Essential_Audit_Facts_20261105.mat.parts/manifest.json

python3 SLIP_Quadruped_v3/4_Solution_Management/ByteArchive_v3.py restore \
  SLIP_Quadruped_v3/Research_v3/C1/Audits/V3_Historical_Essential_Audit_Facts_20261105.mat.parts/manifest.json \
  SLIP_Quadruped_v3/Research_v3/C1/Audits/V3_Historical_Essential_Audit_Facts_20261105.mat
```

The utility uses only Python's standard library and copies opaque bytes; it
does not interpret MAT data. Restoration checks each part and the complete
original SHA256/length, reads back the staged result, and refuses an existing
output. The manifest and parts are kept together. Git attributes preserve
binary part bytes and LF manifest line endings across platforms.

The restored oversized MAT is ignored by Git. It can be removed after
inspection because the parts retain it exactly. The cleanup ledger's
`lossless_file_transports` entry maps the original native proof reference to
the current physical parts. Earlier cleanup actions and native proof hashes
remain historical records. The original oversized file is removed only after
a complete actual restoration and independent whole-file SHA check pass;
the verified temporary restoration is then removed as well.

The actual 303,225,245-byte restoration passed an independent whole-file SHA256 comparison (`3a9f422614bf074b89bda5b03012f49abcbd4d1aa91ceaa55ba8f980813a5b44`). All 21 synthetic transport checks passed, including corruption, missing parts, traversal, existing/concurrent output refusal, partial-publication cleanup and Finder metadata. The oversized original and temporary restoration were then retired. The current physical protected set has 187 references; all match their recorded hashes. The prior 910 cleanup actions remain unchanged, with the later lossless transport recorded separately. No Git-visible worktree file exceeds 100 MiB. The Git index and commit history were not changed.

Commit the manifest, all seven parts, restore utility, and the v3 `.gitattributes`/`.gitignore` together.
