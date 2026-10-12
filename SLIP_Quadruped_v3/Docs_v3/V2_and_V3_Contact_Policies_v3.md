# Contact execution in v2 and strict v3

> Cleanup note (2026-10-11): this report preserves its historical scientific scope. Selected final evidence is indexed in [Scientific_Evidence](../Audits_v3/Scientific_Evidence/README.md). Per-probe intermediates and campaign scripts were removed; historical claims do not imply a retained complete rerun workspace. The unchanged original report is also in the evidence bundles.


The current target remains **`v3-autonomous-first-directed-root-compressive-stance`**. The user selected this target after inspecting the prescribed-contact alternative. No compatibility-model dataset was published into P1 or P2.

## What stays the same

Under the explicit `v2-exact` conversion, the continuous equations, body/leg angle convention, spring forces and touchdown/liftoff angular-rate resets agree. The state changes from legacy leg order `[BL FL BR FR]` to native `[BL BR FL FR]`; physical parameters become the native ten-entry vector. This is a coordinate conversion, not a reason to change an angle or force sign.

For leg angle `theta = phi + alpha`, signed hip offset `s`, hip height `h = y + s*sin(phi)` and uncompressed leg length `l0`, both formulations use the event surface

```
g = h - l0*cos(theta) = 0.
```

During swing, `g` is the virtual foot's height. During stance, the fixed-foot leg length is `r = h/cos(theta)` and compression is `c = l0-r`. A negative `g` during stance is ordinary compression for a downward-pointing leg; it must not be confused with swing-foot penetration.

## How execution differs

| Condition | v2 prescribed-event shooting | Strict v3 autonomous contact model |
|---|---|---|
| Event times | The supplied event-time vector determines each integration endpoint and contact interval. The outer solve normally solves the coupled `[X;E]` problem; event times are genuine unknowns there. | The simulator locates event times from the evolving state. Contact times are outputs rather than supplied integration endpoints. |
| Touchdown | Execute at the supplied TD time; the shooting residual requires the foot surface to vanish there. | Enable TD only for a swing leg; execute its first downward crossing, `g=0` with `Dg*F<0`. |
| Liftoff | Execute at the supplied LO time, with its event-surface equality. | Enable LO only for a stance leg; execute its first upward crossing, `g=0` with `Dg*F>0`. |
| Earlier crossings | The prescribed schedule can pass through another surface crossing before the selected event. | An earlier enabled directed crossing changes the contact sequence immediately. |
| Between events | The production residual checks scheduled event surfaces and relative state closure. It does not enforce the complete strict v3 path inequalities. | Accepted states must have nonpenetrating swing feet, compressive stance, valid lengths and hip/torso geometry, mode/guard consistency and downward leg orientation. Current orientation checks apply to swing as well as stance. |
| Period/section | The supplied per-call `E(9)=tAPEX` determines the terminal shooting section; the outer coupled solve may adjust it. The maintained v2 Floquet layer additionally checks downward apex orientation and timetable consistency. | The return is an actual downward apex. The principal BL-marked chart selects the last downward apex before the next BL touchdown and preserves its declared BL occurrence count. |

The strict simulator does **not** clamp negative spring force to zero or silently skip an inconvenient contact. ODE trial stages may temporarily leave the physical domain while locating a root; accepted hybrid states are checked separately.

## Why the copied branches do not replay unchanged

The independent native MATLAB audit checked nine complete scheduled trajectories spanning BG, BE, FG, FE, HG, HE, GG and GE. Every checked trajectory had **compressive sampled stance** and inward radial motion at its scheduled touchdown. Every one also had virtual swing-foot penetration; two had upward-pointing swing legs. Thus the observed failure is not evidence that those copied stance trajectories themselves require tensile springs.

Strict v3 encounters an earlier swing-foot crossing instead. A downward-moving swing foot need not produce a compressing leg after the fixed-foot reset. If `(vh,wh)` is hip velocity, then at touchdown the correctly reset stance leg has

```
rdot_after = wh*cos(theta) - vh*sin(theta)
gdot_after = cos(theta)*rdot_after.
```

The incoming swing `gdot` also depends on its independent angular velocity. It can be negative while `rdot_after` is positive. In all sixteen retained direct native failures, the earlier touchdown was located correctly, its reset gave zero horizontal foot velocity, and the resulting leg immediately extended beyond rest length. That explains the tensile-stance rejection. Reversing the reset sign would break the fixed-foot constraint; accepting the resulting tension would change the target model.

The scheduled and autonomous systems therefore solve different periodic-orbit problems. A lossless format conversion cannot make a path satisfying one contact contract satisfy the other. The current recovery work seeks **different, corrected strict-v3 cycles**, using legacy branches as predictors and symmetry information. An accepted daughter, its continuation, and its attachment to a parent remain separate numerical claims.

Evidence: native contact derivation (historical intermediate removed), [complete source preservation and direct strict failures](Legacy_P1_Seed_Recovery_and_Model_Compatibility_v3.md), and native equation/reset differential replay (historical intermediate removed). The differential replay is an explicitly separate diagnostic, not admission into the strict network.
