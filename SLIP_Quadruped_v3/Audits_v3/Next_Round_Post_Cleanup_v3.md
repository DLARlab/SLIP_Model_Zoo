# Post-cleanup repository verification

Verified on 2026-10-07 after all MATLAB numerical and saved-data analysis jobs exited. Removed only the machine-local preference/CEF caches at `SLIP_Quadruped_v3/t/`, `Research_v3/runtime/` and `Research_v3/next_round/runtime/`. The v3-local ignore file now also excludes the last path if recreated. Core code, complete copied-source fixtures, successful and failed numerical evidence, checkpoints, figures and scientific audits remain.

| Check | Observed result |
|---|---|
| Starting protected files | 544 |
| SHA-256 verification | All 544 pass |
| Current protected files | 544 |
| Added or missing protected paths | 0 |
| Working files above 100000000 bytes | 0 |
| Largest working file | 18015528 bytes |
| `git diff --check` | Pass |

The protected scan covers every existing path outside `SLIP_Quadruped_v3`, including the pre-existing untracked prompt and the complete `SLIP_Quadruped` folder. Git object storage is excluded. The two equally largest files are the saved low-energy branch audit and the validation continuation MAT file. Numerical task status remains `total_budget_exhausted`: 10804.966922625003 charged seconds, 4990 recorded evaluations as a lower bound, and 227 unfinished tasks. Cleanup introduced no new scientific simulations or source changes to the seven validated numerical engines.

Ordinary repository-management commands actually executed were SHA-256 manifest checking, path-list comparison, working-file size scans and `git diff --check`. Machine-readable evidence:

- [Protected hash checks](Next_Round_Post_Cleanup_Protected_SHA256.txt).
- [Final protected paths](Next_Round_Post_Cleanup_Protected_Paths.txt).
- [Protected path differences](Next_Round_Post_Cleanup_Protected_Path_Differences.txt), empty on success.
- [Oversized working files](Next_Round_Post_Cleanup_Oversized_Files.txt), empty on success.
- [Largest working files](Next_Round_Post_Cleanup_Largest_Files.txt).

The [native MATLAB completion audit](Next_Round_Completion_v3.md) retains branch coverage, attachment results and every unfinished task. Its recursive file count describes the snapshot before runtime-cache removal; this supplement describes the cleaned working tree.
