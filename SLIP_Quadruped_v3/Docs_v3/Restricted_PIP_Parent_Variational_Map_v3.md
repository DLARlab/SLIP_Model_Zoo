# Restricted vertical-parent variational map

`[M, info] = RestrictedPIPParentMatrix_v3(E, p)` computes the derivative of the synchronized-pronk return at the ordinary vertical PIP parent, in fixed-energy flight-apex coordinates `(vx, alpha, dalpha)`. It requires the exact baseline physical parameter vector `[10,10,20,20,1,1,0,0,2,0.5]`. Its vertical orbit is analytic; a four-component ODE integrates the two-by-two stance fundamental matrix. The returned matrix concerns this invariant subspace. It does not replace unrestricted quadruped derivatives, daughter correction, or attachment validation.

At the vertical parent, all four legs share zero angle, front/hind torques cancel, and the body pitch remains zero. In flight `vx` is constant and `alpha''=-20 alpha`. Write `t=sqrt(2(E-1))`, `Omega=sqrt(40)` and `a=1/40`. The touchdown state has `y=1`, `vy=-t`; subsequent stance motion is

```text
y(tau)  = 1-a + a cos(Omega tau) - (t/Omega) sin(Omega tau)
vy(tau) = -a Omega sin(Omega tau) - t cos(Omega tau)
T       = (2 pi - 2 atan(t/(a Omega)))/Omega.
```

The sum of the four axial leg stiffnesses is 40. Expanding the production horizontal force and fixed-foot angular-rate constraint about this vertical trajectory gives the stance variation

```text
d/dtau [delta vx; delta alpha]
    = [0, -40(1-y); -1/y, -vy/y] [delta vx; delta alpha].
```

The stored stance rate is dependent. Touchdown drops the incoming independent swing rate; liftoff reconstructs it as `delta dalpha=-delta vx-t delta alpha`. If `S(T)` is the stance fundamental matrix and `F(t)` is the three-dimensional flight matrix with the harmonic-oscillator block in `(alpha,dalpha)`, then

```text
R_TD = [1 0 0; 0 1 0]
L_LO = [1 0; 0 1; -1 -t]
M(E) = F(t) L_LO S(T) R_TD F(t).
```

The fixed-energy apex lift is `y=E-vx^2/2`, so its first variation in these three coordinates is zero at the parent. The contact guard `y-cos(alpha)` also has zero first variation in angle there. Vertical forcing changes only at second order under the synchronized perturbation. Consequently contact and next-apex timing changes do not add first-order terms to this restricted horizontal/leg variation. This argument uses the exact synchronized invariant subspace; it does not assert that split-contact charts elsewhere have the same higher derivatives.

The minimum parent height is `0.975-sqrt(0.025^2+2(E-1)/40)`. It is positive precisely for `1<E<20`. The lower endpoint has a grazing touchdown; the upper endpoint reaches the hip-height singularity. The helper rejects these endpoints and any nonbaseline parameter vector. A wider campaign energy domain does not make a synchronized parent physical at or above 20.

`AuditRestrictedPIPParentMatrix_v3` preregistered its thresholds before evaluating fresh matrices. Actual MATLAB R2025b results in `Research_v3/next_round/solver/pip_analytic_audit.mat/json/log` passed:

| Independent check | Observed error |
| --- | --- |
| Production stance vector-field derivative, five stance phases at each fresh energy | Maximum absolute generator error 2.0006e-11 |
| Production four-leg liftoff reset derivative | Maximum absolute error 2.4949e-12 |
| Tighter stance variational integration | Maximum relative matrix change 8.7532e-14 |
| Recorded critical matrices at E=1.5551652516426646 and 1.6959508361671367 | Relative errors 4.2399e-9 and 2.8671e-9 |
| Fresh strict hybrid finite differences at E=1.1, 3 and 8 | Relative errors 6.19e-10, 1.58e-9 and 3.50e-9; every column reliable |
| Fresh independent tighter parent replays at the same energies | Full closures 3.04e-13, 2.12e-12 and 4.66e-12 |

The source-bound registration and historical input hashes are retained. The audit script's first period-field mismatch was repaired without changing numerical thresholds; its failed log and partial JSON are separately preserved.

The authorized production shortcut is identify/refine sampling on the registered ordinary-parent interval `[1.0001,3]`, after checking the audit's pass status and helper source hash. Each queued critical point still requires its three physical finite-difference step levels and the separate mixed/transversality finite-difference samples. Analytic sampling may reduce exploratory map calls; it cannot make a finite-difference failure reliable or provide daughter evidence. The isolated E=8 validation does not authorize an unregistered campaign interval extension.
