# Working-tree cleanup audit

Cleanup requested on 2026-10-07. The user explicitly permits changes everywhere except `SLIP_Quadruped/`. The initial Git HEAD is `b54aa77e3f7af269101477a06c93d5ee60da4353`. No commit or push was made.

## Retained material

- All distinct research MAT/JSON results, initial states, complete trajectories, finite-difference matrices, prediction files, rejected/terminal outcomes, family checkpoints, graph and figures.
- All 18 copied P1/P2 source fixtures and all 528 original legacy reference files/links inside `SLIP_Quadruped/`.
- The production simulation, orbit correction, continuation, Floquet/classification, graphics and GUI code; executable examples and scientific audit tools.
- Historical baseline/final suite summaries, analyzer CSV, launcher/environment/LaTeX evidence, physical/delayed-boundary/pronk audit evidence, matched GUI screenshots, workflow/serialization/recording evidence, saved GUI solution/checkpoint and sample media.
- Distinct prior pronk reports/checkpoints and older root pronk results, labeled superseded historical research. Only 18 byte-identical archived result copies were deduplicated.

## Removed material

V3 and repository characterization suites, synthetic test fixtures, unit-test/analyzer runners and v3 test CI; raw JUnit/test-result MAT files and temporary test/debug logs; temporary GUI serialization/recording check drivers and a format-comparison copy; historical raw Round4 test outputs and macOS folder metadata; superseded GUI screenshots; MATLAB preferences/browser caches and Python bytecode. Historical counts retain their original qualifications (188/190 passing, two pre-existing legacy-manifest failures, one incomplete), and are not a newly executed suite.

The Round 1 audit runner retains its numerical/static/integrity checks and records that characterization tests were removed and not executed. Outside-v3 changes are explicitly recorded by path and before/after SHA256 in the JSON manifest. The protected-tree verifier permits only those exact recorded changes and continues to reject any change inside `SLIP_Quadruped/`.

## Lossless result compression

MATLAB R2025b loaded each of 51 MAT-v7.3 artifacts, saved the complete variable set with `save(...,'-struct','data','-v7')`, reloaded it and asserted `isequaln(data,after)` before replacing the original. No result fields or diagnostics were discarded. Total bytes across these files changed from 716,583,534 to 34,455,733. In particular `full_floquet.mat` changed from 357,391,654 to 15,371,053 bytes. Its recorded unreliable unrestricted derivative remains unreliable; compression supplies no new stability claim.

[Artifact compression](artifact_compression.json) and its [MATLAB log](artifact_compression.log) record the actual comparisons. Research drivers now use compressed MAT-v7 for these outputs. Source fixtures and already compressed family/GUI checkpoints were not repacked.

## Verification

The final size scan uses the conservative threshold **100,000,000 bytes**, excludes `.git` internals, and includes retained tracked/untracked/ignored working files. Final counts, largest file and replay/protection results are recorded in [the cleanup manifest](Working_Tree_Cleanup_v3.json). The original before-cleanup tree contained 3,483 files and 1,093,028,738 bytes.

[The retained audit recipe](../audit_commands.sh) independently replays accepted physical solutions and regenerates schema-validated research indexes, figures and reports. [Protected verification](../baseline/protected_verification.json) distinguishes the unchanged legacy reference from the eight authorized cleanup changes outside v3; [fixture verification](../baseline/fixture_verification.json) checks all 18 source copies. Temporary runtime folders are ignored and removed again before handoff.

Final handoff scan: approximately 241 MB of retained files; largest file `SLIP_Quadruped_v3/Research_v3/runs/full/solution_index.json` is 15,547,992 bytes. No working file reaches 100,000,000 bytes. All 79 retained physical solutions replayed successfully with maximum closure 7.242353451e-11; saved states/modes/parameters/energy/period/drift/event words/gait labels remain exactly equal to the pre-cleanup index.
