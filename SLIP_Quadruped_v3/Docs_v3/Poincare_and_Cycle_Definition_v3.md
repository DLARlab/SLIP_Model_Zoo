# Poincare Sections and Hybrid Cycle Definitions in v3

## Three distinct mathematical objects

The v3 framework deliberately separates three operations that are often, but
incorrectly, conflated.

1. A **geometric section** is a codimension-one surface

   \[
   \Sigma=\{(x,q):h(x,p)=0\}
   \]

   with a directional transversality condition. The quadruped apex section is
   \(h(x,p)=dy=0\), accepted only when \(\dot h=ddy\) is negative by more than
   the configured derivative tolerance. The definition places no restriction
   on the contact mode, so a grounded apex is valid.

2. A **section-crossing detector** integrates the hybrid execution until the
   next valid directional intersection with \(\Sigma\). It leaves the initial
   section, rearms the directional crossing, and then returns to the section.
   All state-triggered guards, reset maps, and mode transitions remain active
   during this process.

3. A **return policy** decides whether a detected crossing completes the map
   of interest. A rejected crossing is retained in diagnostics, and integration
   continues from its right-continuous state and mode.

This separation is implemented by `PoincareSection_v3`, the private
next-crossing operation in `PoincareMap_v3`, and subclasses of
`ReturnPolicyBase_v3`, respectively.

Construction selects the system-level default once: quadruped maps use
`EventCycleReturnPolicy_v3`, while generic systems use
`FirstReturnPolicy_v3`. An explicit policy always wins, so constructing a
periodic residual or Floquet analyzer cannot later change the map definition.

## First return

`FirstReturnPolicy_v3` accepts the first valid directional crossing after
positive time. If \(z_k=(x_k,q_k)\) denotes successive section intersections,
the map is

\[
P_\Sigma(z_0)=z_1.
\]

This is a geometric first-return map. It is not necessarily a complete gait
cycle: the first crossing can have a different discrete mode, incomplete
contact events, or represent one of several apexes in a physical cycle.

## Iterated return

`IteratedReturnPolicy_v3(m)` accepts the \(m\)-th valid crossing and computes

\[
P_\Sigma^m(z_0)=z_m.
\]

The iterate count is geometric. No event count or event order is imposed.
This policy is useful when multiplicity is known independently, but it should
not be used to conceal an unknown cycle-completion condition.

## Event-cycle return

`EventCycleReturnPolicy_v3` determines completion from physical event history.
For a contact vector with \(n\) legs, candidate crossing \(j\) is accepted at
the first index satisfying

\[
q_j=q_0,
\qquad N_i^{TD}(0,t_j)\geq 1,
\qquad N_i^{LO}(0,t_j)\geq 1,
\quad i=1,\ldots,n.
\]

The policy counts events using model-provided `leg_index` and `event_kind`
metadata. It does not prescribe their order. A leg may begin in stance or in
swing, and intermediate section crossings are permitted. For the quadruped,
this means every leg must have at least one touchdown and one liftoff and the
right-continuous section mode must close.

The accepted full-cycle map is denoted

\[
P_C(x_0,q_0,p)=(x_j,q_j),
\]

where \(j\), reported as `return_multiplicity`, is discovered by integration.
A periodic-orbit residual must use \(P_C\), rather than silently identifying
\(P_\Sigma\) with one gait cycle.

## Multiple apexes

A physical orbit may contain several downward \(dy=0\) intersections. Under an
event-cycle policy, every valid intersection is recorded in
`candidate_section_crossings`. Each record contains its state, right-continuous
mode, cumulative event history, event signatures, transversality, and the
policy reason for accepting or rejecting it. The first candidate satisfying
the cycle contract is returned.

Thus a two-apex cycle has `return_multiplicity = 2`, and its stability matrix
is the derivative of the complete composition

\[
DP_C=DP_{\Sigma,2}\,DP_{\Sigma,1},
\]

not the derivative of only its first local return.

## Section/event coincidences and boundary ownership

The simulator processes physical guards at a stopping-section coincidence
before recording the section stop. Consequently, section states and modes are
**right-continuous**:

\[
(x_\Sigma,q_\Sigma)=(x^+,q^+).
\]

The physical event is appended once to cumulative event history, is available
in `section_coincident_events`, and is not counted again when integration
restarts. Stop records are excluded from physical signatures and event counts.

This convention permits a contact event to move continuously through the apex.
For example, a branch can pass from `FR_LO < Apex`, through coincidence, to
`Apex < FR_LO`; the section mode changes chart locally while the continuous
orbit can remain valid.

## Local section-mode resolution

`SectionModeResolver_v3` starts with the previous accepted section mode. It
evaluates model-provided guard descriptors at the section and adds only modes
obtained from transitions whose guards are:

- within `SectionModeTolerance` of zero; and
- consistent with the guard's directional derivative.

When several independent guards are section-near, simultaneous combinations
are generated from that local set only. Every candidate records the transition
events and its generation reason. Failed transition combinations are retained
as rejected-mode diagnostics.

`allModes()` is an explicit exhaustive/debugging operation. It is not used by
the normal periodic-root workflow.

## Event signatures

The map reports two topology signatures.

- `section_relative_event_signature` starts at the chosen section and retains
  the observed temporal ordering. Simultaneous event names are sorted within a
  batch and joined by `&`.
- `cyclic_event_signature` is the lexicographically minimal cyclic rotation of
  those batches. It compares the same physical cycle across different choices
  of section origin.

Neither signature is a gait label. They are diagnostics for topology matching,
finite-difference reliability, continuation, and hybrid-boundary detection.

## Termination limits and diagnostics

`PoincareMap_v3` enforces independent limits:

- `MaxReturnTime`: elapsed time from the initial section;
- `MaxSectionCrossings`: number of policy candidates;
- `MaxCycleEvents`: cumulative number of physical guard events.

Successful output includes the accepted period, return multiplicity, all
candidate crossings, candidate count, accepted index, initial and final mode,
per-leg event counts when supplied by the policy, both event signatures,
section-coincident events, section and guard transversality margins, and
policy-specific cycle-completion diagnostics. Apex sections additionally
expose `candidate_apex_count` and `accepted_apex_index` aliases.

The generic map contains no quadruped leg count, event IDs, event ordering, or
gait classification. Those meanings enter only through model event metadata
and the selected return policy.
