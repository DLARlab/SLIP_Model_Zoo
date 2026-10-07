# Local traveling-pronk existence at the odd-quarter PIP resonances

This is an analytic statement about the ideal v3 hybrid model at the exact baseline physical parameters `p=[10,10,20,20,1,1,0,0,2,0.5]`. It concerns the invariant synchronized-pronk restriction, with pitch and pitch rate zero, identical leg angles/rates, and identical contact bits. It does not assert C² regularity of the unrestricted split-contact map or an attachment to a historical imported branch. The finite-tolerance MATLAB simulator approximates this exact return; numerical matrices provide independent model checks and do not replace the proof.

## The invariant analytic return

Matched leg parameters and centered COM make all four guards identical and cancel the front/hind torques in this restriction. Flight has `v'=0`, `y''=−1`, and `alpha''=−20 alpha`. During all-leg stance, the geometric constraint gives

`alpha'=−[v cos²(alpha)+y' sin(alpha)cos(alpha)]/y`.

The common reset sets the leg rate to that expression. All forces, guards and resets have analytic extensions when `y>0` and `cos(alpha)>0`; the force implementation does not clamp spring compression at an ODE trial stage. [Actual force and swing equations](../1_Dynamic_Frameworks/Dynamics_v3/ContinuousDynamics_v3.m), [guards](../1_Dynamic_Frameworks/Dynamics_v3/GuardFunctions_v3.m), [reset](../1_Dynamic_Frameworks/Dynamics_v3/ResetMap_v3.m).

On the flight apex, use the three independent fixed-energy coordinates `u=(v,alpha,beta)` and set `y=E−v²/2`; `beta` is the common swing rate. Let `P_E` denote the horizontal-translation-reduced, single-BL-marked return in this invariant restriction. The vertical parent is `u=0` for every `1<E<20`. Put

`t=sqrt(2(E−1)), omega=sqrt(20), Omega=sqrt(40), a0=1/40`.

Here t is each flight half-duration. Stance height and duration are

`y(tau)=1−a0+a0 cos(Omega*tau)−(t/Omega)sin(Omega*tau)`,

`T=(2*pi−2*atan(t/(a0*Omega)))/Omega`.

The endpoints satisfy `y(0)=y(T)=1`, `y'(0)=−t`, `y'(T)=t`. Height is symmetric about `T/2`. Its minimum is

`1−a0−sqrt(a0²+t²/40)>0` precisely when `E<20`.

For `1<E<20`, spring compression is strictly positive in the stance interior, touchdown/liftoff are transverse with speed magnitude t, and the flight apex has `dy/dtime=−1`. Near each such parent, the common touchdown, common liftoff and accepted flight-apex times are analytic by the implicit function theorem. Within this invariant restriction, the event identity remains a single common guard rather than a variable ordering of four split contacts. Thus `P_E(u)` is analytic on a neighborhood of the parent. The first-order fixed-energy vertical perturbation and all first-order event-time shifts vanish at `u=0`. [Independent restricted variational implementation](../3_Numerical_Continuation/3_Bifurcation_Analysis/RestrictedPIPParentMatrix_v3.m), [BL occurrence ownership](../4_Solution_Management/BLMarkedApexReturnPolicy_v3.m).

## Stance symmetry and the return determinant

Set `z=y*alpha` in the parent variational equation. The horizontal and common-leg perturbations satisfy

`v'=−a(tau)*z`, `z'=−v`, `a(tau)=40(1−y(tau))/y(tau)`.

The coefficient a is nonnegative, strictly positive in the interior, and symmetric about `T/2`. Let S be the fundamental matrix on `(v,z)` over stance. Its trace-zero generator gives `det(S)=1`. Reversing time with `R=diag(1,−1)` gives `S=R*S^(−1)*R`, so

`S=[[A,B],[C,A]], A>1, B<0, C<0`.

The strict signs follow directly from `z''=a*z`: initial data `(z,z')=(1,0)` give positive final derivative, while `(0,−1)` give a strictly negative decreasing solution. Because y is one at both endpoints, this S is also the endpoint matrix on `(v,alpha)` used by the MATLAB helper.

Write F(t) for the flight swing rotation on `(v,alpha,beta)`, R0 for touchdown extraction `(v,alpha,beta)->(v,alpha)`, and L for the liftoff lift

`L(v,alpha)=(v,alpha,−v−t*alpha)`.

Then the apex derivative is `M=F(t)*L*S*R0*F(t)`. Its two nonzero eigenvalues are those of `S*Q`, where

`Q=R0*F(2t)*L=[[1,0],[-sin(2*omega*t)/omega, cos(2*omega*t)−t*sin(2*omega*t)/omega]]`.

Since M has one zero eigenvalue, `det(M−I)=−det(S*Q−I)`. With `theta=omega*t`, direct expansion yields

`D(E):=det(S*Q−I)=2*cos(theta)*[(1−A)*cos(theta)+((A−1)*t+B)*sin(theta)/omega]`.

The minus sign between the two determinants is material for interpreting determinant slopes; it does not change their zeros or the nonzero-transversality conclusion.

## Exact simple crossing

At `theta=(2n+1)*pi/2`, Q is `diag(1,−1)`. Therefore S*Q has trace zero and determinant minus one, and the restricted apex derivative has the three **exact** multipliers `+1,−1,0`. The `+1` multiplier is simple in this three-dimensional fixed-energy restriction.

At these resonances, all derivatives of A and B in D are multiplied by `cos(theta)=0`. Consequently

`D'(E_n)=−2*((A−1)*t+B)/t`.

To prove this does not vanish, take the homogeneous stance solution `z_h''=a*z_h` with `z_h(0)=1`, `z_h'(0)=−t`, and compare it with the parent height. Because `y''=a*y−1`, their difference r satisfies

`r''=a*r+1`, `r(0)=r'(0)=0`.

Its Volterra integral equation has nonnegative kernel and positive forcing, so `r(tau)>0` and `r'(tau)>0` for positive tau. Thus `z_h'(T)>y'(T)=t`. In `(v,z)` coordinates the homogeneous initial vector is `(t,1)`, giving

`A*t+B=−z_h'(T)<−t`, hence `B<−(A+1)*t`.

It follows that `((A−1)*t+B)<−2*t` and therefore **`D'(E_n)>4`**. In particular, `d/dE det(M−I)=−D'(E_n)<−4` is nonzero. This is an analytic inequality, independent of numerically integrated values of A and B.

The resonance energies are

`E_n=1+(2n+1)²*pi²/160`.

The admissible vertical interval contains `n=0,...,8`. Its first two values are approximately `E_0=1.0616850275068086` and `E_1=1.5551652475612765`. The executed full-space PIP seed has energy `1.5551652516426646`, about `4.08e−9` above the exact n1 formula; it is a nearby numerical parent, not an exact symbolic resonance value.

## The local branch and nonzero drift

Define `G(u,E)=P_E(u)−u`. Its analyticity, `G(0,E)=0`, simple kernel/cokernel of `D_u G=M−I`, and the nonzero determinant derivative establish the simple-branch transversality condition. The local simple-eigenvalue bifurcation theorem therefore gives a nontrivial local curve of fixed points of this restricted return near each E_n. [Crandall–Rabinowitz, original theorem 1.7 and regularity statement](https://jxshix.people.wm.edu/2013-taiwan/crandall-rabinowitz-1971-JFA.pdf).

To identify its drift, use the stance-entry kernel convention `Q*S*w0=w0`, not the stance-exit eigenvector convention `S*Q*w=w`. At odd quarter phase, this says

`v(T)=v(0)`, `z(T)=−z(0)`.

Here `v0` cannot vanish because B is nonzero. Choose `v0>0`; then `(A−1)*v0+B*z0=0` implies `z0>0`. Time reversal and uniqueness give `z(tau)=−z(T−tau)` and symmetric v. The equation `z''=a*z` cannot turn from a positive decreasing solution into a negative endpoint after its derivative has reached zero. After its first zero, its derivative remains negative. Therefore z crosses zero once at `T/2` and `v=−z'>0` throughout stance. The first-order horizontal drift over the entire return is

`Delta'=2*t*v0+integral_0^T v(tau) d tau>0`.

The nontrivial local solutions consequently have nonzero drift for sufficiently small nonzero signed amplitude. All legs remain synchronized, pitch stays zero, and the single common TD/LO pair and positive flight interval persist. These are physical traveling-pronk (PK) relative periodic solutions of the original model through its invariant restriction.

Horizontal reflection acts here as `u->−u`, leaving energy unchanged. Uniqueness of the local nontrivial curve, parameterized by a linear signed kernel coordinate, makes E an even function of that coordinate. This establishes opposite-drift reflected solutions. It does **not** establish a nonzero quadratic energy shift, a supercritical/subcritical orientation, or a nondegenerate pitchfork normal form; those need higher-order coefficients.

This proof establishes local restricted existence. The additional unrestricted flip modes and pitch sectors require their own analysis, and the full physical map's C² regularity is not supplied by the restricted analytic argument. It also does not identify which historical imported PK component, if any, connects to these branches. Distinct energies distinguish individual conservative orbits, while global continuation and physical chart transport are needed to establish ancestry.

The separate MATLAB algebra audit checks n0, n1 and n2 using the actual restricted variational implementation. It confirms the determinant sign relation and slopes approximately `8.08858`, `5.31448` and `4.88121`, with negative margins in `B+(A+1)t`. These finite calculations check the implementation against the derivation; the strict slope bound above is proved analytically. [Executed algebra/sign checks](../P1_Single_Flight_Phase_Continua/Bifurcation_Audits/PIP_to_PK/Theory/restricted_odd_quarter_proof_audit.json).
