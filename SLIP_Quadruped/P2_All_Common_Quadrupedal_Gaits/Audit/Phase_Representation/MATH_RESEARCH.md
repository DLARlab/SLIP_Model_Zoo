# Mathematical audit: phase choice and duplicate gait representations

> Results-only layout. Numerical conclusions and evidence are retained. Historical filenames and run instructions refer to the [original numerical workspace](../../../P2_Numerical_Run_Archive/P2_original_layout_20261007.tar.gz). Use the [result path map](../Provenance/result_path_map.json) and [branch tree index](../../README.md) for current locations.


Date: 2026-09-09. This note separates primary-source facts, direct derivations, and proposed project changes. It does not claim a globally unique section or a new physical model.

## Finding

**Final project recommendation:** the fixed-fraction labelled-event gauge proved in the final section is the minimal experiment for this repository's fixed event-time itinerary. The moving-reference conditions surveyed below remain the fallback when that labelled clock is unavailable. `PLAN.md` records the selected approach and completed numerical checks.

The relevant object is a **whole periodic orbit modulo time translation**, not its initial apex. The B2 audit already supplies two downward-apex descriptions of a full cycle. Changing the scalar phase equation can make continuation locally well posed, but eliminating duplicate catalog entries requires a separate orbit-equivalence test.

In the active `Quadrupedal_ZeroFun_v2.m`, the section residual is `YAPEX(4)` (vertical velocity) and the following 13 residuals impose periodicity of all states except horizontal position. These equations also imply initial vertical velocity zero. They do not require downward crossing, the first return, or a unique apex. Therefore this implementation is a prescribed-full-period shooting problem with an apex phase condition; it is not itself an event-detected first-return map.

## Source-backed mathematical facts

For a section `h(z)=0`, transversality requires `Dh(z) f(z) != 0`; orientation selects one crossing direction. If an orbit intersects an oriented section `k` times per primitive period, it is a `k`-cycle of the first-return map and a fixed point of its `k`th iterate. Full-cycle Floquet multipliers do not depend on the starting point. A transverse section removes the time-translation neutral direction; it does not automatically remove other neutral directions. These statements are explicitly developed in chapters 3 and 5 of the authors' [ChaosBook, §§3.1, 5.3, 5.5](https://chaosbook.org/version17/chapters/ChaosBook.pdf).

AUTO's periodic-orbit implementation uses an integral phase condition with integrand `(U-UOLD) dot UPOLD`. Its documentation distinguishes continuation with this condition from phase shifting after removing it. This supports a moving-reference phase convention rather than assuming a particular observable has a single extremum. See the maintainers' [AUTO periodic.f90, ICPS](https://github.com/auto-07p/auto-07p/blob/master/src/periodic.f90#L279-L305) and [AUTO manual, demos ph1 and phs](https://github.com/auto-07p/auto-07p/blob/master/doc/auto.tex).

For hybrid systems, differentiable guards/resets and transverse, consistently ordered events underlie the usual saltation linearization. An event with identity reset and matching vector fields on both sides has identity saltation. Hence simultaneous compliant contacts must be examined in this model; simultaneity alone neither proves nor disproves differentiability. See [Kong et al., Saltation Matrices, §III-A](https://arxiv.org/html/2306.06862v2).

With multiple event surfaces, local return maps can be only piecewise differentiable. Burden et al. prove a local Poincaré-map result and describe the Bouligand derivative needed when different perturbation directions select different event orders. This matters even if the chosen section lies away from contact: moving the section does not remove nonsmoothness encountered elsewhere in the cycle. See [Burden et al., Event-Selected Vector Field Discontinuities, Theorem 3 and §6](https://arxiv.org/pdf/1407.1775).

## Direct consequences for B2

Let A and B be its two distinct downward apices and let `P` mean the next downward-apex return. Then

`P(A)=B`, `P(B)=A`, `P^2(A)=A`, `P^2(B)=B`.

Thus adding `ddy<0` is useful validation but leaves both representations. In particular, neither `DP(A)` nor `DP(B)` alone is the full-gait stability matrix. The full maps use `DP(B) DP(A)` at A and `DP(A) DP(B)` at B. Do not take a scalar square root of full-cycle multipliers to infer an apex-to-apex multiplier. A purported shorter primitive period must repeat the complete labelled state and contact schedule, not only body height or leg symmetry.

For `h=dy`, the transverse derivative is `ddy`. A bound `ddy < -epsilon` rejects flat extrema as a section failure without rejecting the underlying orbit. The B2 finding of two downward apices is therefore multiplicity, not necessarily loss of transversality. If no such apex exists in an admissible nonphysical continuation segment, apex selection cannot cover it.

An apparent intersection in `(initial velocity, initial height)` can be a phase-image crossing. A true branch point requires inequivalent nearby periodic orbits after phase alignment and independent tangent/rank evidence; a section change cannot erase a genuine bifurcation.

## Recommended implementation and validation plan

1. **Separate shooting residual from phase equation.** Preserve all v2 event/periodicity residuals and the underlying signed-velocity, signed-GRF model. Replace exactly the existing phase row in an opt-in v3; do not append another phase constraint. The state variable `dy0` must remain free when a different phase condition is selected. Keep the full period and labelled event schedule as unknowns.

2. **Use a moving local phase chart during continuation.** At a regular point of a reference orbit, with horizontal translation removed, a practical point condition is

   `psi(z0) = f_ref' W (z0-z_ref) = 0`,

   where `W` is fixed positive definite scaling within a corrector. Its derivative along the reference phase shift is `f_ref' W f_ref > 0` for a nonstationary reduced state. This gives local phase isolation. Monitor the current transverse derivative `f_ref' W f(z0)`, distance from the reference, and distance from hybrid events; update the reference only between accepted continuation steps. A point plane may have other distant intersections: restrict to the chart neighborhood rather than claiming global uniqueness.

   An integral alternative over normalized time `s in [0,1]` is

   `psi = integral (z(s)-z_ref(s))' W z_ref'(s) ds = 0`.

   At the reference its phase derivative is `integral z_ref' W z_ref' ds > 0`. Use piecewise smooth quadrature with event intervals represented consistently. Both choices are local gauges and can have distant roots. They need chart management, not a global minimization inside each residual evaluation.

3. **Use a labelled event to normalize presentation and test it independently.** A fixed leg's touchdown, for example BL touchdown, occurs once in the current one-TD/one-LO-per-leg itinerary and is a useful deterministic clock. Shift every state, event time, and horizontal origin together. Record the anchor identity, pre/post contact convention, transverse guard derivative, and event order. A foot-location guard at touchdown also belongs to the physical event constraints, so replacing the apex row by a duplicate foot-ground residual is invalid. Instead anchor the event time (for example `t_BL_TD=0`) in a compatible chart. Exact event-boundary conventions need validation in the existing time-wrap integrator; a regular interior phase chart avoids depending on them during continuation. If event number changes or touchdown disappears, explicitly change chart/itinerary.

4. **Deduplicate whole orbits outside the corrector.** Compare normalized full-state trajectories and cyclically shifted labelled event schedules. Minimize over time shift only for basic identity. Validate period, mean velocity, and trajectory agreement; these scalar invariants alone are insufficient. Keep a separate flag for reflection/leg-permutation equivalence, so signed branches and physical symmetries are not silently collapsed. Maintain original-to-canonical IDs and every transformation. A deterministic presentation anchor may jump at a tie; retain chart transitions in branch data.

5. **Audit Floquet calculations with the same full return.** Compare a known B2 orbit at its two apices and at the v3 chart, transporting section tangent bases and using the full labelled itinerary. Check convergence with perturbation and integration tolerance. At simultaneous contacts, compare derivatives for different admissible event orders. If they disagree in the limit, report a piecewise derivative or restricted symmetry result, not an unrestricted single Floquet matrix. Check any non-time neutral family direction separately before identifying a bifurcating multiplier near +1.

6. **Acceptance cases.** Use B2 gathered/extended apex pairs; signed and near-zero-mean B2; the PK-to-B2 point; PIP and pronking with simultaneous contacts; standing BS/BIP; and near-degenerate section/event cases. Require unchanged full-cycle residual and mean velocity under rephasing, same canonical identity for phase copies, separate identities for an unrelated nearby orbit, and full-cycle spectrum agreement where differentiability is verified. Re-run a short continuation through an old phase-image overlap and show orbit IDs rather than doubled displays. Preserve all original MAT data until this audit passes.

## Alternatives and their limits

| Choice | Benefit | Limit |
|---|---|---|
| `dy=0`, `ddy<0` | Minimal compatibility improvement | Still has two B2 downward apices; loses flat/no-apex cases |
| Pitch sign or gathered-suspension predicate | Can select one B2 view locally | Can vanish/change at parent families and removes legitimate representations outside its domain |
| Highest apex | Simple display rule | Equal-height ties and height-order exchanges make it discontinuous; unsuitable inside Newton residual |
| Labelled touchdown time | Unique clock for current labelled event itinerary | Event boundary and topology need explicit treatment; symmetry-equivalent labels are separate |
| Moving point/integral phase | Smooth local continuation gauge across changing apex counts | Requires references, locality checks, and chart transitions |

The recommended combination is moving-reference continuation plus labelled-event canonical presentation and full-orbit identity checks. A robust v3 should promise local well-posedness and demonstrable phase-copy consolidation on tested data, not one universal globally smooth representative for every gait family.

## Additional audit: fixed-fraction labelled-event phase gauge

The following is a direct mathematical derivation for the legacy event-time shooting representation, rather than a new result claimed from the cited literature. It provides a stronger phase-copy guarantee than the general moving-template proposal **within the current fixed labelled itinerary**.

Let `tau` be the one labelled BL touchdown time in `[0,T)`, and let a phase shift act as

`z_theta(t) = z(t+theta)`,

`tau_theta = mod(tau-theta,T)`.

All other labelled event times must undergo the same shift, and horizontal position must be rebased consistently. Choose a fixed `0<eta<1` and replace the old apex equation by

`psi = (tau-eta*T)/T = 0`.

Then the unique admissible phase shift modulo `T` is

`theta = mod(tau-eta*T,T)`.

To prove uniqueness, suppose two shifts satisfy the gauge. Both transformed touchdown times equal the same interior value `eta*T`, so their difference is an integer multiple of `T`. The transformed periodic trajectories and labelled schedules therefore agree. Locally, with `T` constant along a pure phase shift, `dpsi/dtheta = -1/T`, which is nonzero for every finite positive `T`. The modulo operation has no local kink at the anchored timestamp because `eta*T` is strictly interior.

Consequently, two exact apex descriptions of the same labelled periodic solution produce the same event-anchored representation. This conclusion does not depend on touchdown being a transverse physical guard crossing. The gauge fixes the time origin using an event timestamp, not an instantaneous geometric hypersurface of the physical state. It is a **periodic boundary-value phase gauge**, not a newly defined first-return Poincaré section. The distinction must remain explicit in code documentation and Floquet analysis.

Compared with a local moving-template plane, this gauge removes all time-shift copies modulo the declared period for the specified itinerary, rather than only the copies inside a small chart neighborhood. It is therefore a suitable minimal v3 experiment. Keep `eta` fixed throughout each corrector and continuation segment; use distinct metadata for chart transitions.

The guarantee has the following boundaries:

- **One event and a meaningful label.** If the leg has multiple touchdowns per declared cycle, the event occurrence must be identified consistently. Picking the first timestamp after an arbitrary origin is not an invariant occurrence label and can restore multiplicity. If touchdown disappears or becomes a freely movable no-op event, the physical orbit no longer determines the labelled timestamp. The gauge may still select a formal schedule but cannot establish physical uniqueness.
- **Zero-duration contact or swing.** Coincident TD/LO can destroy the intended event interpretation or change the model's interval ownership. Treat the limiting orbit and the continuation into the new itinerary separately. A timestamp constraint cannot repair a degenerate contact equation.
- **Primitive period.** The proof assumes a fixed declared `T`. It does not identify repetitions stored with `T`, `2T`, etc. Test the complete state and contact schedule for shorter periods. The current one-TD-per-leg schema normally excludes repeated contact itineraries, but degenerate/no-op contacts require an explicit check.
- **Other events at time zero.** Anchoring BL touchdown away from zero does not ensure every other event is away from the initial time. Monitor the initial-time distance to all event times and their order. If necessary, switch to another `eta`, rephase the whole solution, and record the transition. Choosing another `eta` moves the initial point; it does not remove simultaneous events occurring elsewhere in the gait.
- **Physical transversality and differentiability.** The nonzero gauge derivative does not cure grazing touchdown, a singular event-constraint Jacobian, or differing derivatives associated with simultaneous-event orders. Those remain independent continuation and Floquet validity tests.
- **Spatial symmetries.** Reflection, time reversal when it is a model symmetry, and leg permutations remain separate equivalence relations. A BL-labelled gauge does not silently quotient them. Gaits with genuine spatiotemporal symmetry may have equivalent label choices; record the transformation rather than conflating it with a pure phase shift.
- **Numerical accuracy.** Rephasing needs a valid full trajectory, consistent wrapped times and contact ownership, and retained full-period residual validation. Similar canonical initial states alone do not prove orbit identity. Preserve the previous chart and source column mapping.

Recommended experiment: keep the native event and periodicity equations, substitute this single gauge row with `eta=1/4` initially, free initial vertical velocity, and rephase both B2 apices to it. Require agreement of full state, labelled schedule, period, mean velocity, and residual. Test several other `eta` values and both directions through a short continuation segment. Compare the full-period Floquet spectra using separately validated physical return maps; do not interpret the event-time gauge row as a Poincaré projection.
