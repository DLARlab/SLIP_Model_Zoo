# Round 1 implemented-model and symbolic audit

## Scope and evidence boundary

This is a source-level formalization of the production implementation at
commit `2c106101383ecee1b2a9d695efe09fbd72d5718a`. MATLAB was not installed in
the audit environment, so derivation scripts were not executed and numerical
equivalence was not claimed. The authoritative statement for current runtime
behavior is `Quadrupedal_ZeroFun_v2.m`, not the symbolic scripts or comments.
The complete index contract is in
[`data-schema-round1.md`](data-schema-round1.md).

## Hybrid system implemented in production

Let
\[
q=(x,y,\phi,\alpha_{BL},\alpha_{FL},\alpha_{BR},\alpha_{FR})
\]
and let the 14-state vector interleave each coordinate and velocity as
documented in the schema. For each prescribed contact mode
\(\sigma=(c_{BL},c_{FL},c_{BR},c_{FR})\in\{0,1\}^4\), production integrates
\[
\dot y=f_\sigma(y,p)
\]
with `ode45` (`Quadrupedal_ZeroFun_v2.m:127-178`). The code selects one of up
to 16 modes from prescribed event-time intervals; it does not use
state-triggered ODE events.

### Geometry and angle convention

With normalized torso length one,
\[
r_B=(x-\ell_b\cos\phi,\ y-\ell_b\sin\phi),\qquad
r_F=(x+(1-\ell_b)\cos\phi,\ y+(1-\ell_b)\sin\phi).
\]
These are implemented at `Quadrupedal_ZeroFun_v2.m:385-387`. For a stance
leg with \(\theta_i=\phi+\alpha_i\), the implemented vertical geometry gives
leg length
\[
\ell_i=\frac{r_{i,y}}{\cos\theta_i},
\]
and the stationary-foot constraint represented by the generated functions is
\[
x_{\text{foot},i}=r_{i,x}+r_{i,y}\tan\theta_i=\mathrm{constant}.
\]
The angle is therefore relative to the torso; the upward leg-axis force on the
body is represented as \((-\sin\theta_i,\cos\theta_i)\).

### Spring, body force, and torque

Back/front stiffnesses are split from `k` and `kr`:
\[
k_b=\frac{2k}{1+1/k_r},\qquad k_f=\frac{2k}{1+k_r}.
\]
For a prescribed stance leg,
\[
F_i=k_i(\ell_0-\ell_i).
\]
No `max(0,.)` clamp or independent contact-validity check is present
(`Quadrupedal_ZeroFun_v2.m:397-408`). The body equations are
\[
\ddot x=-\sum_i F_i\sin(\phi+\alpha_i),\qquad
\ddot y=\sum_i F_i\cos(\phi+\alpha_i)-1,
\]
\[
\ddot\phi=\tau/J,
\]
where back-leg torque is
\(-F_i\ell_b\cos\alpha_i\) and front-leg torque is
\(+F_i(1-\ell_b)\cos\alpha_i\)
(`Quadrupedal_ZeroFun_v2.m:410-420`). Mass and gravity are both one.

For a stance leg, the generated constraint functions supply its angular
velocity and acceleration to maintain horizontal foot fixation
(`Quadrupedal_ZeroFun_v2.m:425-459`). For a swing leg, the explicit
acceleration includes body accelerations, pitch coupling, and the restoring
term `alpha*ks/l^2` (`Quadrupedal_ZeroFun_v2.m:428-465`). The parsed neutral
angle `osa=Para(5)` is not referenced in these equations; production restores
toward zero, not toward `osa`.

### Contact and event semantics

For valid `T>0`, event times are mapped into `[0,T)`. A nonwrapped stance is
the strict-open interval `(TD,LO)`; a wrapped stance is `(TD,T) union
(0,LO)`. Coincident `TD=LO` means no contact in the production dynamics and
GRF calculation (`Quadrupedal_ZeroFun_v2.m:132-153,600-622`). Sorting the
nine event times determines integration segment order
(`Quadrupedal_ZeroFun_v2.m:121-130`). Event ties create zero-length segments;
the source does not define a physical priority for simultaneous reset maps.

At every touchdown **and** every liftoff, production duplicates the event
sample and replaces only that leg's angular velocity with the
stationary-horizontal-foot projection
(`Quadrupedal_ZeroFun_v2.m:183-245`). Position, torso velocities, and the
other leg rates remain unchanged. This is not an impulse solve and does not
project torso velocity. Applying the same projection at liftoff is current
behavior; whether it is physically intended requires model-owner confirmation.

### Return map and periodic orbit

The 22 unknowns are \(z=[X;E]\), with \(x_0=0\) fixed. Integration returns at
the prescribed period \(T=t_{\mathrm{APEX}}\). The Poincaré equation is
\(\dot y(T)=0\) (`Quadrupedal_ZeroFun_v2.m:303-305`). The remaining
nonhorizontal state is periodic:
\[
y_{2:14}(0)-y_{2:14}(T)=0
\]
(`Quadrupedal_ZeroFun_v2.m:319-320`). At a root this also makes the initial
vertical velocity zero. If `J==Inf`, the code adds \(\phi(T)=0\)
(`Quadrupedal_ZeroFun_v2.m:307-310`). Optional event-pair constraints may add
two circular timing differences.

Horizontal position is a continuous translation symmetry and is removed from
the unknown/residual. Left/right relabeling is a discrete symmetry when
parameters are symmetric. The prescribed Poincaré condition fixes phase for
an isolated periodic solution. No conserved quantity is asserted by the code:
prescribed mode switches and velocity projections can change energy, and no
energy invariant is tested. Time evolution within a fixed mode is autonomous,
but the hybrid schedule is prescribed by solved clock times.

## Production, documentation, derivation, and uncertainty

| Topic | Production implements | Comments/docs claim or imply | Symbolic source appears intended to derive | Status |
|---|---|---|---|---|
| Parameter vector | Seven values `[k,ks,J,l,osa,lb,kr]` | `Quadrupedal_ZeroFun_v2.m:1` and `SolveQuadrupedalZE.m:10` show stale five-value orders | Several scripts use different local parameter sets | Production order is established; derivation lineage is fragmented |
| Swing neutral angle | Restoring term proportional to `alpha` | `osa` is described as resting angle | No committed authoritative generator connects `osa` to runtime | Confirmed unused parameter; intended physics unknown |
| Contact | Prescribed strict-open clock intervals | README does not specify endpoints | Symbolic scripts formulate stationary-foot constraints | Endpoint/equality meaning outside dynamics is inconsistent |
| Event handling | Leg angular-rate projection at TD and LO | Comments label several LO blocks as touchdown | Generated constraint expresses zero horizontal foot speed | Projection at LO and tie order need owner confirmation |
| Springs | Bilateral algebraic spring force during prescribed contact | No unilateral rule documented | Lagrangian scripts do not establish runtime force law | Whether tension is physical is unresolved |
| Nondimensionalization | `M=g=L=1`; body length one | README gives nondimensional plot units | Projection comments mention normalized body length | Scaling is inferable but not centrally specified |
| GRF horizontal sign | Output uses `+F*sin(theta)` | ODE body force uses `-F*sin(theta)` | No single shared force generator | Frame/actor convention may explain it; owner confirmation required |

## Symbolic-source audit

### `SystemDynamics_Lagrangian.m`

This is a multi-section experimental/code-generation script, not currently a
reproducible authoritative generator.

- **CD:** The first section references undefined `posbl`, `posbr`, `posfl`,
  and `posfr` at line 40, while only `posB` and `posF` were declared.
- **CD:** It references undefined `d_CoGSbl`, `d_CoGSbr`, `d_CoGSfl`, and
  `d_CoGSfr` at lines 45–48.
- **CD:** Five generalized coordinates are declared at lines 5–10, but the
  generalized-force vector at line 70 has seven entries and also uses
  undefined `abl`, `abr`, `afl`, and `afr`. Consequently
  `f_cg + u` at line 78 is dimensionally incompatible.
- **NR:** It explicitly forms `inv(MassMatrix)` at line 75 instead of a
  linear solve. Even after the symbol defects are repaired, this is a less
  stable and less efficient symbolic/numeric pattern.
- Later sections independently generate stance-velocity, stance-acceleration,
  and leg-length files at lines 85–203. The named generated files are not
  committed under those names, so their output cannot be reconciled with
  production from repository state alone.

The first section necessarily stops before generation. Regeneration was not
attempted because MATLAB and Symbolic Math Toolbox are absent and Round 1
forbids repairs.

### `SystemDynamics_Projection.m`

This file contains successive bipedal, quadrupedal swing, two-leg stance, and
four-leg stance experiments separated by `clear`; it is not a single
end-to-end generator.

- **CD:** The quadrupedal swing torque vector uses `alphaBL` and `alphaBR`
  again for its front-leg entries at line 153 instead of the declared
  `alphaFL` and `alphaFR`.
- **CD:** After `clear`, the quadrupedal section declares `m` but not `m2`
  (`SystemDynamics_Projection.m:82-95`), then evaluates
  `limit(ddq,m2,0)` at line 157.
- The two-leg stance section at lines 161–216 is internally the apparent
  generator for committed `Func_alphaB_VA_v2.m` and
  `Func_alphaF_VA_v2.m`: it solves horizontal foot velocity and acceleration
  and supplies `[q;dq;ddq;lb]`.
- **CD:** In the four-leg section, the front-right foot x-coordinate mixes
  `posB(1)` with `posF(2)` at line 249.
- **CD:** Lines 263 and 274 solve velocity equations for acceleration
  variables (`ddalphaBL`, `ddalphaFL`) rather than solving for the
  corresponding angular velocities. The four-leg section ends before a
  complete four-leg output set is generated.

The safe later repair is to choose one explicit derivation, add symbolic
assumptions and dimension assertions, generate into a temporary directory,
and compare generated expressions and constraint residuals before replacing
any runtime file.

### `QuadrupedalSystemDynamics.mlx`

Static OOXML extraction shows swing/stance Lagrangian experiments and embedded
outputs from an older MATLAB release. It is readable as a Live Script archive,
but cannot be established as authoritative: it has no machine-checked link to
the committed runtime functions, and its cells were not executed. Preserve it
as reference evidence until the model owner selects a derivation source.

### Generated stance functions

The standalone headers identify Symbolic Math Toolbox 8.7 and generation on
16 February 2023 (`Func_alphaB_VA_v2.m:5-6`,
`Func_alphaF_VA_v2.m:5-6`). The exact 16-input layout is
\[
[q_1,\ldots,q_5,\dot q_1,\ldots,\dot q_5,\ddot q_1,\ldots,\ddot q_5,\ell_b]^T,
\]
where \(q=[x,y,\phi,\alpha_B,\alpha_F]^T\). The apparent generator is
`SystemDynamics_Projection.m:161-216`.

Static expression comparison found the standalone back/front functions
byte-for-expression identical to the local copies at
`Quadrupedal_ZeroFun_v2.m:477-559`. This duplication is architecture debt,
not a demonstrated numerical discrepancy.

The audit tests substitute the generated angular velocity and acceleration
into central finite differences of
\(x_\text{foot}=r_x+r_y\tan(\phi+\alpha)\). Execution is pending MATLAB.
Visible singular factors include:

- back velocity denominator `2*(y-lb*sin(phi))`
  (`Func_alphaB_VA_v2.m:32`);
- a separate trigonometric back-acceleration denominator
  (`Func_alphaB_VA_v2.m:38`);
- front factors `(lb-1)*sin(phi)-y`, `tan(phi+alphaF)`, and
  `1+tan(phi+alphaF)^2` (`Func_alphaF_VA_v2.m:21-39`).

Production does not check distance from these singular manifolds before
calling the generated functions.

## Invalid regions and force assumptions

| Region or assumption | Current behavior | Evidence |
|---|---|---|
| `T<=0`, `T=NaN`, or `T=Inf` | `mod` returns invalid values or accepts a negative modulus; no error | `EventTimingRegulation.m:17-37` |
| `J=0` or negative finite `J` | Divides torque by `J`; no validation | `Quadrupedal_ZeroFun_v2.m:420,428-465` |
| `J=Inf` | Pitch acceleration terms tend to zero and one residual is added | `Quadrupedal_ZeroFun_v2.m:307-310,420` |
| `l<=0` or nonfinite | Used in swing denominators and geometry; no validation | `Quadrupedal_ZeroFun_v2.m:95,428-465` |
| `cos(phi+alpha)` near zero | Stance length/force diverges | `Quadrupedal_ZeroFun_v2.m:397-408` |
| `kr=0`, `kr=-1`, negative/nonfinite | Stiffness split can divide by zero, become nonfinite, or reverse signs | `Quadrupedal_ZeroFun_v2.m:104-106` |
| Nonfinite `k` or `ks` | Propagates into ODE without an explicit rejection | `Quadrupedal_ZeroFun_v2.m:92-93,397-465` |
| Leg longer than rest length | Algebraic `F_i<0` can produce tensile ground force | `Quadrupedal_ZeroFun_v2.m:397-408` |
| Prescribed contact with geometrically invalid foot | Still integrated; validity is only encouraged through root residuals at event times | `Quadrupedal_ZeroFun_v2.m:127-178,287-299` |
| Horizontal GRF sign | Reported sign is opposite the ODE term for the same `F*sin(theta)` | `Quadrupedal_ZeroFun_v2.m:410-411,643-653` |

The last two physical interpretations are `LD`, not confirmed model defects:
the code is unambiguous, but unilateral intent and whether GRF reports the
force on the ground rather than on the body require model-owner confirmation.

