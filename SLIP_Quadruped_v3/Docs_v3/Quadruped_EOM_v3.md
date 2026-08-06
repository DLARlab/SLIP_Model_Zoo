# Quadruped v3 equations of motion

## Model parameters

The production parameter vector is ordered exactly as follows.

| Index | Name | Meaning | Admissible values |
|---:|---|---|---|
| 1 | `k_l_b` | back-leg linear stiffness | \(>0\) |
| 2 | `k_l_f` | front-leg linear stiffness | \(>0\) |
| 3 | `k_s_b` | back-leg torsional stiffness coefficient | \(\geq0\) |
| 4 | `k_s_f` | front-leg torsional stiffness coefficient | \(\geq0\) |
| 5 | `l_l_b` | back-leg uncompressed length | \(>0\) |
| 6 | `l_l_f` | front-leg uncompressed length | \(>0\) |
| 7 | `rsla_b` | back-leg equilibrium relative swing angle | finite |
| 8 | `rsla_f` | front-leg equilibrium relative swing angle | finite |
| 9 | `j_pitch` | torso pitching inertia | \(>0\) or \(+\infty\) |
| 10 | `l_com` | COM distance from the back hip on the unit torso | \(0<l_{com}<1\) |

The family values expand in `[BL,BR,FL,FR]` order:

\[
k_l=[k_{l,b},k_{l,b},k_{l,f},k_{l,f}]^T,
\quad
k_s=[k_{s,b},k_{s,b},k_{s,f},k_{s,f}]^T,
\]

\[
l_0=[l_{l,b},l_{l,b},l_{l,f},l_{l,f}]^T,
\quad
rsla=[rsla_b,rsla_b,rsla_f,rsla_f]^T.
\]

## Coordinates and geometry

Normalized torso length, body mass, and gravitational acceleration are one.
For leg \(i\in\{BL,BR,FL,FR\}\), let

\[
s_i=\begin{cases}
-l_{com},&i\in\{BL,BR\},\\
1-l_{com},&i\in\{FL,FR\},
\end{cases}
\qquad \theta_i=\phi+\alpha_i.
\]

The coordinate \(\alpha_i\) is relative to the torso, while \(\theta_i\)
is the absolute leg angle. The hip position is

\[
r_{H,i}=\begin{bmatrix}x\\y\end{bmatrix}
+s_i\begin{bmatrix}\cos\phi\\\sin\phi\end{bmatrix}.
\]

For a stance leg whose foot lies on the ground, its length is

\[
L_i=\frac{y+s_i\sin\phi}{\cos\theta_i}.
\]

Its compression and axial force magnitude are

\[
\delta_i=l_{0,i}-L_i,
\qquad \lambda_i=k_{l,i}\delta_i.
\]

Negative compression is not clamped. An accepted stance state is admissible
only if \(\delta_i\ge-\varepsilon_{adm}\). Continuous ODE solvers can evaluate
temporary Runge--Kutta stages beyond an event root; consequently the flow
returns an admissibility diagnostic, and `assertAdmissible` rejects accepted
hybrid states below the tolerance.

## Body force and pitch equation

The force exerted by stance leg (i) on the body is

\[
f_i=q_i\lambda_i
\begin{bmatrix}-\sin\theta_i\\\cos\theta_i\end{bmatrix}.
\]

Therefore

\[
F_x=-\sum_iq_i\lambda_i\sin\theta_i,
\qquad
F_y=\sum_iq_i\lambda_i\cos\theta_i.
\]

Taking moments about the COM gives

\[
\tau=\sum_iq_i s_i\lambda_i\cos\alpha_i.
\]

The torso equations are

\[
\ddot x=F_x,
\qquad
\ddot y=F_y-1,
\qquad
\ddot\phi=\frac{\tau}{j_{pitch}}.
\]

When \(j_{pitch}=\infty\), the implementation assigns
\(\ddot\phi=0\) explicitly so that no indeterminate arithmetic is used.

## Swing-leg derivation

For an infinitesimal swing leg of length \(l_i\), the foot position is

\[
r_{F,i}=r_{H,i}+l_i
\begin{bmatrix}\sin\theta_i\\-\cos\theta_i\end{bmatrix}.
\]

Define the tangential direction

\[
t_i=\begin{bmatrix}\cos\theta_i\\\sin\theta_i\end{bmatrix}.
\]

The torsional potential is defined in the relative coordinate:

\[
V_{s,i}=\frac12 k_{s,i}(\alpha_i-rsla_i)^2.
\]

Thus `rsla_i` is the equilibrium value of \(\alpha_i\), not of the
world-frame angle \(\theta_i\). The infinitesimal-leg Euler--Lagrange
equation gives

\[
\ddot\theta_i=
-\frac{t_i^Ta_{H,i}+g\sin\theta_i}{l_i}
-\frac{k_{s,i}}{l_i^2}(\alpha_i-rsla_i).
\]

The hip acceleration is

\[
a_{H,i}=a_C
+s_i\ddot\phi
\begin{bmatrix}-\sin\phi\\\cos\phi\end{bmatrix}
-s_i\dot\phi^2
\begin{bmatrix}\cos\phi\\\sin\phi\end{bmatrix},
\]

where

\[
a_C=\begin{bmatrix}F_x\\F_y-g\end{bmatrix}.
\]

Projecting onto \(t_i\), using
\(\theta_i=\phi+\alpha_i\), and collecting the gravitational terms gives

\[
t_i^Ta_{H,i}+g\sin\theta_i
=F_x\cos\theta_i+F_y\sin\theta_i
+s_i\ddot\phi\sin\alpha_i
-s_i\dot\phi^2\cos\alpha_i.
\]

Because \(\ddot\alpha_i=\ddot\theta_i-\ddot\phi\), the implemented swing
equation is

\[
\boxed{
\ddot\alpha_i=
-\ddot\phi
-\frac{F_x\cos\theta_i+F_y\sin\theta_i}{l_i}
-\frac{s_i}{l_i}\ddot\phi\sin\alpha_i
+\frac{s_i}{l_i}\dot\phi^2\cos\alpha_i
-\frac{k_{s,i}}{l_i^2}(\alpha_i-rsla_i)
}.
\]

At \(\alpha_i=rsla_i\), the torsional contribution is exactly zero.
Increasing `rsla_i` by \(\Delta\) changes the angular acceleration by

\[
\Delta\ddot\alpha_i=\frac{k_{s,i}}{l_i^2}\Delta.
\]

## Biped limit

For

\[
\phi=0,\quad s_i=0,\quad l_i=1,\quad k_{s,i}=\omega^2,
\]

the swing equation reduces to

\[
\ddot\alpha_i=-F_x\cos\alpha_i-F_y\sin\alpha_i
-\omega^2(\alpha_i-rsla_i).
\]

The conceptual biped reference model has no torso-pitch coordinate. Its
leg-angle coordinate measured from vertical therefore coincides with this
quadruped relative-coordinate convention when \(\phi=0\).

## Stance constraint and reset

The horizontal coordinate of a stance foot can be written

\[
\xi_i=x+s_i\cos\phi
+(y+s_i\sin\phi)\tan(\phi+\alpha_i).
\]

The stance flow enforces \(\dot\xi_i=0\) and its time derivative using the
validated legacy symbolic back/front formulas. At contact transitions, the
massless-leg reset leaves every body coordinate and velocity continuous and
projects only the affected angular rate:

\[
\dot\alpha_i^+=-\dot\phi-
\frac{
\dot x-s_i\sin\phi\dot\phi
+(\dot y+s_i\cos\phi\dot\phi)\tan\theta_i
}{
(y+s_i\sin\phi)\sec^2\theta_i
}.
\]

The reset rejects a denominator or absolute-leg cosine below the documented
`SingularityTolerance`.

## Diagnostics

`ContinuousDynamics_v3.evaluate` optionally returns hip positions,
absolute leg angles, leg lengths, compression, axial forces, per-leg force
vectors, total force, pitch torque, mode, projected leg rates, and
admissibility margins. Every leg-valued diagnostic is ordered
`[BL;BR;FL;FR]`.

## Conceptual comparison

The no-torso-pitch biped comparison follows the coordinate interpretation in
the [Frontiers reference model](https://doi.org/10.3389/fbioe.2022.804826)
and its [companion implementation](https://github.com/DLARlab/2022_A_Template_Model_Explains_Jerboa_Gait_Transitions).
The equations above are the independently derived v3 quadruped contract; the
linked model is used only to explain the stated \(\phi=0\) biped limit.
