# Round 1 canonical data schema

## Conventions

This document records the schema implemented at commit
`2c106101383ecee1b2a9d695efe09fbd72d5718a`. It does not endorse every
constraint as a permanent contract. The model is nondimensional: torso mass,
gravity, and torso length are set to one in
`Quadrupedal_ZeroFun_v2.m:89,385-387,418-420`. Thus length is in body-length
units, time in `sqrt(L/g)`, translational velocity in `sqrt(gL)`, force in
`Mg`, and pitch inertia in `ML^2`. Angles are radians.

The leg labels are `B`/`F` for back/front and `L`/`R` for left/right.
Touchdown and liftoff are `TD` and `LO`. Event quantities are circular modulo
the period when the period is positive and finite; ordinary states and
parameters are linear.

## Initial state `X` (13 elements)

The integrated horizontal position is fixed to `x(0)=0`, so it is not an
unknown. The exact production unpacking is at
`SLIP_Quadruped/1_Dynamic_Frameworks/v2/Quadrupedal_ZeroFun_v2.m:52-66`.

| Index | Name | Symbol | Meaning | Units | Kind and current validity |
|---:|---|---|---|---|---|
| 1 | `dx0` | \(\dot x_0\) | Initial horizontal torso velocity | `sqrt(gL)` | Linear, finite intended; not validated |
| 2 | `y0` | \(y_0\) | Initial torso height | `L` | Linear; positive/feasible intended; not validated |
| 3 | `dy0` | \(\dot y_0\) | Initial vertical velocity | `sqrt(gL)` | Linear; apex residual later requires return value zero |
| 4 | `phi0` | \(\phi_0\) | Initial torso pitch | rad | Circular physically, stored/solved linearly |
| 5 | `dphi0` | \(\dot\phi_0\) | Initial pitch rate | `sqrt(g/L)` | Linear |
| 6 | `alphaBL0` | \(\alpha_{BL,0}\) | Back-left leg angle relative to torso | rad | Circular physically, stored/solved linearly |
| 7 | `dalphaBL0` | \(\dot\alpha_{BL,0}\) | Back-left leg angular rate | `sqrt(g/L)` | Linear |
| 8 | `alphaFL0` | \(\alpha_{FL,0}\) | Front-left leg angle relative to torso | rad | Circular physically, stored/solved linearly |
| 9 | `dalphaFL0` | \(\dot\alpha_{FL,0}\) | Front-left leg angular rate | `sqrt(g/L)` | Linear |
| 10 | `alphaBR0` | \(\alpha_{BR,0}\) | Back-right leg angle relative to torso | rad | Circular physically, stored/solved linearly |
| 11 | `dalphaBR0` | \(\dot\alpha_{BR,0}\) | Back-right leg angular rate | `sqrt(g/L)` | Linear |
| 12 | `alphaFR0` | \(\alpha_{FR,0}\) | Front-right leg angle relative to torso | rad | Circular physically, stored/solved linearly |
| 13 | `dalphaFR0` | \(\dot\alpha_{FR,0}\) | Front-right leg angular rate | `sqrt(g/L)` | Linear |

## Event vector `E` (9 elements)

Production normalizes elements 1–8 with `mod(event,T)` and leaves element 9
as the period (`EventTimingRegulation.m:17-37`). For valid `T>0`, normalized
events lie in `[0,T)`, despite the production comment saying `[0,T]`.

| Index | Name | Symbol | Meaning | Units | Kind and current validity |
|---:|---|---|---|---|---|
| 1 | `tBL_TD` | \(t^{TD}_{BL}\) | Back-left touchdown | `sqrt(L/g)` | Circular modulo `T`; normalized to `[0,T)` |
| 2 | `tBL_LO` | \(t^{LO}_{BL}\) | Back-left liftoff | `sqrt(L/g)` | Circular modulo `T`; normalized to `[0,T)` |
| 3 | `tFL_TD` | \(t^{TD}_{FL}\) | Front-left touchdown | `sqrt(L/g)` | Circular modulo `T`; normalized to `[0,T)` |
| 4 | `tFL_LO` | \(t^{LO}_{FL}\) | Front-left liftoff | `sqrt(L/g)` | Circular modulo `T`; normalized to `[0,T)` |
| 5 | `tBR_TD` | \(t^{TD}_{BR}\) | Back-right touchdown | `sqrt(L/g)` | Circular modulo `T`; normalized to `[0,T)` |
| 6 | `tBR_LO` | \(t^{LO}_{BR}\) | Back-right liftoff | `sqrt(L/g)` | Circular modulo `T`; normalized to `[0,T)` |
| 7 | `tFR_TD` | \(t^{TD}_{FR}\) | Front-right touchdown | `sqrt(L/g)` | Circular modulo `T`; normalized to `[0,T)` |
| 8 | `tFR_LO` | \(t^{LO}_{FR}\) | Front-right liftoff | `sqrt(L/g)` | Circular modulo `T`; normalized to `[0,T)` |
| 9 | `tAPEX` | \(T\) | Stride period and prescribed return time | `sqrt(L/g)` | Positive finite required mathematically; not validated |

The production contact predicate is strict-open. For one leg,
\[
\chi(t;t_{TD},t_{LO}) =
\begin{cases}
t_{TD}<t<t_{LO},&t_{TD}<t_{LO},\\
t<t_{LO}\ \lor\ t>t_{TD},&t_{TD}>t_{LO},\\
\mathrm{false},&t_{TD}=t_{LO}.
\end{cases}
\]
Therefore `TD>LO` represents a wrapped stance and `TD=LO` represents no
stance in the dynamics.

## Parameter vector `Para` (7 elements)

The implemented order is defined at
`Quadrupedal_ZeroFun_v2.m:92-106`; the five-element order in that file's
header and `SolveQuadrupedalZE.m:10` is stale.

| Index | Name | Symbol | Meaning | Units | Kind and current validity |
|---:|---|---|---|---|---|
| 1 | `k` | \(k\) | Mean linear leg stiffness | `Mg/L` | Positive finite intended; not validated |
| 2 | `ks` | \(k_s\) | Swing angular stiffness coefficient | nondimensional in implemented equations | Nonnegative finite intended; not validated |
| 3 | `J` | \(J\) | Torso pitch inertia | `ML^2` | Positive finite or exactly `Inf`; zero/negative not rejected |
| 4 | `l` | \(\ell_0\) | Resting leg length / normalized body length | `L` | Positive finite intended; appears in denominators; not validated |
| 5 | `osa` | \(\alpha_0\) | Documented neutral swing-leg angle | rad | Linear/circular; parsed and returned but unused by dynamics |
| 6 | `lb` | \(\ell_b\) | COM-to-back-hip fraction of normalized torso length | nondimensional | Intended `0<lb<1`; not validated |
| 7 | `kr` | \(k_r=k_b/k_f\) | Back/front stiffness ratio | nondimensional | Positive finite intended; `0` and `-1` are singular/invalid; not validated |

Production derives
\[
k_b=\frac{2k}{1+1/k_r},\qquad k_f=\frac{2k}{1+k_r}.
\]

## Integrated state `Y` (14 columns)

The order is constructed at `Quadrupedal_ZeroFun_v2.m:115-117` and unpacked
again at lines 369–383.

| Index | Name | Symbol | Meaning | Units | Kind |
|---:|---|---|---|---|---|
| 1 | `x` | \(x\) | Horizontal torso position | `L` | Linear; translational gauge |
| 2 | `dx` | \(\dot x\) | Horizontal torso velocity | `sqrt(gL)` | Linear |
| 3 | `y` | \(y\) | Vertical torso position | `L` | Linear |
| 4 | `dy` | \(\dot y\) | Vertical torso velocity | `sqrt(gL)` | Linear |
| 5 | `phi` | \(\phi\) | Torso pitch | rad | Circular physically, integrated linearly |
| 6 | `dphi` | \(\dot\phi\) | Torso pitch rate | `sqrt(g/L)` | Linear |
| 7 | `alphaBL` | \(\alpha_{BL}\) | Back-left leg angle | rad | Circular physically |
| 8 | `dalphaBL` | \(\dot\alpha_{BL}\) | Back-left angular rate | `sqrt(g/L)` | Linear |
| 9 | `alphaFL` | \(\alpha_{FL}\) | Front-left leg angle | rad | Circular physically |
| 10 | `dalphaFL` | \(\dot\alpha_{FL}\) | Front-left angular rate | `sqrt(g/L)` | Linear |
| 11 | `alphaBR` | \(\alpha_{BR}\) | Back-right leg angle | rad | Circular physically |
| 12 | `dalphaBR` | \(\dot\alpha_{BR}\) | Back-right angular rate | `sqrt(g/L)` | Linear |
| 13 | `alphaFR` | \(\alpha_{FR}\) | Front-right leg angle | rad | Circular physically |
| 14 | `dalphaFR` | \(\dot\alpha_{FR}\) | Front-right angular rate | `sqrt(g/L)` | Linear |

## Output parameter vector `P` (16 elements)

`P` is `[E; Para]` in row form, constructed at
`Quadrupedal_ZeroFun_v2.m:260`:

| Indices | Contents |
|---|---|
| 1–9 | `tBL_TD, tBL_LO, tFL_TD, tFL_LO, tBR_TD, tBR_LO, tFR_TD, tFR_LO, tAPEX` |
| 10–16 | `k, ks, J, l, osa, lb, kr` |

It is an output/graphics transport vector, not an independent model schema.
Graphics code hard-codes these positions, notably
`ComputeJoint_LegLA.m:8-23`, `ComputePhaseDiagram.m:3-21`, and
`SLIP_Animation_Quad.m:40-56`.

## Periodic-orbit unknown `z` (22 elements)

\[
z=[X_1,\ldots,X_{13},E_1,\ldots,E_9]^T.
\]

Thus rows 1–13 use the `X` table and rows 14–22 use the `E` table. The input
parser accepts `X,E,Para` separately or supported concatenations
(`Quadrupedal_ZeroFun_v2.m:712-779`).

## Saved branch `results` (29 rows)

Each column is one candidate solution:

| Rows | Contents | Contract |
|---|---|---|
| 1–13 | Initial state `X` | Exact order above |
| 14–22 | Event vector `E` | Exact order above |
| 23–29 | Parameters `Para` | Exact order above |

All nine repository MAT files contain one numeric, finite, two-dimensional
`results` array with exactly 29 rows. The observed column counts are:

| File | Columns |
|---|---:|
| `BD1_20_2_BE.mat` | 443 |
| `BD1_20_2_BG.mat` | 474 |
| `BD1_20_2_FE.mat` | 228 |
| `BD1_20_2_FG.mat` | 212 |
| `BD1_20_2_GE.mat` | 200 |
| `BD1_20_2_GG.mat` | 277 |
| `BD1_20_2_HE.mat` | 180 |
| `BD1_20_2_HG.mat` | 538 |
| `PK_20_2.mat` | 891 |

Across all 3,443 stored columns the parameter vector is constant at
`[10,20,2,1,0,0.5,1]`. No stored column has `TD>LO` for any leg, so no
repository branch exercises wrapped stance representation.

## Independent schema copies and inconsistencies

| Location | Copy | Round 1 observation |
|---|---|---|
| `Quadrupedal_ZeroFun_v2.m:1` | Parameter header | Stale five-element order and places `lb` before `l`; production uses seven elements |
| `Quadrupedal_ZeroFun_v2.m:52-106,260,688-779` | Authoritative runtime unpack/parser/output | Internally agrees on 13/9/7 and 16-output order, except parser comments still mention obsolete 14/2/6 inputs |
| `SLIP_Quadruped/README.md:34-38` | Saved `results` rows | Agrees on 13/9/7 row groups but does not enumerate elements |
| `SLIP_Quadruped_GUI.m:18-30,3701` | GUI labels and save layout | Agrees on 13/9/7 and `[X;E;Para]` |
| `NumericalContinuation1D_Quadruped_v2.m:27-33` | Branch persistence | Saves `[X(22);Para(7)]`, agreeing with 29 rows |
| `NumericalContinuation2D_Quadruped_v2.m:226-229` | Parameter selection | Assumes index exists and is finite but does not enforce exact seven-element schema |
| `ParameterVarying2D_Quadruped_v2.m:3-16` | Parameter-name switch | Hard-coded seven parameter keys; legacy file loader assumes a `results` variable |
| `SolveQuadrupedalZE.m:10` | Parameter comment | Stale five-element ordering; executable passes input through without schema validation |
| Graphics functions | `P` indexing | Multiple independent hard-coded copies; currently consistent with the 16-element production output |
| MAT filenames | Gait/parameter metadata | Informal implicit API only; loaders primarily trust the `results` variable rather than validated metadata |

