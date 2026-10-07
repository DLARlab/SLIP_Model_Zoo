# P2 seeded compatibility and discovery status

This report is generated from saved evidence by `Research_v3/generate_family_reports.py`; it runs no simulation or solver. The source `Research_v3/runs/full/compatibility.json` has status `completed`, finished UTC `07-Oct-2026 09:52:16`, and SHA-256 `b09c927a99795f32130ca1e7753f8517f45d3890f37f8814a24472355635cc92`.

The completed replay contains 27 sampled source columns: 5 autonomous-state replay acceptances and 4 of those within the baseline parameter/initial-energy bounds. Autonomous-state acceptance is not an ancestry edge, and it is not automatically reproduction of the same legacy hybrid cycle. A primitive identity, complete forward trajectory, period, modes, guard eligibility and all event occurrences must also agree.

## Fixed model, domain and qualification

The model is `v3-autonomous-first-directed-root-compressive-stance`, with schema state order `x,dx,y,dy,phi,dphi,alphaBL,dalphaBL,alphaBR,dalphaBR,alphaFL,dalphaFL,alphaFR,dalphaFR`, separate contacts `BL,BR,FL,FR`, and baseline p=`[10,10,20,20,1,1,0,0,2,0.5]`. TD/LO use the first eligible directed state root; accepted tensile stance and swing penetration are rejected. `v2-exact` maps the legacy inactive-osa swing law and the physical parameter vector, not the full scheduled hybrid execution.

The registered search bounds are E in `[1.0001,3]`, mean speed in `[-3,3]`, absolute pitch at most 1.2, primitive relative period at most 12 and at most 64 physical events. The energy column below is the independently evaluated finite-j mechanical energy of the mapped initial state; it does not itself certify mode admissibility, conservation, geometric bounds or the full orbit. Out-of-domain imported source comparisons remain useful model diagnostics and cannot complete the registered network.

The root component is the ordinary synchronous vertical PIP family. Source filenames and directory trees describe historical provenance; no inherited parent/daughter relation is a v3 ancestry certificate. Accepted states at distinct parameters, under distinct event laws, or at different primitive covers cannot be merged to create a fixed-model graph.

The proposed route `PIP -> B2 -> F2/H2 -> G2` remains a hypothesis. The protected evidence instead records a delayed-PIP -> PK_B2_Parent -> B2 route, with ordinary-PIP/delayed-PIP and PK-family bridges unresolved. B2 G/E are reported alternate apex representations of the same cycles, not distinct discoveries; their equivalence under the chosen autonomous model still requires corrected full-state rephasing and replay.

The delayed analytic fixture column 1 has y=`1+1e-10`, all-stance contact, and zero rates. Its energy is approximately 1.0000000001, below 1.0001. The earlier map output had an approximately -0.9934489 time reversal and a spurious near-initial contact; it is invalid evidence despite a small endpoint residual. The corrected detector rejects that raw root using the existing directed/transverse predicate. See `Near_Grazing_Event_Diagnosis_v3.md` and the before/after MAT artifacts. This boundary record must not become an accepted delayed-PIP seed or a primitive two-flight orbit.

At positive flight amplitude, the analytic delayed vertical history suppresses the first eligible ascending LO root and subsequently enters tensile stance. It is incompatible with this contact law. The geometric grazing limit and its multiple covers do not establish a regular bridge. This specific obstruction does not exclude every possible nonvertical ordinary-PIP-to-B2 route.

The P1/P2 `PK_20_2.mat` source copies have identical SHA-256 `45835bb5024b1dc9b875c7b8f7b205769f537a4ff4144c763058537f44dbf401`; column 1 maps to the same state, mode, parameters and autonomous event log. Their two accepted provenance records are a duplicate comparison, not two orbit discoveries. This does not identify that family with the distinct `PK_B2_Parent` dataset.

## Sampled fixtures and first recorded failure

| Source fixture | Columns | Saved statuses | Initial energies | First recorded failure or unresolved qualification |
|---|---|---|---|---|
| `B2_10_20_2_E.mat` | 1, 654, 1307 | rejected: 3 | 38.2276248, 1.55337527, 11.7657803 | ContinuousDynamics_v3:PhysicallyInadmissible: Quadruped section-return is physically inadmissible: swing_foot_penetration:BL, contact_complementarity_loss:BL, swing_foot_penetration:BR, contact_complementarity_loss:BR, swing_foot_penetration:FL, contact_complementarity_loss:FL, swing_foot_penetration:FR, contact_complementarity_loss:FR. |
| `B2_10_20_2_G.mat` | 1, 680, 1358 | rejected: 3 | 38.2276248, 1.31559429, 11.4456431 | ContinuousDynamics_v3:TensileStance: Stance compression is below the admissibility tolerance for leg(s) FL, FR. |
| `BIP_10_20_2.mat` | 1, 453, 904 | rejected: 3 | 3.06564159, 2.29441913, 10.3919387 | PoincareMap_v3:InvalidInitialSection: The initial state is not a transverse section point with the requested crossing direction. |
| `BS_10_20_2_BIP_Child.mat` | 1, 107, 213 | rejected: 3 | 0.999186106, 1.58189267, 8.58271071 | PoincareMap_v3:NoReturn: No return-to-section crossing for candidate 9 occurred before MaxReturnTime. |
| `PIP_10_20_2.mat` | 1, 115, 228 | accepted_autonomous_seed: 3 | 1.00000001, 1.36646125, 2.99789349 | No saved failure; full hybrid-cycle equivalence and ancestry remain separate checks. |
| `PIP_10_20_2_Spread.mat` | 1, 325, 648 | rejected: 2, accepted_autonomous_seed: 1 | 0.821700261, 1.22395765, 0.821700261 | ContinuousDynamics_v3:TensileStance: Stance compression is below the admissibility tolerance for leg(s) BL, BR, FL, FR. |
| `PIP_Delayed_Analytic_10_20_2.mat` | 1, 794, 1586 | rejected: 3 | 1, 2.25972727, 19.99999 | EventDetector_v3:IneligibleTriggeredGuard: ODE-reported guard BL_LO at t=1.3877787807814457e-17 fails the directed transverse-root contract (g=1.000000082740371e-10, DgF=0). |
| `PK_20_2.mat` | 1, 446, 891 | accepted_autonomous_seed: 1, rejected: 2 | 1.11713894, 96.2638783, 20.5273827 | ContinuousDynamics_v3:PhysicallyInadmissible: Quadruped section-return is physically inadmissible: swing_foot_penetration:BL, contact_complementarity_loss:BL, swing_foot_penetration:BR, contact_complementarity_loss:BR, swing_foot_penetration:FL, contact_complementarity_loss:FL, swing_foot_penetration:FR, contact_complementarity_loss:FR. |
| `PK_B2_Parent.mat` | 1, 130, 259 | rejected: 3 | 19.9606882, 1.08913081, 19.9606882 | ContinuousDynamics_v3:TensileStance: Stance compression is below the admissibility tolerance for leg(s) BL, BR, FL, FR. |

A tensile-state or penetration failure is a specific violation of the selected mode domain. An invalid initial section can indicate a different apex/chart rather than nonexistence of an orbit. A missing return within bounds or a solver stop leaves that search unresolved. The table is a bounded column sample, not an exhaustive rejection of every source orbit.

## Autonomous replay versus original cycle

| Source / column | Replay label / primitive diagnostic | Saved residual | Legacy / autonomous period | Contact-history comparison |
|---|---|---|---|---|
| `PIP_10_20_2.mat` / 1 | PIP / primitive_within_checked_bound | 4.75968154e-11 | 0.993458827 / 0.993458827 | timing/multiplicity matches within 1e-6 (trajectory equivalence unproved) |
| `PIP_10_20_2.mat` / 115 | PIP / primitive_within_checked_bound | 6.54410748e-10 | 2.26670028 / 2.26670028 | timing/multiplicity matches within 1e-6 (trajectory equivalence unproved) |
| `PIP_10_20_2.mat` / 228 | PIP / primitive_within_checked_bound | 2.11109707e-09 | 4.51958355 / 4.51958355 | timing/multiplicity matches within 1e-6 (trajectory equivalence unproved) |
| `PIP_10_20_2_Spread.mat` / 325 | PIP / primitive_within_checked_bound | 4.91161778e-10 | 1.90862258 / 1.90862258 | timing/multiplicity matches within 1e-6 (trajectory equivalence unproved) |
| `PK_20_2.mat` / 1 | PK / primitive_within_checked_bound | 2.95206304e-10 | 1.56452021 / 1.56452021 | timing/multiplicity matches within 1e-6 (trajectory equivalence unproved) |

The contact comparison ignores mere ordering differences inside simultaneous TD/LO ties and compares all event occurrences on the time circle at the specified periods. A timing/multiplicity match is a diagnostic, not proof of equal flows, resets, GRF or complete hybrid trajectories. The machine-readable first-divergence field compares simultaneous contact clusters rather than tie ordering. If the initial state already violates the physical domain, that is the first failure; later schedule differences are secondary.

## Reproduction and parent-only discovery

F2 means front-spread half-bounding and H2 means hind-spread half-bounding. The legacy suffix 2 is a timing heuristic; physical flight count is independently measured over the numerically identified primitive cycle. A component may pass through zero-, one- and two-flight segments, and a double cover of a one-flight orbit is not a new double-flight gait. Borderline, unclassified and primitive-unknown records remain explicit diagnostics.

Imported B2, PK_B2_Parent or daughter states are seeded comparison inputs, not parent-only discoveries. No B2 -> F2, B2 -> H2, F2/H2 -> G2 or root/PK-family bridge is certified by these replay observations. Without an admitted B2 parent and validated unrestricted derivative, proceeding with a claimed smooth daughter certificate would bypass the model gate. The graph may retain blocked/unresolved candidate edges, not invented branches.

## Separate restricted parent-only checkpoint

The saved `Research_v3/runs/full/pip_pk_local.json` status is `budget_exhausted`, origin `parent-only`, and restriction `pronk invariant subspace; no split-contact derivative claimed`. The artifact reports held-out daughter use as `False`. These records are separate from imported-seed replay. A stored restricted attachment status does not establish unrestricted contact-cluster smoothness, a theorem-backed pitchfork or ancestry of the imported PK/B2-parent datasets.

| Critical energy | Saved evidence status | Signed amplitude samples | Maximum saved complete-state closure |
|---|---|---|---|
| 1.55516525 | `numerically_supported_restricted_attachment` | 10 | 8.7374552e-12 |
| 1.69595084 | `numerically_supported_restricted_attachment` | 10 | 1.76699511e-11 |

This is a snapshot of the saved local experiment. Tighter replay, full-trajectory distinctions, amplitude convergence, released physical directions and continuation/attachment assessment must be read from its final certificates and the overall research status. No P1/P2 network completion follows from this table.

## Additional boundary qualification

Ordinary `PIP_10_20_2.mat` column 1 has initial E approximately `1.00000001`, below the registered lower bound. The current saved first BL TD is `0.000141421354`, compared with the exact flight benchmark `0.000141421356`. The previous detector clustered a nonzero-height guard prematurely at the artificial leave-section stop (`t=1e-7`). The regression was reproduced red, then fixed by requiring both surface-value tolerance and root-time proximity when the normal velocity is nonzero, with the original direction/tolerance settings retained. The final contract tests place all four TD events at the physical root within 1e-9 and preserve ordinary simultaneous contacts. The out-of-domain energy qualification remains. Small endpoint closure alone does not certify near-grazing event-time accuracy; grazing continuation and ordinary smoothness still require separate treatment.

PC/TR/TL remain in the declared target universe and are not certified reached here. The conditional local propositions in `Periodic_Orbit_and_Bifurcation_Theory_v3.md` do not imply H_network, H_coverage or H_global.

## Supporting runs and reproducibility

The saved exact vertical stage status is `completed`; maximum saved period error is 1.00561248e-09, closure is 1.88878868e-09, and energy range is 2.30013963e-09. These are vertical-model benchmark observations, not off-synchrony branch connections.

The fixed-parameter family stage snapshot status is `completed`. Its final counts/terminal reasons and accepted physical points must be read from the completed checkpoint; a running or budget-ended stage cannot establish branch completeness.

The protected-source manifest is `Research_v3/baseline/source_fixture_manifest.json`. Each observation records its immutable in-v3 fixture path, original path, checksum, source HEAD, variable, column, model parameter policy and mapped state/mode/parameter. Converted seeds preserve source provenance separately from v3 result identity. The local P2 original-run archive was absent in the recorded inventory; no native scheduled campaign execution is claimed.

Run/resume through `python3 SLIP_Quadruped_v3/Research_v3/run_campaign.py --config full --stage compatibility` from the repository root (using the driver's registered MATLAB environment). After a completed corrected-code replay, refresh this report with `python3 SLIP_Quadruped_v3/Research_v3/generate_family_reports.py`. The source JSON, MAT checkpoints, logs and execution ledger are authoritative for what actually ran. Model-gate failures are distinct from physical-boundary results and search-budget limits.

The generic parent-only stage status is `completed_bounded_search`: No branch edge is certified by this search. Its attempt diagnostics are separate from the restricted local pronking study. The corrected compatibility replay uses effective top-level integration RelTol=1e-09, AbsTol=1e-10; earlier ODEOptions-only runs were superseded.

## Imported PK continuation segments

These segments hold the ten physical parameters fixed and vary conserved energy within the pronk restriction. Their imported seed supplies no ordinary-PIP ancestry. Accepted-point counts include stored restart/seed endpoints; they are not counts of distinct gait classes or proof of complete branches.

| Direction | Status | Stored accepted points | Maximum complete-state closure | Stop reason |
|---|---|---|---|---|
| -1 | `completed_bounded_branch` | 20 | 3.38852946e-10 | maximum point count reached |
| 1 | `completed_bounded_branch` | 21 | 2.96106695e-10 | maximum point count reached |

See the typed graph and `Branches_v3/index.json` for shared checkpoints. Maximum point count is a numerical budget stop, not a demonstrated physical endpoint.
