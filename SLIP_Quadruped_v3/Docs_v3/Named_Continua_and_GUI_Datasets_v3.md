# Named continua and GUI datasets

**C1 identifies P1; C2 identifies P2.** A C number is the user's continuum number. Source groups, numerical samples and separately continued components never receive another C number merely because they came from different calculations.

Names follow `C<continuum number>_<gait>_<linear stiffness>_<torsional stiffness>_<pitching inertia>.mat`. The baseline physical parameter vector is `[10;10;20;20;1;1;0;0;2;.5]`: the tokens `10_20_2` are `p(1)=p(2)`, `p(3)=p(4)`, and `p(9)`. A single stiffness token requires equal front/hind stiffnesses. Decimal tokens use `p`. A registered F2 source region adds `_L` or `_H` **after** the parameters, for example `C2_F2_10_20_2_L.mat`.

A common continuum prefix is an organizational convention. It does not establish that disconnected source groups or signed components have been joined. Record counts are not distinct-cycle or gait-family counts.

## Stored native datasets

| Dataset | Actual evidence scope |
|---|---|
| `P1/C1_PK_10_20_2.mat` | All retained PK publication groups at the exact parameters. Their original labels, signed samples, source hashes, arclengths and separate ordered components remain intact. |
| `P1/C1_USBL1_10_20_2.mat` | Actual unclassified standing single-flight source17 sample(s); USBL1 is descriptive. |
| `P1/C1_PIP_10_20_2.mat` | Actual primitive one-flight PIP parent admitted through the original nine service gates. Later independently admitted analytic-family samples retain their own source group and sampling provenance. |
| `P2/C2_OSBL2_10_20_2.mat` | Actual unclassified opposed-spread standing BL2 records. Resonance n0/n1, signed phases, samples and ordered components remain separate source groups. OSBL2 is not B2, F2 or G2. |
| `P2/C2_PIP_10_20_2.mat` | **Exact byte copy** of the latest C1 PIP dataset, published as the shared parent reference. Its content retains C1 identity and actual one-flight classification; this creates no two-flight admission or ancestry edge. |

The publisher updates these active files only after numerical writers stop. The folder's current `Branch_Catalog_v3.json` is authoritative for the completed publication. Unsupported requested gait names are not emitted from legacy predictors or nominal targets.

### P1 PK source groups

The `source_groups` metadata inside C1_PK retain stable provenance keys:

- `P1/imported_PK`: both actual continuation directions, with their verified inherited prefixes.
- `P1/restricted_daughter_1` and `P1/restricted_daughter_2`: historical restricted signed samples and local continuation components.
- `P1/PIP_n0`: the original PIP n0 PK neighborhood.
- `P1/PIP_low_energy`: its original local neighborhood and separately audited imported-PK bridge.
- `P1/signed_PIP_2` and `P1/signed_PIP_3`: original and later strictly qualified signed samples and daughter components.

Each group owns explicit `record_indices` and `component_indices`. Each record/component also stores `source_group_key`. The GUI draws each verified ordered component separately; independent signed samples remain scatter points. Opposite signs, directions, unrelated source groups and nonmatching prefixes are never joined by publication.

The PIP2 and PIP3 study audits link to these groups **inside C1_PK**, with their independent bifurcation audit folders. The earlier mistaken C6/C7 names are historical publication labels only.

## Actual class and geometry

New one-flight names BG/BE, FG/FE, HG/HE and GG/GE require the original accepted native base class BD, HB_front, HB_hind or GP and its measured `suspension_geometry.description` of `gathered` or `extended`. Borderline/mixed geometry is not forced into a G/E label. PK/PIP remain their original v3 names; stored classifier abbreviations remain unchanged in native metadata.

A two-flight native B2/F2/G2 label requires the actual primitive flight count and original independent acceptance, rather than a BL occurrence setting or a predictor's name. F2 L/H denotes an explicitly registered source region, separately from its native gait classification. Its original trial must bind `publication_branch_suffix` and `publication_naming_provenance` to the exact pre-map method file/SHA and matching `branch_region`. Missing or inconsistent naming evidence is reported while the admitted result remains in its scientific dataset/audit.

All new publication admissions retain the original nine service gates, exact baseline p10, registered physical domain, primitive cover one and full saved closure. Publication performs no maps, replay, correction, derivative or new admission.

## Catalog and shared-parent identity

The schema is `named-continua-catalog-v3-2`. Catalog and entries expose `continuum_id` (`C1`/`C2`), numeric `continuum_number`, gait `abbreviation`, full `physical_parameter`, and a unique `dataset_key`. Dataset keys combine the continuum, abbreviation and exact full p10; F2 region keys also include the explicit region. Matching uses this full identity, never C number alone.

Ordinary native `branch`/`summary` identity agrees with the catalog. The declared `shared_PIP_parent_reference` exception exposes C2 as the logical catalog continuum and C1 as `content_continuum_id`, with `content_dataset_key`, `copy_source_path` and `copy_source_sha256`. Source and copy are byte-identical. The shared copy refreshes **after** additional C1 PIP admissions are merged.

## Preservation and refresh

Every previous canonical dataset and catalog is preserved by exact bytes before overwrite/removal, including same-name earlier C1_PK snapshots. Per-study bytes live under `Bifurcation_Audits/Continuum_Namespace_Migration/<epoch>/prior_bytes/`. The versioned `Audits_v3/Named_Continuum_Namespace/<epoch>/relocation_manifest.json` maps **old logical path plus SHA256** to archival path. The dated naming addendum explains immutable earlier reports without rewriting their text or hashes.

The index also records already-preserved earlier `*_previous_<SHA>.mat` canonical versions and historical catalogs under `Named_Branch_Publication`, and the exact naming document saved before this correction. Those immutable bytes stay in their existing audit locations; old path and SHA distinguish them from later same-name versions.

Obsolete wrong-C filenames leave the active roots only after verified new publication. Original scientific sources/results/audits remain available. Raw source relocation uses dedicated read routing rather than treating a read alias as a write destination; immutable archival inputs must never be overwritten by a future exporter.

The native MAT files contain complete saved `solutions`, primary trajectories, states/modes/events, parameters, chart/BL occurrence, source groups and components. The GUI keeps loaded acceptance false until independent replay/correction. Each compressed MATLAB file remains below100MB.
