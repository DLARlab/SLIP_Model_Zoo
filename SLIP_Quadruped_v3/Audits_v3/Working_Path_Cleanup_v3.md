# Working-path cleanup — 2026-10-11

The v3 working tree was reduced from **111,435 to 319 files**, retaining 101 MATLAB core functions/classes, six main datasets, thirteen diagnostic datasets, saved raw results, final figures/matrices and compact audits. About **32.2 GB** was removed. `SLIP_Quadruped` is byte-identical to its cleanup baseline (528 files).

Git now reports **213 added/modified files** and **2,279 tracked deletions** (2,492 total, down from 109,091). The deletions remove already committed debris and necessarily appear in this cleanup commit; they are not new implementation files. Unrelated pre-existing changes outside v3 were preserved.

## Retained implementation and results

- Four required solver/I/O helpers were moved byte-for-byte into the numbered core modules. Path initialization and root discovery no longer depend on campaign drivers. Examples use the retained native PK dataset.
- All six main and thirteen moved diagnostic MAT datasets match their pre-cleanup SHA256. P1/P2 catalogs and latest publication audits remain. All 27 historical raw-dataset aliases still resolve with exact SHA256 checks.
- [Selected scientific evidence](Scientific_Evidence/README.md) contains **393 exact original files in eight bundles**, all below 100 MB: direct admission/service/two-fine proofs for thirteen diagnostic points, final physical Floquet matrices, restricted attachment mathematics/results, final search/failure audits and historical reports. The [manifest](Scientific_Evidence/manifest.json) locates each original file.
- Legacy branch copies and native-coordinate initial guesses remain separately labeled as unaccepted. Core model, solver and contact-policy documentation remains available.

## Removed material

The `Research_v3` run trees, per-evaluation probes, acquisition roots, repeated source snapshots, superseded epochs/backups, launcher scripts, logs, GUI smoke outputs/recordings, test-only functions and caches were removed. No archive of the full discarded workspace was retained. Historical record paths may therefore point to removed intermediates; the complete raw proof sets are retained for thirteen published diagnostic points, while the 111-record final checkpoint preserves its broader historical inventory.

## Verification

Native MATLAB R2025b Update 5 passed a fresh-start check with `Research_v3` absent: all 19 datasets load, P1/P2 each list three main datasets, stored classification/color and animation frames work, diagnostic points create no ordered curves, all 27 raw aliases validate, and the GUI loads/plots datasets and applies separate axis limits. Hidden GUI shutdown took **0.41 seconds**, with no owned timers left behind. Native default example correction passed with residual **2.9611e−10**.

The check also reproduced and verified the path-resolver fix for JSON arrays decoded as cells when object fields differ in order or optional fields. Independent byte verification passed for all 393 archive entries. No working-tree file is 100 MB or larger, and no v3 cache files remain. Verification scripts were kept outside the repository.

The scientific conclusions are unchanged: the requested principal BG/BE/FG/FE/HG/HE/GG/GE and P2 B2/F2/G2 networks remain unresolved. Cleanup performs no new numerical admission or ancestry certification.

[Machine-readable audit](Working_Path_Cleanup_v3.json) includes exact hashes, native check results and protected-file verification.
