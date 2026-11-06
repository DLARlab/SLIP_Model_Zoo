# Branch speed sampling and naming

`SampleBranchNaming_v3` separates an admitted point's classification, a stable ordered component identity, and a modal display name. The current classifier contract is read from the second output of `GaitSemanticTable_v3` (`quadruped-gait-v3.5` after the 2026-10-13 user H/F clarification). The service never infers connectivity from a source group, filename, label, C prefix, proximity, or a plot.

## Inputs and the speed observable

The input component has a stable `component_id`, `ordered_verified=true`, explicit `connectivity_evidence`, and ordered `points`. Each point retains a label-independent `orbit_id`, the native `orbit`, and its original `admission_report`. All original nine service gates must pass, and the report must establish primitive cover one within its declared scope. Physical p10 vectors must agree exactly. Differently stored representatives are checked numerically for duplicate cycles at the same strict canonical section.

`OrbitSpeed_v3` extracts the scalar horizontal displacement using `QuadrupedSchema_v3.shared().TranslationIndex`. `stride_displacement` is a full 14-state displacement vector; dividing the whole vector does not define speed. The observables are

\[
\bar v=\Delta_x/T,\qquad U=|\bar v|.
\]

The service retains signed mean velocity, direction, primitive period, horizontal displacement, and initial-section `dx` separately. A stored multiple cannot use its full displacement with a shorter primitive denominator. It must first be reduced and independently admitted.

The default naming speed error tolerance is `1e-8` in native nondimensional velocity units. For narrow speed ranges the effective reuse/correction tolerance is further reduced to one tenth of the target-level spacing, preventing one physical point from filling two different speed levels.

## Partition and intersection plan

`BranchSpeedLevelPlan_v3` partitions one verified ordered component at signed travel reversals and resolved primitive-flight-count changes. The parent component ID survives every partition. A reversal between adjacent admitted points creates a **predictor** of zero velocity; the zero-speed cycle still requires nonlinear correction. An unresolved flight-count transition is a reported gap; the service does not interpolate across incompatible physical event topologies.

Each nonconstant partition uses exactly twenty levels including endpoints,

\[
U_j=U_{\min}+j(U_{\max}-U_{\min})/19,\quad j=0,\ldots,19.
\]

All resolved intersections at each level are enumerated, including both limbs of a fold. The piecewise continuation path only brackets roots. `monotone_edges_verified` registers the **numerical resolution scope** under which each edge has no unresolved additional extrema. An unverified edge can conceal an extra intersection even if its endpoint speeds do not bracket that level; therefore every level in the affected partition remains incomplete. A constant-speed segment at a target is unresolved, rather than arbitrarily supplying one representative of infinitely many intersections.

An isolated point or constant-speed family cannot supply twenty distinct speed locations. PIP keeps its explicit C0 exception. Such evidence remains usable as admitted points without becoming a sampled ordinary branch.

## Nonlinear correction and independent admission

Interpolation provides only an initial predictor. `CorrectOrbitAtSpeed_v3` reconstructs the declared physical section chart and return policy, then delegates to `PeriodicSolutionSolver_v3`. Return occurrence comes from the actual declared policy and saved BL-marking configuration, never from the measured flight count or a closure-minimizing choice.

`MatchingReturnSection_v3` requires equal return-policy names/configurations, BL occurrence or iterated multiplicity as applicable, and canonical section identity, geometry, orientation, boundary ownership and gauge. Sampling passes the original service policy configuration as evidence. Missing configuration or an incompatible source chart leaves the intersection unresolved; a chart transition requires a separately recorded, admitted rephase.

`RecordedReturnPolicy_v3` reads the effective delegated `options.Residual.Map.ReturnPolicy`, then the actual `correction_return_policy`, then seed metadata. Native policies and the exact `CompactResearchBranch_v3` `runtime-object-descriptor` shape are supported when every actual property is present. Restoration passes all recorded settings explicitly and checks they remain equal, including empty event-cycle leg settings. Policy names, partial descriptors and custom event callbacks without a portable closure are refused. Midpoint and speed corrections share this extraction; neither restores default settings from a policy name.

For `d` independent physical section coordinates, `SpeedConstrainedEnergyResidual_v3` solves the square system in `[u;E]`:

\[
\left[(P(u)-u)_{i\ne j};\ H(u)-E;\ \Delta_x(u)/T(u)-v_{\rm target}\right]=0.
\]

It has `d+1` equations and unknowns. `E` is free orbit energy and does not alter p10. The signed target is `direction * U_j`; the zero target handles reversals without differentiating `abs` at its cusp. The existing regular energy pivot and physical chart belong to `EnergyFamilyResidual_v3`. The observable is evaluated from every actual autonomous hybrid return, including nonperiodic but physically valid trials. Invalid chart/guard/mode/integration trials remain invalid.

The full unscaled equation vector, scaling, selector residual, energy, target/achieved speed, and signed velocity errors are exposed. Default residual scales are one in native coordinates; an explicit positive scale vector can be registered. Shared reduced root acceptance remains at most `1e-10`, and the full closure/energy/family/selector/stance defaults remain `1e-8`. A fresh independent replay must pass all nine gates. The naming helper independently recomputes speed on that admitted primitive replay and rejects a missed target.

A locally corrected orbit must remain inside the registered source-bracket neighborhood and mode chart. Failure to establish local limb membership is an incomplete intersection. Convergence of two distinct fold intersections to the same physical cycle leaves one missing; duplicate roots do not fill the sample count. This is finite numerical continuation evidence, not an analytical connectivity theorem.

## Equal-weight votes and provisional cases

`BranchNamingVotes_v3` reports all twenty votes. Qualified intersections with one common compact label give that label one vote, however many physical cycles were required. Different labels give `MULTIVALUED`. A missing or unresolved intersection gives `INCOMPLETE` and cannot demonstrate agreement among the known limbs.

The branch display name is the **unique most frequent category**. A strict majority is reported separately and is not required. Ties, a diagnostic winner (`M`, `U`, `MULTIVALUED`), or incomplete sampling leave the name provisional. The report includes mode count/fraction, majority, ties, categories, all votes, level completeness, number of actual physical orbits, per-intersection achieved errors and failures, and stable parent identities. Point labels are never overwritten by the modal name.

Ordinary point labels are `<B/H/F/G><reference G/E/M/U><primitive flight count>`, including multi-digit counts. M/U are transparent diagnostic codes and never requested G/E results. PK/PIP are explicit naming exceptions with flight metadata retained separately. The 2026-10-13 user convention is H = hind spread/fore synchronized and F = fore spread/hind synchronized; it supersedes the reversed H/F wording in the original campaign prompt and earlier contracts. Native state evidence must support each current classification; historical filenames alone never establish a label.

## Canonical catalog and identity helpers

`NamedDatasetIdentity_v3` produces C0 for a canonical PIP parent, C1 for one-flight data including PK, and C2 for two-flight data. Examples are `C0_PIP_10_20_2.mat`, `C1_PK_10_20_2.mat`, `C1_BG1_10_20_2.mat`, `C1_HE1_10_20_2.mat`, and `C2_FG2_10_20_2.mat`.

The short stiffness filename is used only when paired stiffnesses agree **and** other omitted parameters have their native common values (leg lengths 1, rest angles 0, COM fraction .5). Otherwise all ten ordered parameters appear in a `p10_...` filename with seventeen significant digits. Stable IDs also use all ten parameters with seventeen significant digits, including explicit `Inf`, independently of JSON rendering. Full parameter vectors and stable branch IDs always remain in metadata. Distinct branch identities that would share a display filename require explicit disambiguation; the migration planner rejects collisions.

Catalog entries additionally carry `physical_parameter_tokens`. `CatalogPhysicalParameter_v3(entry)` parses these ten lossless tokens, verifies agreement with the numeric vector and validates the native schema. It allows JSON `null`/NaN only at a coordinate carrying an explicit positive `Inf` token; a null without that evidence fails. MAT summaries and orbit parameters retain their exact numeric vectors.

`SharedPIPCatalogReference_v3` exposes the same canonical C0 parent in C1 and C2 catalogs by identity/path reference, creating no MAT copy or new cycle. Historical C1/C2 PIP copies remain provenance until a coherent migration preserves their original bytes and hashes. `ResolveNamedCatalog_v3` returns every matching branch for family alias `C2_B2`; this alias omits G/E and is not a unique complete gait name.

`BuildNamedContinuumDataset_v3` preserves source admissions/classifications and component separation while adding current native point classifications. Stable records, components and parent IDs remain separate from display names. Ordinary bundles without the appropriate completed modal audit are provisional. Distinct PIP parent branch identities cannot be aggregated merely because they have equal parameters.

`PlanNamedCatalogMigration_v3` performs no writes. It inventories old actual bytes/hashes/aliases and validates staged MAT loadability, full identities, reference links, provisional names, and filename/identity collisions. Publication must preserve original bytes before publishing MATs and atomically replacing catalogs and the alias/evidence-link manifest. A metadata rewrite changes the hash; the plan records that honestly. Historical evidence text is not silently rewritten.

## Runnable controls and campaign execution

After `V3AddPaths_v3`, run `RunBranchNamingControls_v3`. The deterministic controls exercise plurality, ties, sparse data, diagnostic winners, equal fold weighting, missing limbs, fold intersection enumeration, reversal and count partitions, unresolved extrema, constant speed/PIP, scalar displacement, stored multiples, square nonlinear residuals, finite nonperiodic trials, invalid trials, stable IDs, full p10 names, C0 references and B2 alias multiplicity. Algebraic test doubles are explicitly identified and are never counted as scientific admissions.

The retained native driver `Research_v3/NineHour_20261012/Drivers/RunNineHourSampling_v3.m` consumes actual Round A continuation components. It independently corrects arclength midpoints and registers local monotonic brackets when endpoint/midpoint signed secants agree above `1e-10` with magnitude ratio at most ten. This is finite endpoint/midpoint resolution and does **not** prove absence of smaller hidden folds. Failures or inconsistent secants leave edges unresolved and names provisional.

The driver defaults to 1,800 seconds total, at most 300 seconds per speed correction, and shares the registered monotonic research deadline. It audits all retained PIP points first, requiring current qualified vertical subtype, zero mean speed and original nine-gate primitive admissions. This constant-speed exception consumes no artificial speed roots and does not count against the default limit of two nonconstant windows, prioritized PK and B. Every intersection has an atomic checkpoint. Resume validates original campaign identity, exact source component SHA, target/partition context and the actual saved orbit identity before reusing an admitted root. Primary sample and midpoint trajectories are retained once; duplicate nested replay/derivative traces are compacted. Midpoint correction reserves time for independent replay and verifies exact p10 equality before interpolation. The root campaign is responsible for executing and independently validating the resulting scientific samples.

Complete current-contract audits are reused, including complete tied/diagnostic votes that correctly remain provisional. A qualified PIP constant-speed audit is reused without artificial sampling. An incomplete or stale-contract audit is preserved under an epoch and actual SHA before reentry. Reentry reclassifies accepted physical checkpoints and attempts targets whose numerical execution never started. Completed numerical failures remain failed checkpoints by default; `RetryFailedNumericalTargets=true` requires a nonempty `RetryDiagnosis` and explicitly changed `RetrySolverOptions`. The previous failed bytes are archived before a successor replaces a checkpoint. Identical requested settings are refused. Each invocation has its own bounded sampling deadline inside the unchanged campaign deadline and its own `Sampling_Runs` receipt. New midpoint/count/fold evidence that changes registered level targets or intersection counts requires a separately declared sampling scope rather than silently changing the old grid.

The Round A PK four-point window has three actual adjacent edges; the B two-point window has one. Each can support a twenty-speed study over its retained speed range after the local edge studies pass. The registered original orbit IDs, indices and arclength endpoints bound the study. Neither completeness of those twenty locations nor consistent endpoint/midpoint secants establishes the full global component speed range or excludes smaller hidden folds. A failed edge remains unresolved; additional admitted local refinement is required before treating that edge as resolved.

`PublishNineHourCatalog_v3` stages the campaign's coherent new C0/C1/C2 catalogs under `Research_v3/NineHour_20261012/Publication`. It recomputes point classifications and all modal votes using the current contract, publishes complete ordinary sampled partitions, and preserves historical isolated representatives as explicit provisional references. Original active source files/catalogs remain at their original paths with verified hashes. Staged MAT identities, p10 vectors and evidence links are validated before publication; atomic MAT moves and catalogs are followed by one final atomic publication manifest. C0 has one physical parent MAT per declared parent identity and C1/C2 refer to it. Publication of a display name creates no additional cycle or connectivity edge.

Before promoting a sampled partition, publication independently validates the original component SHA, twenty equal endpoint-inclusive targets, complete levels, actual stored-orbit identities and source full p10. It recomputes signed speed from every referenced physical orbit at every level and checks the recorded tolerance, at most `1e-8` and one tenth of the level spacing. Fresh classification must retain the registered flight-count partition. Evidence computed from a discarded or merged predictor cannot substitute for the physical orbit actually stored in the published sample list.
