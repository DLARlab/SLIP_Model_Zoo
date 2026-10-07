# Registered quadruped v3 research specification

## Identity and evidence boundary

This specification implements the research prompt at repository HEAD
`b54aa77e3f7af269101477a06c93d5ee60da4353` (2026-10-07). The machine-readable
registration is `Research_v3/config/full.json`, saved before campaign runs.
Its domain and acceptance criteria remain fixed when searches fail. Historical
Round4/P1/P2 reports are source evidence; their numerical statements become
current v3 evidence only after independent replay under the model below.

The original preservation gate below applied during the research campaign.
The later 2026-10-07 cleanup was separately authorized to remove testing
infrastructure outside v3 and revise its audit documentation. That cleanup
protects the complete `SLIP_Quadruped/` tree; preservation of every original
outside-v3 file is a campaign-time fact, not the cleanup invariant.

The production model identifier is
`v3-autonomous-first-directed-root-compressive-stance`. Its sufficient state
is the canonical 14 physical coordinates and the separate four-bit contact
mode. It has no hidden schedule, gait label, elapsed-contact clock, or
orbit-specific guard suppression. Geometry, parameters, event IDs and leg
ordering are supplied by `QuadrupedSchema_v3`. The parameter adapter's
`v2-exact` policy means equality of the mapped swing law; it does not mean
equality of complete hybrid executions.

## Model, root and search domain

The baseline parameters, read from fixture columns and checked against the
configuration, are

\[
p=(10,10,20,20,1,1,0,0,2,0.5)^T,
\]

corresponding to legacy `[10,20,2,1,0,.5,1]`. Touchdown occurs at the first
eligible descending zero of foot height, and liftoff at the first eligible
ascending zero of the uncompressed-leg surface. Accepted stance has positive
leg length and nonnegative compression within the stated numerical tolerance;
swing feet and torso cannot penetrate the ground. No force clamping is used.
ODE stages may pass beyond an event surface for root localization; they are
not accepted hybrid states. Every accepted point must also lie on its stance
rate-constraint manifold.

The specified root component is the ordinary synchronous vertical PIP family:
zero drift, `dx=phi=dphi=alpha_i=dalpha_i=0`, four simultaneous contacts, and
the ordinary first-liftoff vertical cycle. A named root family is a component
candidate, not a proof of connectedness or uniqueness. The delayed vertical
PIP family and the two traveling-pronking datasets are distinct objects until
complete-state equivalence or an admissible connection is demonstrated.

The registered domain is energy `1.0001 <= E <= 3`, mean speed
`-3 <= drift/T <= 3`, `abs(phi) <= 1.2`, primitive relative period at most
12, and at most 64 physical events per primitive cycle. All 16 contact modes
are permitted where physically admissible. Each labeled leg may contact more
than once. Downward leg/positive-length geometry, nonpenetration and mode
complementarity are mandatory. The finite-inertia energy is derived in
`Periodic_Orbit_and_Bifurcation_Theory_v3.md`; swing oscillator variables do
not carry finite body mechanical energy in this massless model.

This bound excludes the protected P1 pronking critical snapshot with initial
`dx=4.43406193516227`: positive height and nonnegative spring/pitch energy
give `E>0.5*dx^2>9.83`. The present bounded PIP energy campaign therefore
does not evaluate that historical critical neighborhood. Its exclusion is
reported separately from model incompatibility and failed search; the domain
will not be expanded silently after inspecting campaign outcomes.

Permitted equivalences are horizontal translation, time-phase transport, and
proved fixed-parameter system symmetries. A shorter leg-relabelled return is
recorded as spatiotemporal symmetry, not silently used as the primitive period.
Repeated traversals and different contact histories are not new primitive
orbits. In particular, B2 G/E apex views are one orbit family when a legitimate
phase transport agrees in state, modes, events and parameters.

The declared descriptive target universe is `PIP, PK, BD, HB_front, HB_hind,
GP, B2, F2, H2, G2, PC, TR, TL`. P1 roadmap subclasses BE/BG/FE/FG/HE/HG/GE/GG
must be kept as source-specific labels until trajectory diagnostics determine
their physical class. F2 means front spread; H2 means hind spread. Legacy
suffix 2 is not a certificate of two positive-duration flights. P1 and P2
classification uses the primitive-cycle physical flight count independently.
PC/TR/TL are retained in the target universe and marked unreached if absent;
they may not be omitted from a coverage claim after the campaign.

## Four separate hypotheses

**H_local.** Specific admissible connections exist between specified parent and
daughter branches. A regular connection requires a common model/parameter
identity, converged parent/daughter data, independent physical coordinates,
critical-subspace/rank evidence, signed daughter amplitude sequences tending
to the parent, full-trajectory symmetry change, and a derivative uncertainty
smaller than the observed signal. Theorem-backed status additionally requires
the analytical hypotheses on an open neighborhood containing the daughter
directions. Smoothness inside a paired-leg parent subspace is insufficient.

**H_network.** The specified ordinary-PIP component reaches representatives
of the requested P1 and P2 target classes at baseline p. The primary graph
counts validated regular bifurcations. A second, explicitly weaker graph may
count admissible nonsmooth itinerary connections. A grazing limit, candidate
proximity, imported daughter, or multiple-cover identification does not count
as a regular edge.

**H_coverage.** The resulting component represents every target class within
the registered domain. Sampling many points is not exhaustive orbit coverage;
classification borderline cases and unclassified accepted solutions remain
in the catalog. Complete target coverage is a class-level statement only.

**H_global.** Every admissible primitive relative periodic orbit of the model
belongs to this root component. This is a separate conjecture and requires a
global argument or exhaustive certification. Local branch theorems and a
bounded campaign cannot establish it.

## Desired graph, not presumed ancestry

P1 desired edges are ordinary PIP -> P1 PK -> BD -> HB_front/HB_hind -> GP,
with all actual roadmap subclasses and both spread sectors assessed. P2
desired edges are ordinary PIP -> B2 -> F2/H2 -> G2, permitting a documented
traveling-pronking intermediate. Required bridges include ordinary/P1 PIP to
delayed/P2 PIP and/or the two traveling-pronking datasets. Matching the name
PK is not a bridge. Legacy evidence instead reports delayed PIP ->
PK_B2_Parent -> B2; it also permits negative GRF and suppressed guard roots.
The legacy route therefore enters the compatibility gate before ancestry
is assigned in v3.

Graph nodes are model/parameter-qualified branch segments. Edge types are
regular symmetry breaking; other local bifurcation; admissible itinerary
connection; grazing/zero-duration limit; phase/proved symmetry equivalence;
multiple-cover identification; and numerical candidate. Each edge has an
evidence level, independent coordinates, isotropy before/after, and an explicit
terminal or unresolved reason. Different policies or physical parameters
cannot be joined to satisfy fixed-model H_network.

## Dependency gates and reproducibility

1. Preserve the protected tree relative to the initial worktree manifest.
2. Audit complete model equivalence, including first divergences. Keep
   incompatible legacy fixtures as rejected comparisons and continue admissible
   v3 searches.
3. Validate physical charts, energy, downward apex orientation, complete-cycle
   marking, reset ownership, circular phase transport and primitive identity.
4. Continue admissible families at fixed p; diagnostic parameter variation is
   a separate experiment.
5. Assess the full physical derivative or order-dependent collection. Restricted
   spectra do not certify directions excluded by synchrony.
6. Freeze parent-only predictions before inspecting held-out daughters. Imported
   seed reproduction and parent-only recovery remain separate ledger categories.
7. Validate GUI services and standalone v3 paths without legacy runtime imports.

The initial scaled periodicity infinity-norm threshold is `1e-8`; raw residual
components, guard residuals, physical margins and integration settings must
be stored. Acceptance also requires complete-state/mode closure and independent
forward replay. Numerical tolerances cannot be relaxed to include a desired
gait. Candidate FD matrices require step/tolerance studies and matrix-action
agreement, not only eigenvalue agreement. Contact-cluster derivative status is
conditional on continuity and feasible-order cones.

The full configuration registers total wall budget 7200 s, baseline tests
900 s, 120 s per fixture, three columns per family, 20 points in each
continuation direction, 20 root iterations/2000 evaluations, 16 alternative
seeds, 1800 s continuation, and 300 s GUI validation. Every expensive phase
must checkpoint accepted/rejected data, counters, seed 20261007, versions,
configuration, and terminal reasons. A budget stop is unresolved; a failed
corrector, minimum step or chart singularity is not a proof of nonexistence.

## Decision rule

The campaign may conclude conditional local propositions, demonstrated model
incompatibility, a precise refutation, numerical target connectivity, or
unresolved missing edges. The strong claim is determined by actual artifacts,
not by the graph requested at registration. The analytical delayed-history
obstruction below refutes copying that specific scheduled route into this
contact law; it does not refute all possible autonomous ordinary-PIP-to-B2
routes.

The parent-only pronk rerun registers version-2 numerical validation settings
before correction: an added `.01` signed amplitude, tighter solve/replay
integration, independent left-kernel transversality and derivative error
comparisons, and fail-closed support gates. These settings strengthen evidence
without changing the registered domain or physical parameters. Previous stage
files remain in a dated archive. The details and limits are in
`Parent_Only_Pronk_Validation_v3.md`; a tangent or even-multiplicity unit
crossing may be missed by the registered determinant sign-change scan.
