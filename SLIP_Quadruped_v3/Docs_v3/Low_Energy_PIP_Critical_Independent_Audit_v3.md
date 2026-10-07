# Independent check of the low-energy PIP/PK candidate

The new `PIP_PK_low_energy_neighborhood` data support a numerically identified critical point and nontrivial corrected daughters in the exact synchronized-pronk restriction. They do not yet establish identity with a saved imported PK orbit or attachment to the imported PK component. The restricted return is analytic by the existing model derivation; the named critical root's exact simplicity and transversality remain supported numerically without interval error bounds.

The [focused audit](../P1_Single_Flight_Phase_Continua/Bifurcation_Audits/PIP_to_PK/low_energy_critical_20261007T143707040/audit.json) used 16 explicit redetected BL-map calls in 40.80 seconds. Before evaluating any return, it preserved byte-identical source snapshots and SHA256 records in the [prospective registration](../P1_Single_Flight_Phase_Continua/Bifurcation_Audits/PIP_to_PK/low_energy_critical_20261007T143707040/registration.json). The [MAT evidence](../P1_Single_Flight_Phase_Continua/Bifurcation_Audits/PIP_to_PK/low_energy_critical_20261007T143707040/audit.mat) contains actual finite-difference signatures and fresh replay traces. All registered engine hashes stayed unchanged. The snapshot contains six accepted signed daughter records and 65 historical/validation imported PK point records; these counts are saved records, not new simulations or distinct physical solutions.

| Independent check | Result |
|---|---:|
| Saved parent critical energy | 1.1171137022972106 |
| Independently located restricted determinant root | 1.11711370210144 |
| Difference of root energies | −1.96e−10 |
| Actual redetected derivative versus restricted matrix | 4.19e−10 |
| Actual derivative step-refinement difference | 1.32e−9 |
| Restricted variational integration refinement | 2.14e−13 |
| Two independent transversality estimates | 1.72124618, 1.72124596 |
| Saved transversality estimate and empirical uncertainty | 1.72124604 ± 0.00221989 |
| Fresh vertical-parent full closure | 3.32e−13 |
| Parent minimum stance height | 0.89449730 |

The independent restricted multipliers are approximately `1,−0.273931956,0`. Singular values of `DP−I` are `5.521546972,0.714407807,9.95e−15`; the small value is a numerical root residual rather than a certified exact zero. Its kernel direction in `(dx,common_alpha,common_beta)` is approximately `[0.544424413,0,0.838809906]`, aligned with the saved direction to numerical precision. The matrix comparison used `1e−5` and `5e−6` physical-coordinate steps, with ODE tolerances `1e−12/1e−14`, maximum step `0.005` and separately registered event/arming tolerances. [Independent variational equations](../3_Numerical_Continuation/3_Bifurcation_Analysis/RestrictedPIPParentMatrix_v3.m).

Fresh replay of the selected `+0.0001` and `−0.01` daughters gives full closure `1.25e−12` and `9.16e−13`; fresh replay of the imported minimum-energy validation point gives `4.08e−12`. These preserve the numerical acceptance evidence. They do not provide rigorous orbit error bounds or a new global continuation.

## Exact restricted regularity and the conditional theorem

For exact baseline `p=[10,10,20,20,1,1,0,0,2,0.5]`, the synchronized-pronk fixed-energy flight-apex chart is `u=(dx,alpha,beta)`, `y=E−dx²/2`. At every vertical parent with `1<E<20`, stance height is positive, common TD/LO are transverse, interior compression is positive and the flight-apex crossing is transverse. The common flow, guards and massless-leg rate reset are analytic there. The exact BL marking is preserved in a sufficiently small restricted neighborhood. Thus the exact restricted residual `G(u,E)=P_E(u)−u` is analytic; restricted C² is not a missing hypothesis here. This statement concerns the invariant common-contact restriction. It does not supply unrestricted C² across split-order charts. [Analytic chart and model derivation](Restricted_Odd_Quarter_PIP_Existence_v3.md), [actual flow](../1_Dynamic_Frameworks/Dynamics_v3/ContinuousDynamics_v3.m), [guards](../1_Dynamic_Frameworks/Dynamics_v3/GuardFunctions_v3.m), [reset](../1_Dynamic_Frameworks/Dynamics_v3/ResetMap_v3.m), [BL mark](../4_Solution_Management/BLMarkedApexReturnPolicy_v3.m).

At an exact critical energy E*, if `D_uG(0,E*)` has one-dimensional kernel/cokernel and `w'*D_E D_uG(0,E*)*v≠0`, the simple-eigenvalue theorem gives an actual local curve of nontrivial restricted periodic solutions. The finite matrices and two independent crossing estimates above support those remaining hypotheses at the identified low-energy root. They do not certify them with interval bounds, so this is a conditional local theorem at the named root, not a certified numerical theorem. [Original Crandall–Rabinowitz theorem 1.7](https://jxshix.people.wm.edu/2013-taiwan/crandall-rabinowitz-1971-JFA.pdf).

There is an additional exact broad-interval fact. Using the stance fundamental matrix `S=[[A,B],[C,A]]`, with `A>1`, `B<−(A+1)t` and `det S=1`, write

`det(DP−I)=−2*cos(theta)*H(E)`,

`H(E)=(1−A)*cos(theta)+((A−1)t+B)*sin(theta)/sqrt(20)`,

`theta=sqrt(20)*t`, `t=sqrt(2(E−1))`.

At `theta=pi/2`, `H<0`; at `theta=pi`, `H=A−1>0`. Continuity therefore guarantees at least one additional restricted unit critical energy strictly between `1+pi²/160` and `1+pi²/40`, approximately `1.06168503` and `1.24674011`. This argument establishes a critical energy somewhere in the interval. It does not establish a unique root, a simple crossing, a branch curve at that root or the identification of the exact root with the finite value `1.11711370210144`.

Conditional on a simple unit root in that interval, its kernel's stance velocity cannot vanish, since B is nonzero. Stance endpoint relations give `z(T)=−z(0)` for `z=y*alpha`; symmetry and `z''=40*(1−y)*z/y` make z antisymmetric and `dx=−z'` strictly of one sign through stance. Flight velocity has the same sign. The first-order drift is therefore nonzero. Also, `cos(theta)≠0` inside the interval implies the apex kernel common angle is exactly zero. These statements agree with the measured kernel and identify the conditional local nontrivial solutions as traveling pronk within the restriction. They do not identify an imported PK component. Reflection gives opposite-drift signed partners; no nonzero quadratic energy coefficient or full-space normal form is claimed.

## Imported PK nearness and limits

The minimum sampled validation PK point has energy `1.1171142328164629`. Relative to the saved critical vertical parent, its energy gap is `5.3052e−7`, physical apex gap about `0.00164`, period gap `1.1626e−7` and horizontal drift gap `0.001638`. It is a finite sampled turn; no exact fold location is certified. The selected `+0.0001` daughter has closest imported physical-apex gap `0.00155581`, energy gap `5.3783e−7` and reflected drift gap `0.00155417`. The largest saved `−0.01` daughter is closer to a historical imported point: apex gap `0.000373420`, energy gap `1.2653e−6`, period gap `2.6997e−7` and reflected drift gap `0.000373031`.

These comparisons remove only constant horizontal translation and allow the independently established baseline synchronized-pronk horizontal reflection. Both sides retain their exact parameter vectors, individual energies, periods, drifts and contact occurrence counts. Different conservative energies exclude identity of the individual exact orbits if the numerical values are validated; the present finite measurements supply distinct sampled records without certified orbit error bounds. They do not exclude ancestry or prove an attachment. Equal descriptive PK labels, a nearby turning energy and even a close finite sample cannot replace a continued branch with demonstrated physical chart transport and matching states. The final event-aware trajectory comparison will use the later continuation snapshots separately.
