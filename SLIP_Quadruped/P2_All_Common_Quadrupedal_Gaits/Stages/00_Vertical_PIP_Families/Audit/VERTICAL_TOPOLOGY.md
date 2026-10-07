# Ordinary PIP, delayed PIP, and the qualified path to B2

> Results-only layout. Numerical conclusions and evidence are retained. Historical filenames and run instructions refer to the [original numerical workspace](../../../../P2_Numerical_Run_Archive/P2_original_layout_20261007.tar.gz). Use the [result path map](../../../Audit/Provenance/result_path_map.json) and [branch tree index](../../../README.md) for current locations.


The frozen evidence supports **delayed PIP → PK_B2_Parent → B2**. A regular
**ordinary PIP → delayed PIP** connection has not been established. This audit
derives a shared grazing boundary, which must not be presented as a verified
regular branch link or a certified period-doubling bifurcation.

## Exact vertical reduction and energy matching

Parameters are `[10,20,2,1,0,.5,1]`. For all four legs vertical and synchronous,
the torso follows `y'' = 40(1-y)-1` in stance and `y'' = -1` in flight. Thus
`w=√40`, `yeq=.975`, and `τ=2π/w=0.993458826579610`. This reduction is regular for
positive leg length. The conserved energy is

`E = y + (dy)^2/2 + 20(1-y)^2` in stance, and `E = y + (dy)^2/2` in flight.

For a delayed tensile-stance apex `h>1`, define

`A=h-.975`, `E=h+20(h-1)^2`, `v=√(2(E-1))`,
`θ=atan2(v/w,.025)`, `tL=(2π-θ)/w`.

The ordinary cycle starts at its flight apex `y=E`. Its touchdown is at `v`,
its stance duration is `(2π-2θ)/w`, and its period is
`Tord=(2π-2θ)/w+2v`. The delayed cycle starts at its tensile stance apex `h`.
It has wrapped stance, `LO=tL`, `TD=tL+2v`, and
`Tdel=2tL+2v`. Consequently,

**`Sdel−Sord = Tdel−Tord = τ` exactly, at equal energy.**

The extra stance oscillation includes tension; allowing negative GRF makes
this a valid family of the scheduled-contact mathematical model. It does not
make its contact sequence identical to ordinary PIP. Ordinary PIP uses the
first ascending zero-force exit after its compression. Delayed PIP remains
in stance through an additional complete oscillator revolution. At positive
flight duration this changes the number of compression minima per full cycle.

More generally, retaining `n` extra oscillator revolutions gives
`T_n(E)=Tord(E)+nτ`, with a nonnegative integer `n`. Ordinary PIP has `n=0`;
this delayed PIP has `n=1`. Positive leg length requires `1<E<20`, because
`ymin=.975−sqrt(.025²+2(E−1)/40)>0`. Within the synchronized vertical,
one-flight-interval family, `n` is locally invariant when contact events are
transverse and the leg stays positive. It cannot change through a regular
variation inside that subspace. This is not a claim about routes leaving the
vertical subspace or passing through singular contact boundaries.

## Comparison at the delayed-PIP pitchfork

The critical snapshot equals `PK_B2_Parent.mat` column 132 exactly. At this
energy the two vertical cycles have the following values:

| Quantity | Ordinary PIP | Delayed PIP |
|---|---:|---:|
| Conserved E / flight-apex height | 1.087455508685840 | 1.087455508685840 |
| Initial height in saved phase | 1.087455508685840 | 1.045694946313665 |
| Initial contact | flight | four-leg stance |
| Minimum body height | 0.904305053686335 | 0.904305053686335 |
| Flight duration | 0.836447290321822 | 0.836447290321822 |
| Continuous stance duration | 0.611030329538862 | 1.604489156118472 |
| Full contact-cycle period | 1.447477619860684 | 2.440936446440293 |
| Compression minima per full cycle | 1 | 2 |
| Minimum total vertical GRF | 0 | -1.827797852546604 |

The delayed individual-leg minimum GRF is
`-0.456949463136651`; total and individual-leg force
must not be mixed when comparing audit tables.

There is an intervening downward flight apex at `Tdel/2 =
1.220468223220147`, where `y=1.087455508685840`.
It differs from the starting height by
`0.041760562372175`, and contact has
changed from stance to flight. Therefore it is **not** a full-state/contact
return. At finite flight duration the full delayed contact period is minimal:
there is one maximal nonempty flight interval per cycle, so a nontrivial time
shift cannot preserve the complete contact sequence. An apex map that stops
at the next downward apex is a different map from this full-contact-cycle map.

The analytic timing formulas match all 228 saved
ordinary columns to `2.98e-09` and all
7 delayed local columns to
`8.88e-16`. The critical delayed timing error
is `8.88e-16`. Exact sampled trajectories
conserve energy to floating-point roundoff. These are analytic consistency
checks of frozen snapshots, not a new native periodic-orbit correction.

## What happens at zero flight

As `E→1+` (equivalently `h→1+`), `v→0`, `θ→0`, and

`Tord→τ=0.993458826579610`, `Tdel→2τ=1.986917653159220`.

Both approach the all-stance oscillator

`y(t)=.975+.025 cos(√40 t)`, with `.95≤y≤1`.

Its minimal period is `τ`. Ordinary PIP reaches one traversal of this orbit;
delayed PIP reaches two traversals when represented over its limiting period
`2τ`. More precisely, delayed PIP's closure meets a **double cover of the
ordinary family's grazing-limit orbit**. There is a common limiting geometric
orbit after allowing phase changes and repeated traversals.

This does **not** establish a regular connection:

1. Flight duration collapses to zero and the event normal velocity `dy` is
   zero. The touchdown/liftoff event equations lose transversality.
2. The minimal period changes from the delayed full contact period to `τ`.
   A shared repeated-orbit limit is insufficient to infer a period-doubling
   bifurcation; no required Floquet or grazing branch-switch calculation is
   supplied here.
3. In the frozen `Quadrupedal_ZeroFun_v2.m`, contact uses strict `TD<LO` or
   `TD>LO` cases (lines [132, 601]). Setting
   `TD=LO` selects **no contact**, not the all-stance limiting mode. Thus the
   exact grazing endpoint cannot be evaluated by naively substituting equal
   timing values. For ordinary PIP the boundary also places TD=0 and LO=T at
   the timing wrap; this requires a separately defined boundary chart.
4. A finite-period double cover of ordinary PIP has two flight intervals per
   doubled cycle, whereas this delayed family has one. The one-TD/one-LO
   chart cannot itself certify a regular transition between those schedules.

For `E>1`, the strict period identity excludes equality of these two vertical
cycles at the same energy and minimal period. This is not a proof that no
other route exists through additional branches or a suitably resolved grazing
boundary. Such a route remains uncomputed.

## What the stored connection evidence does establish

The delayed critical orbit and the B2 critical pronking orbit occur in the
same saved `PK_B2_Parent` curve, at columns 132 and 110 respectively. Their
29-vector differences against the frozen critical snapshots are `0` and
`2.22e-16`. The stored parent validation reports all 259 columns with maximum
Cartesian full-state return residual
`6.142e-09`.
The local traveling snapshots record
`H/u = a(h-hc)+b u²+...`, `a=32.0853173585`,
`b=-7.41667179759`, and
`h-hc≈0.231154696546u²`.
They provide the local reflected traveling daughters from delayed PIP.
The B2 local daughter snapshots approach the other critical orbit and record
maximum periodic residual
`3.694e-13`.
Those values are **existing snapshot evidence**, with independent checks in
the audit's other components; this topology script does not recalculate them.

Thus the verified chain starts on **delayed PIP**, not automatically on the
supplied ordinary PIP. The unresolved ordinary-to-delayed step must stay visible
in any claim of a complete PIP→B2 path.

Figures: `vertical_equal_energy_and_boundary.png/.pdf` and
`path_topology.png/.pdf`. The dashed arrows in the topology figure mark either
an unresolved regular link or analytic boundary limits, as labeled.
