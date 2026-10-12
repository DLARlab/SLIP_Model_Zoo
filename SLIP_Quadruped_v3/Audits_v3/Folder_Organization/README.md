# Runtime path compatibility

`locations.json` resolves the earlier module names and relocated diagnostic datasets to retained files. Core modules live in the four numbered implementation folders. Stale aliases to removed experiment directories were pruned.

`source_relocations.json` retains only journal records whose `after_sha256` matches the current source. The one required original `V3OutputPath_v3.m.txt` remains for the strict byte-hash check in `V3HashMatches_v3`. Edited numerical sources are not silently certified by an old relocation record.

The complete earlier journal and final historical research reports are indexed in [selected scientific evidence](../Scientific_Evidence/README.md). Historical probe references in those records identify deleted run intermediates; they are not active runtime paths.
