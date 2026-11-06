# Bifurcation assumptions for the current C1 campaign

Original source audit, 2026-10-21. Its source propositions remain conditional. The dated 2026-10-22 supplement below separately reports closed native numerical evidence without asserting an attachment.
“C1” in the campaign means one physical flight per primitive cycle; mathematical **C^1** means a continuously differentiable map. These are separate properties.
H means hind spread/fore synchronized; F means fore spread/hind synchronized (S15).
FG→G and HE→G below mean breaking the remaining synchronized pair while retaining the parent's existing spread and posture convention; labels alone do not establish an edge.

## Source anchors

- **S1** [QuadrupedSchema_v3.m:39–91,185–201](/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped_v3/1_Dynamic_Frameworks/Schema_v3/QuadrupedSchema_v3.m:39).
- **S2** [GuardFunctions_v3.m:48–87,99–137](/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped_v3/1_Dynamic_Frameworks/Dynamics_v3/GuardFunctions_v3.m:48).
- **S3** [ResetMap_v3.m:50–128](/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped_v3/1_Dynamic_Frameworks/Dynamics_v3/ResetMap_v3.m:50).
- **S4** [ContinuousDynamics_v3.m:83–154,266–302,334–382](/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped_v3/1_Dynamic_Frameworks/Dynamics_v3/ContinuousDynamics_v3.m:83).
- **S5** [Quadrupedal_Dynamics_v3.m:88–149](/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped_v3/1_Dynamic_Frameworks/Dynamics_v3/Quadrupedal_Dynamics_v3.m:88).
- **S6** [QuadrupedPhysicalChart_v3.m:36–85,106–129,162 onward](/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped_v3/1_Dynamic_Frameworks/Dynamics_v3/QuadrupedPhysicalChart_v3.m:36).
- **S7** [HybridSimulator_v3.m:135–200,502–565](/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped_v3/1_Dynamic_Frameworks/Simulation_v3/HybridSimulator_v3.m:135).
- **S8** [EventDetector_v3.m:378–410,458–485,538–550](/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped_v3/1_Dynamic_Frameworks/Simulation_v3/EventDetector_v3.m:378).
- **S9** [BLMarkedApexReturnPolicy_v3.m:25–39,43–107](/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped_v3/4_Solution_Management/BLMarkedApexReturnPolicy_v3.m:25).
- **S10** [EnergyFamilyResidual_v3.m:41–105,136–164](/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped_v3/4_Solution_Management/EnergyFamilyResidual_v3.m:41).
- **S11** [HybridFiniteDifferenceJacobian_v3.m:478–507](/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped_v3/3_Numerical_Continuation/1_Root_Solving/HybridFiniteDifferenceJacobian_v3.m:478).
- **S12** [EventOrderChartJacobian_v3.m:72–148](/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped_v3/3_Numerical_Continuation/1_Root_Solving/EventOrderChartJacobian_v3.m:72).
- **S13** [FloquetAnalysis_v3.m:55–94,117–163,455–508](/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped_v3/3_Numerical_Continuation/3_Bifurcation_Analysis/FloquetAnalysis_v3.m:55).
- **S14** [SymmetryRestrictedFloquet_v3.m:43–85](/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped_v3/3_Numerical_Continuation/3_Bifurcation_Analysis/SymmetryRestrictedFloquet_v3.m:43).
- **S15** [GaitIdentification_v3.m:201–207](/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped_v3/4_Solution_Management/GaitIdentification_v3.m:201).
- **S16** [RunC1DaughterSearch_v3.m:59–98,187–207](/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped_v3/Research_v3/C1/RunC1DaughterSearch_v3.m:59).
- **S17** [Quadrupedal_ZeroFun_v2.m:33–44,70–83,113–120](/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped/1_Dynamic_Frameworks/v2/Quadrupedal_ZeroFun_v2.m:33).

## Exact default-model contact identities

Leg order is BL, BR, FL, FR. For leg i, write its relative angle/rate as (alpha_i, omega_i), hip offset s_i, rest length l_i, and theta_i=phi+alpha_i (S1).
The enabled TD and LO share the guard

`g_i = y + s_i sin(phi) - l_i cos(theta_i)`.

TD uses negative and LO positive crossing direction; their pre-contact mode bits differ. Transversality uses **Dg_i F**, including the actual stance-projected angular velocity, rather than blindly substituting the stored omega_i (S2).

The default reset R_i leaves body position/velocity and all other legs unchanged, setting only

`omega_i = -dphi - [dx - s_i sin(phi)dphi + (dy+s_i cos(phi)dphi)tan(theta_i)] / [(y+s_i sin(phi))/cos(theta_i)^2]`.

It depends only on the body and alpha_i, not another leg's angle/rate or the previous omega_i. Thus, for distinct legs and nonsingular geometry,

`R_i R_j = R_j R_i`, `g_j R_i = g_j`, and the mode-bit transitions commute.

The implementation rejects two events on one leg in a batch; it checks forward/reverse reset agreement and isolation before reporting an atomic batch (S3, S5). These checks alone are not a smooth-return-map theorem.
On an already physical stance state, LO's projection is the identity **on the stance manifold**; its ambient derivative must still be pulled back through that manifold (S3, S6).

At the exact guard g_i=0 with cos(theta_i) nonzero, stance length equals l_i, so the added/removed axial spring force is zero.
Body acceleration/torque consequently agree across that switch. Other-leg flow also agrees: its equations depend on body forces and its own coordinates, and not on omega_i (S4).
This applies to distinct-leg TD–TD, LO–LO, and mixed TD–LO intersections with enabled pre-modes. It does not authorize a same-leg TD/LO collision or guarantee a physical continuation after a contact.

## Conditional first-derivative compatibility, including event times

For a transverse, autonomous switch in a common ambient representation, the event-time correction is

`S_i = DR_i + b_i n_i^T / d_i`,
`b_i = F_after(R_i x) - DR_i F_before(x)`, `n_i = Dg_i`, `d_i = n_i^T F_before(x) != 0`.

At a common exact distinct-leg guard intersection, the preceding source identities imply:

- b_i has support only in leg i's angle/rate rows: the reset has no body impulse and the boundary force is zero.
- For j≠i, n_j b_i=0 and DR_j b_i=b_i. DR_i and DR_j commute.
- Resetting/toggling j leaves b_i and d_i unchanged there; the common body variables, leg-i geometry, body force and leg-i incoming flow are unchanged.

Therefore the two adjacent-order saltation products agree,

`S_j(after i) S_i = S_i(after j) S_j`,

with physical tangent lifts/retractions at the intervening modes. This addresses LO as well as TD; it is stronger than commuting state resets.
No equal-normal independence assumption is needed: synchronized guard normals can coincide. Each relevant event must nevertheless have a nonzero true Lie derivative.

A local **C^1 return map is supported conditionally** if all of the following hold:

1. The actual default component equations apply, their physical stance flow is tangent to the constraint manifold, and chart/projection denominators stay uniformly away from zero.
2. Every realized neighboring event order is a smooth transverse branch with the same enabled-event multiset, no accumulation, stable return multiplicity, and a fixed initial/final section chart.
3. Those branches remain physically admissible, including the post-TD direction/contact constraints; no grazing, lost event, extra contact, or active admissibility boundary intervenes.
4. Branch values and first derivatives extend continuously to the switching boundaries; the above compatibility holds at every adjacent interchange needed to connect the realized orders.

Under these hypotheses the finitely many event-order pieces glue with a common first derivative. The source algebra identifies a route to this conclusion; this audit has not verified all hypotheses for any saved orbit or all its perturbations.
It establishes neither C^2/C^3 regularity nor a smooth global hybrid state space. If a condition fails, the map may be undefined, only piecewise differentiable, or nonsmooth; that must be diagnosed for the actual case.

Finite arming, root and clustering thresholds are separate numerical mechanisms (S8). A finite near-zero guard can carry nonzero force, and an unarmed contact can be excluded from a batch. Exact-surface identities cannot be applied to those values without a convergence/error assessment.
Accepted-segment and post-reset physical checks remain necessary (S7); no physical gate or tolerance is relaxed by this argument.

## Pair symmetry and the marked section

At fixed physical p, swapping BL↔BR or FL↔FR permutes the corresponding (angle,rate,mode) coordinates and fixes the body.
S1 expands each hind parameter twice, each fore parameter twice, and uses s_BL=s_BR and s_FL=s_FR. The default flow, guards, resets and physical retraction therefore respect these two independent Z2 actions (S1–S4, S6).
Neither within-pair symmetry requires equal fore/hind stiffnesses, lengths or rest angles, nor l_com=0.5.
The ten physical parameters end in **j_pitch, l_com**; appended E is the orbit-energy continuation variable, not an eleventh physical parameter (S1, S10).

F's remaining action is hind exchange; H's is fore exchange. The pair-invariant correction charts enforce equal raw angles, physical rates and modes for that pair (S10).
Pronk's additional reduction explicitly requires matched fore/hind parameters, centered COM, zero pitch/rate and synchronous legs. Those extra assumptions cannot be inferred from pair symmetry.
At PK, both pair symmetries are unbroken; multiple odd critical modes can coexist. A larger D4-type action would need its own coordinate/parameter proof, and a near-unit eigenvalue at PK does not establish a simple secondary pitchfork.

The BL policy globally distinguishes BL (S9). Fore exchange fixes BL and hence preserves its marking whenever the surrounding chart is valid.
Hind exchange interchanges BL/BR, so global policy equivariance cannot be assumed. However, at a hind-synchronized parent the TDs coincide.
If both TDs and their small split continuations stay strictly between the **same consecutive downward apexes**, with positive margins to both apexes, stable occurrence counts/mode closure and no intervening new apex, “last apex before BL” and “last apex before BR” select the same local apex.
Then the local return section can remain unchanged under hind exchange. Recorded BL margins alone do not verify the required BR neighborhood or all return occurrences.
If the named section changes, one must first construct and verify the section-transport conjugacy; matrices from different section maps cannot simply be compared.

## What a refused derivative does and does not establish

Strict HybridFiniteDifferenceJacobian requires matching cyclic, section and cluster signatures (S11). A synchronized pair can split into the opposite scalar orders under ±odd perturbations.
Such refusal is a conservative chart refusal **when** the compatibility and local-section conditions above hold; it is not evidence by itself that the ideal return map lacks a classical derivative.
Conversely, reset commutation and an accepted finite difference do not certify that derivative.

EventOrderChartJacobian is an existing model-specific route: it requires the default components, flight-to-flight section, fixed p, transverse admissible closed cycles, no section-coincident event, and one TD/LO per leg in separated all-TD/all-LO cohorts (S12).
It retains raw signatures while normalizing only compatibility metadata. Its finite guard/cohort checks and step agreement are numerical evidence under declared hypotheses, not an exact smoothness theorem. Mixed/interleaved cohorts remain outside this operator's declared chart even where the contact algebra above is compatible.
SymmetryRestrictedFloquet labels the supplied block; a Fix(pair) block is the **even** restriction and is not automatically the missing odd block (S14).

At a flight apex fixed by the remaining pair action, the odd tangent is two-dimensional: angle difference and rate difference of that pair, with the body/even coordinates zero.
If the local map is differentiable and equivariant, its derivative preserves this space, so body/even output is zero to first order. A stance chart has dependent rates and must be lifted/restricted explicitly (S6, S13).
Compare separate ± difference quotients, central differences, smaller steps and tighter integration/event tolerances; measure leakage in the full physical section tangent. Agreement of only one projected 2×2 matrix is insufficient.
The existing daughter search records these quantities as **acquisition predictors**, preserves the parent's original split, and makes no classical-derivative or attachment claim (S16).

## Numerical attachments versus a classical pitchfork

For a testable FG→G or HE→G attachment, require actual independently corrected/admitted parent and daughters, unchanged physical p and map/policy, and verified common section/event-domain ownership.
Track both signed odd amplitudes toward zero while retaining the parent's other-pair spread; verify convergence of full physical states, energy and the complete return, rather than only labels or E–speed proximity.
Keep source occurrence/provenance and genuine correction/replay ownership. Native all-nine acceptance, primitive one-flight classification, closure and appropriate fine-integration checks remain separate requirements. Two isolated accepted G objects or a near-zero determinant establish neither connectivity nor a pitchfork.

For classical local bifurcation reasoning, let P_E act on the fixed-energy physical marked section and set F(z,E)=P_E(z)-z along the parent family.
Remove phase via the oriented apex, translation via the gauge, and the parent-energy neutral direction via ker(DE); do not delete an arbitrarily chosen multiplier nearest +1.
S13 explicitly checks the regular energy gradient, closed base, invariant energy tangent and leakage before reporting that restricted spectrum.
At a pair-fixed base an invariant energy has zero odd gradient, so the proper odd directions are tangent to its energy leaf, provided that leaf is regular.
The augmented coupled [u;E] correction Jacobian is not itself the fixed-energy return derivative (S10).

A simple pitchfork interpretation needs a one-dimensional **odd** kernel of L=D_zF, an invertible complementary problem, and no additional unaccounted unit multiplier.
It also needs nonzero crossing along the actual parent branch, e.g. wᵀ(dL/dE)v≠0 for normalized kernel/adjoint vectors, and a nondegenerate odd reduced nonlinear term.
For a cubic normal form `a[alpha(E−E*) + beta a² + …]=0`, alpha and beta must be nonzero and the regularity needed to justify that expansion must be established; C^3 is a usual sufficient hypothesis, not a requirement for merely testing a numerical attachment or a C^1 derivative.
A C^1 equivariant map alone does not establish the cubic expansion, existence, uniqueness or stability of daughter branches. None of these nondegeneracy conditions is asserted verified here.

## Why the v2 expected graph is a hypothesis for v3

The v2 source accepts explicit contact timings, enforces/regulates them, and includes a prescribed tAPEX (S17). Its state ordering and parameterization also differ from S1.
A v2 diagram or saved template consequently does not prove the same marked autonomous v3 return domain, admissible itinerary, primitive multiplicity, map derivative, or branch connection.
A comparison must first match physical parameters/units, leg order, section/policy, timing ownership, energy, symmetry and admissibility; a saved range is not continuous coverage or current native admission.
The current source supports a specific, testable compatibility/symmetry route. Actual FG→G/HE→G attachment and a classical pitchfork remain to be demonstrated.

## A separate invariant set inside the saved mixed G family

With exactly matched fore/hind stiffnesses, rest lengths and rest angles, centered COM, zero pitch and pitch rate, and equal raw angle/rate/mode for BL=FL and BR=FR, the ipsilateral pairs have identical hip heights and velocities. Their axial forces match, opposite fore/hind moment arms cancel, and their swing and stance equations agree (S1–S4). Equal same-kind paired guards and atomic paired resets preserve these equalities, provided the execution stays admissible and the paired event identities persist. This is a conditional invariant-set statement; small floating-point differences do not prove exact membership.

Ipsilateral angle equality prevents both requested gathered and extended patterns: each matched hind/fore pair would need opposite strict angle signs at the same reference phase. It does not prevent a valid mixed G classification. The closed saved-sample audit `Diagnostic_G_017_Saved_Subspace.json` records near-zero pitch and the raw states; the separate ipsilateral audit must measure the precise pair differences, modes and event-cohort conditions before numerical membership is reported. No between-sample or global connectedness conclusion follows from that audit alone.

A nonzero pitch selector in the existing unrestricted physical chart leaves the zero-pitch set. Coupling that selector to free energy preserves the square shooting formulation. Such a search is an acquisition experiment; pitch sign does not determine GG/GE, and every returned orbit still needs the unchanged native admission, primitive-flight classification and any claimed attachment evidence.

# v2 reference graph and current-v3 assumptions

Source/document audit only. Coordinates below are **signed initial apex dx** from v2, not cycle mean speed, mechanical energy, or a verified current-v3 attachment. H means hind spread with synchronized fore pair; F means fore spread with synchronized hind pair.

## Shared PK reference

The PK package reports one repeated-+1 point at dx **4.43406193516227**, with final corrected bracket **[4.43406193516227, 4.43406370981359]**, scanned from PK_20_2 parent columns **194:198**. Its kernel dimension is four including the parent tangent; three transverse sectors are bounding, fore spread, and hind spread. It validates six oriented local rays with class counts [B,F,H]=[2,2,2]. Held-out secants from all six named BE/BG/FE/FG/HE/HG files are compared with this same critical space. This local result does not prove complete global daughter curves or current-v3 attachments.

The complete literal critical-state source is the **PK critical CSV** listed below: header `variable,value`; rows2:14 are old X13, ordered dx,y,dy,phi,dphi,alphaBL,dalphaBL,alphaFL,dalphaFL,alphaBR,dalphaBR,alphaFR,dalphaFR; rows15:23 are BL TD/LO, FL TD/LO, BR TD/LO, FR TD/LO, and T_apex. Native leg order is BL,BR,FL,FR; apply the lossless adapter rather than copying angle positions directly.

Printed critical values: y=0.986231408959873, dy=3.79682088573584e-15, phi=7.52288324190558e-17, dphi=6.79743262181018e-09, T_apex=1.36459804638066. Old-order angles are [1.48283162092746e-7,-1.4828324363799e-7,1.4827646590005e-7,-1.48277314551292e-7]; all four angular rates are4.28349938944166. Every prescribed TD is approximately0.5548225 and LO approximately0.8097755, so the first positive scheduled interval is flight.

## Secondary graph

| Connection | Broken left/right pair | Refined signed dx | Parent scan columns | Held-out daughter near -> outgoing indices |
|---|---|---:|---|---|
| BG -> HG | hind | 4.50616110935725 | BG37:41 | HG1 ->2 |
| BG -> FG | fore | 5.64566295496185 | BG64:68 | FG212 ->211 |
| BE -> FE | fore | 4.83363821441153 | BE25:29 | FE228 ->227 |
| BE -> HE | hind | 6.04807025559489 | BE57:61 | HE180 ->179 |
| FG -> GG | hind (remaining synchronized pair) | 5.91164915262086 | FG143:147 | GG1 ->2 |
| HE -> GE | fore (remaining synchronized pair) | 6.13622287987371 | HE128:132 | GE200 ->199 |

The registry supplies indices and pair semantics; each corresponding refinement CSV supplies the refined value. The last registry column is a historical daughter-coordinate estimate, not the refined coordinate. The six named curves therefore share a PK-neighborhood validation reference and also have distinct secondary B/H/F attachments; the reference graph is not a simple tree. BG/BE/FG/HE can fold in dx, so the printed local monotone windows do not authorize branch-wide fixed-dx continuation.

## Physical-domain qualification pending native check

The critical CSV does not contain p7. Experiment code takes physical parameters from parent rows23:29; Root/Theory must verify the protected native values. The `v2-exact` adapter copies old p4 to both native rest lengths; it does NOT hardcode unit lengths, and it sets both native rest swing angles to zero. If the actual common rest length is one, the printed y<1 and nearly vertical legs in initial flight violate the current swing-clearance/complementarity domain. This is a conditional source consequence until the native parameter/geometry audit; it is not a computed native gate result. No source state, phase, mode or parameter is projected to erase a refusal. Scheduled-v2 acceptance and first-contact/unilateral current-v3 admission are different contracts.

Fresh short-PK controls establish current admitted examples only. Similar T does not establish ancestry; a failed PAL step does not prove an endpoint or nonexistence. A legacy critical representative outside the current domain does not exclude another current family or critical point elsewhere.

## Suffix and near-PK caveat

The held-out PK summary selects BE1->2, BG1->2, FE1->2, FG2->3, HE1->2, HG538->537. Its named BE near point is literally classified BG, and its named HE near point HG. Corrected local B signs classify BE/BG, while both local F signs classify FG and both local H signs HG. Thus six oriented rays do not mean one newly verified current canonical state for every filename suffix. Current returned native classification, flight count, posture and all-nine gates remain authoritative.

## Source references (text/code SHA256)

- **PK README**: `/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped/3_Numerical_Continuation/2_Floquet_Analysis_v2/reference_experiments/PK_multigait_bifurcation/README.md`
  SHA256 `26d8931ddcb8c136e50ee7e3d20016721372a7eac89779836e376833c18589a7`.
- **PK critical CSV**: `/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped/3_Numerical_Continuation/2_Floquet_Analysis_v2/reference_experiments/PK_multigait_bifurcation/artifacts/05_validation/pronking_critical_orbit.csv`
  SHA256 `b90f548f632fdc8a16991ac971cb6f32f7e3c55f092a7532fcb65b88da433983`.
- **PK validation report**: `/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped/3_Numerical_Continuation/2_Floquet_Analysis_v2/reference_experiments/PK_multigait_bifurcation/artifacts/05_validation/pronking_multigait_validation_report.md`
  SHA256 `e879df3023a71d175ff8caa011eb9a3121666219fa1f61ee5c3548f71efd9244`.
- **PK held-out summary**: `/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped/3_Numerical_Continuation/2_Floquet_Analysis_v2/reference_experiments/PK_multigait_bifurcation/artifacts/05_validation/pronking_multigait_validation_summary.csv`
  SHA256 `fde7f4bcd9e1c88808ae288973103ab7ea7acb4a9cae68ebaacba01de32ef555`.
- **PK corrected rays**: `/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped/3_Numerical_Continuation/2_Floquet_Analysis_v2/reference_experiments/PK_multigait_bifurcation/artifacts/05_validation/pronking_corrected_orbits.csv`
  SHA256 `4f0998c7f77da2fe50ebbf7bcb3a85c2d61a4543db9fa199a648971b2182c045`.
- **Secondary registry**: `/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped/3_Numerical_Continuation/2_Floquet_Analysis_v2/reference_experiments/roadmap_common/RoadmapBifurcationCases.m`
  SHA256 `41d3160063ebacf278b320e2758a8a93d6cea2be25f55b81efeefe8996fd03fd`.
- **BG_half_bounding_bifurcation**: `/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped/3_Numerical_Continuation/2_Floquet_Analysis_v2/reference_experiments/BG_half_bounding_bifurcation/artifacts/02_refinement/refinement_summary.csv`
  SHA256 `adf6a43e67d2472471104da614e45c138c9e26fcb72133772854947692e57056`.
- **BE_half_bounding_bifurcation**: `/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped/3_Numerical_Continuation/2_Floquet_Analysis_v2/reference_experiments/BE_half_bounding_bifurcation/artifacts/02_refinement/refinement_summary.csv`
  SHA256 `f48efa47724d97346560200f582fb8e7c15dee9812cd9e51edbce587606bdb90`.
- **FG_GG_bifurcation**: `/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped/3_Numerical_Continuation/2_Floquet_Analysis_v2/reference_experiments/FG_GG_bifurcation/artifacts/02_refinement/refinement_summary.csv`
  SHA256 `2b06d0a97b5f34c4c898f90fdac3b9b69dd220ae70fc5ac5b47c559bf0ac2323`.
- **GE_HE_bifurcation**: `/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped/3_Numerical_Continuation/2_Floquet_Analysis_v2/reference_experiments/GE_HE_bifurcation/artifacts/02_refinement/refinement_summary.csv`
  SHA256 `cc481ff6b407cedff972a44ea453e7e8d992e46ac43f0f80810bf060bd8f3de3`.
- **Parameter adapter**: `/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped_v3/1_Dynamic_Frameworks/Adapters_v3/LegacyParameterAdapter_v3.m`
  SHA256 `cc6915b72f58604291b9f4b3ae341e273cad5653d07dd0016fc7644731db15c3`.
- **State adapter**: `/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped_v3/1_Dynamic_Frameworks/Adapters_v3/LegacyStateAdapter_v3.m`
  SHA256 `f7dc734828b9b9d6351f7d1c3a279bdb980484a0fba4a8c16c2542769d4b6612`.
- **Unilateral domain**: `/Users/nanyoujiayu/Documents/GitHub/SLIP_Model_Zoo/SLIP_Quadruped_v3/1_Dynamic_Frameworks/Dynamics_v3/QuadrupedAdmissibility_v3.m`
  SHA256 `36890b0c3a8bd994560146b8a676375f5cf9b214c818503f47e66cd8c4072ca7`.

## Conditional remaining-pair odd factorization

This is a source-derived candidate derivative, not a native agreement or bifurcation certificate. Assume the synchronized pair's odd perturbation has zero body/even component, compatible adjacent event orders, and a locally admissible marked return domain (S2–S9). Write \(z=(\delta\alpha,\delta\omega)^T\), \(\theta=\phi+\alpha\), \(H=y+s\sin\phi\), with hip offset \(s\), rest length \(l_0\), and torsional stiffness \(k_s\). During swing,

\[
\dot z=A(t)z,\quad A(t)=\begin{bmatrix}0&1\\c(t)&0\end{bmatrix},\qquad
c(t)=\frac{F_x\sin\theta-F_y\cos\theta}{l_0}
-\frac{s}{l_0}\ddot\phi\cos\alpha
-\frac{s}{l_0}\dot\phi^2\sin\alpha-\frac{k_s}{l_0^2}.
\]

Here \(F_x,F_y\) are the native summed axial forces, excluding gravity; other stance legs and torso motion generally make \(c(t)\) time dependent (S4:266–278).

Let \(\Phi\) be this swing fundamental matrix and \(T\) the actual primitive return period. For one TD then LO at \(0<t_D<t_L<T\), use the true one-sided guard slopes of \(g=H-l_0\cos\theta\). TD projects away the independent rate perturbation:

\[
a=\dot g_D^+/\dot g_D^-,\qquad
K=\frac{H_D\sec^2\theta_D}{H_L\sec^2\theta_L}.
\]

The stance factor follows from the fixed foot anchor \(x_{hip}+H\tan\theta\). At LO define

\[
V_x=\dot x-s\sin\phi\dot\phi,\quad V_y=\dot y+s\cos\phi\dot\phi,
\quad r=-\dot\phi-\frac{V_x\cos^2\theta+V_y\sin\theta\cos\theta}{H},
\]
\[
r_\alpha=\frac{2V_x\sin\theta\cos\theta-V_y\cos2\theta}{H},\qquad
b=r_\alpha+(f_\omega^+-D_xr\,F^-)\frac{l_0\sin\theta_L}{\dot g_L^-}.
\]

Here \(F^-\) is the native incoming stance flow and \(f_\omega^+\) its outgoing swing rate acceleration. The material derivative \(D_xr\,F^-\) must agree with the native stance rate acceleration. LO is identity on the consistent stance tangent, not an ambient identity reset (S3:84–128; S6). Consequently,

\[
M=\Phi(T,t_L)\begin{bmatrix}1\\b\end{bmatrix}K
\begin{bmatrix}a&0\end{bmatrix}\Phi(t_D,0).
\]

Conditionally \(\operatorname{rank}M\le1\), with eigenvalues \(0,\operatorname{tr}M\). The trace and resolved rate/angle direction are acquisition selectors; a unit trace alone establishes neither a secondary attachment nor pitchfork nondegeneracy.

Required checks include matched pair parameters/state/rates/modes, initially swinging pair, exactly one TD/LO, nonzero incoming slopes, positive \(H,\cos\theta\), zero boundary force, consistent stance rates, external atomic limits, and positive local BL marking margins. Grazing, extra events, incompatible order limits, or an active physical boundary invalidate this reduction.

Saved physical knots provide no dense nominal solution. Linear coefficient interpolation must split at every event without interpolating reset jumps. Midpoint-exponential subdivisions 1/2/4 measure quadrature convergence for the **same interpolant**. Boundary-preserving grid decimation 2/4 measures nominal-grid sensitivity, not a rigorous interpolation or continuous-orbit error bound. Independent finite-difference step/sign comparisons remain necessary; no numerical agreement is asserted here.


### Source audit: matched local equations do not establish matched hybrid orbits

Read-only source comparison found no hidden state, unit, parameter, force, swing, stance or reset mismatch for the stated baseline. State conversion only reorders BL,FL,BR,FR into BL,BR,FL,FR; it rescales no angles, rates or time. The actual legacy parameter order is `[k,ks,J,l,osa,lb,kr]`, despite its stale opening comment. `v2-exact` maps `[10,20,2,1,0,.5,1]` exactly to `[10,10,20,20,1,1,0,0,2,.5]`.

Both formulations use the same stance axial forces, body torque/gravity, swing stiffness term `−ks*alpha/l²`, and fixed-foot stance equations on their physical manifold. Both TD and LO project the affected leg rate while preserving body coordinates. Legacy `osa` is parsed but unused; `v2-exact` correspondingly sets native rest swing angles to zero.

The concrete semantic distinction is execution: legacy shooting integrates a prescribed, sorted contact timetable and enforces surface/closure equalities. Native execution uses mode-enabled first directed roots and accepted-state compression, swing-clearance and downward-orientation checks. A negative incoming TD slope can coexist with positive post-reset radial extension; these are different one-sided observations, not evidence of reversed TD direction.

This source audit contains no new numerical execution. It establishes neither long/short-family ancestry nor disconnection, double covering, period doubling, branch completeness or nonexistence. Period and initial-rate differences alone settle none of those questions.

Inspected source references (repository-relative path:lines; SHA-256):
- `SLIP_Quadruped/1_Dynamic_Frameworks/v2/Quadrupedal_ZeroFun_v2.m:90–107,121–177,183–245,397–554`; `475d8bd4a2d2f356da1bdcdd56977d9fa2344d895489457f9b40a31b8e76a6d1`.
- `SLIP_Quadruped_v3/1_Dynamic_Frameworks/Adapters_v3/LegacyStateAdapter_v3.m:5–13,64–80`; `f7dc734828b9b9d6351f7d1c3a279bdb980484a0fba4a8c16c2542769d4b6612`.
- `SLIP_Quadruped_v3/1_Dynamic_Frameworks/Adapters_v3/LegacyParameterAdapter_v3.m:14–51`; `cc6915b72f58604291b9f4b3ae341e273cad5653d07dd0016fc7644731db15c3`.
- `SLIP_Quadruped_v3/1_Dynamic_Frameworks/Dynamics_v3/ContinuousDynamics_v3.m:88–142,267–278,335–434`; `f84f97312328d8d582ed57548a6b27535b776e6c4e332499fe65e0a160144195`.
- `SLIP_Quadruped_v3/1_Dynamic_Frameworks/Dynamics_v3/GuardFunctions_v3.m:48–63,99–139`; `4824d780d4e30249aae888f9ff8d71450e94d0abdd3ec2c9da92bf1d8e66ec80`.
- `SLIP_Quadruped_v3/1_Dynamic_Frameworks/Dynamics_v3/ResetMap_v3.m:50–65,84–128`; `92a281dc5b2ccb92d740e89eb9b639f34c621d5d42dc810561af8d8bc59dd715`.
- `SLIP_Quadruped_v3/1_Dynamic_Frameworks/Dynamics_v3/QuadrupedAdmissibility_v3.m:11–30,155–218`; `36890b0c3a8bd994560146b8a676375f5cf9b214c818503f47e66cd8c4072ca7`.
- `SLIP_Quadruped_v3/1_Dynamic_Frameworks/Simulation_v3/TouchdownDiagnostics_v3.m:11–45`; `df83b52e9dbbc7dbdbf4d9e57fe2468b115c9c72ba9474b9f4e6e3ef4d808349`.

### Finite event-search and inactive-guard sensitivity

The current detector passes armed guard values to `ode45`; its auxiliary channels locate guard arming rather than guard minima. R2025b `odezero.m:46–51` skips interior searching when the two step-end guard signs agree. Thus an interior negative pocket between positive endpoints can escape event discovery. This is a source-level limitation; smaller finite `MaxStep` alone supplies no universal exclusion of narrower pockets.

The closed native audit `Swing_Guard_Minima_he_fg_inactive_guard.mat` refined actual saved all-flight intervals with two independent local integration profiles. For HE component022 point26, the BL guard minimum was `-5.5049909075677306e-9` at time `1.803381002321214`, with saved-right-state agreement about `1.06e-15`. That negative pocket lies inside the unchanged `1e-8` accepted-state tolerance. HE probe point5 and positive FG point39 instead had positive minima. These local fixed-mode extensions are not accepted autonomous hybrid replays or rigorous continuous error bounds.

Regular recorded contacts and positive sampled clearances therefore do not establish the absence of an inactive-guard grazing boundary. Preserve the literal original admission flags, and assess this uncertainty separately from the nine gates and finite replay checks. No detector change or synthetic fixture was performed in this audit. These findings establish neither a complete branch endpoint nor global GG/GE nonexistence.

The later closed native audit `Swing_Guard_Minima_pk_long_outward_tip6.mat` found two BL minima at long-PK outward point6: `-4.4373025032129476e-8` at `0.72690873889676344` and `-4.4372779339774127e-8` at `1.8862906226857512`. Two independent local profiles agreed, with saved-right-state differences about `2e-15`. Unlike the HE26 pocket, these values exceed the unchanged `1e-8` penetration allowance. Point6 is therefore physically disputed despite its literal coarse all-nine admission; the local extensions alone are still not autonomous hybrid replays.

`PK_Near_Tip_Same_State_Map_Control.mat` subsequently evaluated the exact saved states of points5 and6, with unchanged parameters, mode and BL1 policy, at `MaxStep=[.001,.0005,.00025,.000125,.0000625]`. All ten requested calls were attempted and the source/code posthash checks passed. Point5 returned valid, admissible, discrete-closed maps at all five profiles, with period about `2.61319940330483`. Point6 returned a valid map at `.001`, but `.0005` raised swing penetration/complementarity violations and the three finer profiles raised downward-orientation violations. A false `timely_at_map_return` on these exception rows is an unset successful-return flag, not evidence of a timeout. No correction, admission or original flag change occurred. These finite controls support rejecting point6 as a currently supported endpoint; they do not locate or prove the mathematical branch boundary.


## 2026-10-22 supplement: finite secants and primary numerical evidence

The original source arguments above remain conditional. This supplement distinguishes a conservative implementation screen from the separately closed numerical evidence of the current grant; it adds no theorem or attachment.

`FloquetAnalysis_v3.reducedReturn` (lines 609–622) computes the normal component of each finite return displacement, normalized by the finite displacement norm. `selectedStencilLeakage` (lines 753–770) takes the maximum of that quantity over the selected positive/negative full and half steps. This is a **finite-secant plane screen**, not the norm of the normal component of the central derivative. The implementation includes this screen in `subspaceInvariant` and overall `reliable`; those original fields remain unchanged in all retained analyses.

For example, the smooth map P(u,v)=(u, v/2+5u^2), with selected basis e_u at the origin, has an exactly invariant linearized selected subspace. Its finite-secant leakage is approximately 5|h|, exceeding 1e-6 at h=1e-5. Thus a failed finite-secant screen does not establish linearized noninvariance. Conversely, central cancellation alone can hide an even |h| cusp, so a small central normal derivative does not prove differentiability. Separate one-sided differences and step convergence remain necessary numerical evidence, with the local event-domain hypotheses above still unproved in a whole neighborhood.

The closed saved-only MATLAB audits `Saved_Odd_Derivative_Leakage_oldPK22_oddambient01.mat/json` and `Saved_Odd_Derivative_Leakage_criticalPK22_oddambient01.mat/json` reconstruct the original project-first native derivatives exactly from actual saved full14 returns. They report central/Richardson normal leakage, step-halving agreement, and the complete one-sided disagreements, without a new map call, new eigensystem, admission or core flag upgrade. At the empirical critical PK control, both conditional central screens passed the registered 1e-6 thresholds. The H selected normal leakage is zero and the F value is 1.1028215377943221e-8; ambient relative half-step differences are 1.3544720900426908e-8 and 1.277717081443752e-8. One-sided disagreement ratios are approximately one half. These observations support a local linearization interpretation at the tested scales and do not prove C1 regularity or bound the derivative error by the distance of a multiplier to one.

The fresh PK control has native energy 18.27075406676509. Its B energy-leaf multiplier is 0.9999999995928355 with the original reliable/native energy-leaf checks passed. The projected H/hind-odd and F/fore-odd multipliers are 0.9999999977429275 and 0.9999999977924358, respectively, with their original overall/subspace flags false. The control energy was selected empirically by two-level linear extrapolation of two signed B daughter sequences, not by a certified limit. The signed B controls at amplitude magnitudes 0.0005 and 0.00025 approach their independently solved same-energy PK controls in physical state and period. All remain isolated nonedges unless a separate native continuation earns a link.

Together these are numerical evidence for a **multiple-sector primary candidate** and a contracting PK-to-B daughter pair. They do not establish a one-dimensional kernel, three independent simple pitchforks, classical nondegeneracy, a formal PK attachment, or the requested secondary FG-to-GG/HE-to-GE connections. Any finite H/F acquisition uses the projected vectors as explicitly heuristic initializers and must pass the unchanged shared periodic solver and all nine gates independently.


<!-- C1-20261024-odd-selector-parent-tangent -->
## 2026-10-24 round: exact-parent selector limitation

This is a conditional source and algebra observation, not a new numerical bifurcation result. In the existing coupled chart write the d physical family equations as `F(u,E)=0`, with d independent state coordinates and free energy E. Let `w(s)=(u(s),E(s))` be a differentiable nonconstant synchronized parent family, and let the remaining-pair odd selector satisfy `eta(w(s))=0` along that family. Differentiation gives `DF(w) w'=0` and `Deta(w) w'=0`. Therefore the square augmented Jacobian `D[F; eta-a]` has the nonzero parent tangent in its kernel at every exact parent point. Changing the requested nonzero amplitude a changes the residual but not this Jacobian. This applies away from the bifurcation as well; failure of a Newton step there is not evidence that a daughter is absent.

The same conditional issue applies to a mean-angle selector `delta=(alpha_BL+alpha_BR-alpha_FL-alpha_FR)/2` on an exact IPS or diagonal family on which delta vanishes identically. Being outside bilateral B/F/H synchrony does not establish being outside those other sectors. The calibrated near-root is not assumed to have exact sector membership, an exact family tangent or a full-rank augmented Jacobian. A bounded regularized acquisition is an experiment, and reducing the finite-difference step is not a rank certificate. Unavailable finite derivative columns, finite ill-conditioning and exact algebraic rank loss are distinct outcomes.

A linear selector with an even family-tangent component can remove this particular tangent null direction, but the same target may then be reached by moving along the synchronized parent. Such a row alone does not force a daughter. The justified direct FG/HE route remains conditional on a new admissible parent neighborhood and credible remaining-pair odd critical evidence, followed by feasible off-parent predictors, actual shared-service admission and capture, independent fine qualifications, and owned continuation. No selector sign, regularized step, near-unit screen or proximity supplies an attachment.

For the current calibrated mean-contrast experiment, inspect the literal initial, last accepted and last finite coordinates separately, including physical closure versus selector reduction, native/free-energy drift and actual sector defects where a complete native cycle is available. A failed correction without a complete cycle does not inherit a full-cycle sector audit from rounded initial angles. A saved finite/Broyden acquisition matrix is not silently relabeled a fresh derivative or classical bifurcation certificate.


<!-- C1-20261024-midstance-scalar-PK-predictor -->
## Conditional synchronized midstance predictor (20261024 grant)

This is a conditional exact-sector calculation and a proposed finite acquisition method, not a newly computed orbit, a complete basin census, or an attachment to P1. Assume the principal matched parameters, zero pitch/rate, equal four leg angles and rates, the original strict contact law, and a smooth synchronized stance segment with no intervening event. In units with gravity and rest length one, a midstance state with all four legs in stance, height `r` in `(0,1)`, zero leg angles/vertical velocity and horizontal velocity `w>0` has energy

`E = w^2/2 + r + 20(1-r)^2`.

The physical stance rate is `-w/r`. Horizontal reflection composed with time reversal fixes this midstance state. On the exact invariant sector, uniqueness of the smooth stance flow gives reflected touchdown/liftoff limits. If the actual first outgoing all-four liftoff occurs after time `tau_s` at angle `-a`, rate `-b`, horizontal velocity `u>0` and vertical velocity `v>0`, its reflected incoming stance state has angle `+a`, the same stance rate `-b`, and vertical velocity `-v`. No sign of `b` is assumed.

In the exact zero-pitch all-flight sector, body motion is ballistic and the common swing angle obeys `alpha_ddot = -20 alpha`. Equal liftoff/touchdown heights give flight duration `2v`. With `nu=sqrt(20)`, the scalar touchdown-angle condition is

`f = -a*cos(2*nu*v) - (b/nu)*sin(2*nu*v) - a`

`  = -2*cos(nu*v)*(a*cos(nu*v) + (b/nu)*sin(nu*v)) = 0`.

Both factors must be considered. A `cos(nu*v)=0` root has incoming swing rate `+b`; the other factor has incoming swing rate `-b`. The original touchdown map may project either to the physical stance rate `-b`. A rate jump is therefore not by itself a rejection of the first factor. Incoming guard slopes are respectively `-v+b*sin(a)` and `-v-b*sin(a)` and require their own directed-contact checks. For `0<a<pi/2`, the post-reset radial rate is `-u*sin(a)-v*cos(a)<0`. This local compression inequality does not establish whole-flight admissibility or exclude an earlier contact. The conditional period and stride are `2*tau_s+2v` and `2*sin(a)+2*u*v`.

A finite numerical experiment must retain the actual native stance/LO arrays, validate the first all-four LO cohort, search the two factors separately without interpolating through invalid stance samples, check the complete flight with the unchanged native detector, and independently run the BL-marked map and shared PSS. Only native all-nine admission and both original fine replays can qualify a stored canonical PK result. Finite grids and sampled sign brackets do not prove that all scalar roots or basins have been found.

Floating-point near-symmetry is separate from the exact proposition. If a new acquisition predictor is rounded into the known PK sector, its literal unrounded state, measured change and bound must be retained. The actual LO state and native trajectory must remain untouched; any harmonic calculation from a merely near-sector LO is an approximate initializer, subsequently tested by full native integration. No source orbit or physical law is changed by this calculation.


<!-- C1-20261024-direct-root-only-mode -->

The current C1 correction algorithm is explicitly `root-newton`: finite real square `J*step=-F`, a numerical reciprocal-condition guard and a direct linear backward-error check, followed by the first valid physical trial among the full step and registered halvings. It does not minimize an objective, regularize least squares, use a pseudoinverse, or stop successfully on gradient optimality. A valid full trial is allowed to increase the residual. Success requires the registered residual threshold; a small evaluated nonroot trial may instead produce a configured stagnation refusal.

Twenty-one native algebraic controls passed on Root source5f1fb38e and C1 continuation3f4c1d18. Their exact report and the two-operator historical-source bridge are retained in `Root_Only_Native_Validation_20261024.json` and `Root_Only_Source_Epoch_20261024.json`. This validates the tested numerical control behavior, not nonsingularity of a physical return derivative, a local bifurcation theorem, or global branch completeness. Existing physical closure/energy/inequality/primitive/replay gates and model/contact semantics remain independent and unchanged. All historical numerical-method descriptors remain literal; the new method is not retroactively attributed to older results.


## Native evidence added on 2026-10-25

The saved-only P1PKDomain25_01 audit reconstructed the original regulated event-time modes and parameter conversions twice. PK columns 194–198 share the principal native parameter `[10;10;20;20;1;1;0;0;2;0.5]`. Each of those five original initial states is all flight under its actual event schedule and fails native swing-foot nonpenetration. The literal critical CSV state, evaluated with the verified common parent parameter, is also all flight and has four guard clearances `-0.013768591040115963`, compared with the registered accepted swing tolerance `1e-8`. Its apex chart can be constructed, but its unilateral physical-domain report fails. No original state or event schedule was projected or relabeled. The CSV itself does not store a parameter vector; use of the common parent parameter is explicit in the native receipt.

This rejects exact inheritance of these scheduled P1 representatives as admissible native v3 initial states. It does not prove that a different native critical orbit or an analogous native bifurcation graph is absent. The audit made zero new integrations, roots or admissions. Essential evidence: `P1_PK_Critical_Domain_P1PKDomain25_01_20261024.mat` and `.json`; retained actual-exit closure `Root_Closed_P1_PK_Critical_Domain_20261025.json` (SHA256 `e1723f3fe4bf75dc66f77dad167323a26116b168b4da9a226ff95b2eae598639`).

The saved-only ParentUnitFacts25_02 audit separately compared determinant, trace and factored arithmetic on the literal saved F23 and H31 pair-odd operators. Their determinant/factored residual differences are `2.2204460492503131e-16` and `1.3877787807814457e-16`. The unsuccessful original corrections kept residuals `0.070299637213253607` and `0.088540364662447552`. There is no material cancellation evidence warranting a formula change. This is finite arithmetic on saved operators, not a derivative, rank, unit-root or bifurcation certificate. Essential evidence: `Parent_Unit_Saved_Facts_ParentUnitFacts25_02_20261024.mat` and `.json`; retained closure `Root_Closed_Parent_Unit_Saved_Facts_20261025.json` (SHA256 `8b094bf06add58d741586a6d737b6a2e678269e4d0b6b1442fa282fc3ee6bbd5`).

A separate tighter native root-only experiment, LegacyGTight25_01, admitted one G/GM1 periodic point with all nine gates and both independent physical fine replays passing. Its actual mixed reference posture does not qualify GG1 or GE1. It is stored as an isolated NONEDGE and supplies no attachment. The source, correction/replay/FD settings, exact original process exit and complete native return are bound by retained closure `Root_Closed_Legacy_G_Tight_Profile_20261025.json` (SHA256 `bc088a70d0cd90c49228164eab4f622ccf288e518d14cd683fde00eb9812a6eb`).

For final C1 claims, require a certain primitive flight count of one in addition to the actual current classifier/admission predicate. The generic label PK is an explicit naming exception; it does not alone imply one flight. The broad range audit, figure eligibility, strict current graph predicate and independently closed fine evidence are separate strata. Identical BL1 policy settings alone do not prove identical section charts. The failed PrimaryB conjunction checked both an exact decimal energy and an all-false mode; it does not identify a failed clause or establish a mode mismatch before native inspection.


### 2026-10-25: saved diagnostics, status ambiguity and template convention

- `failed_full_closure` is not a convergence certificate: RootSolver_v3 final validation310-326/366-371 can set converged=false and PSS124-145 propagates it before replay; PSS190-211 separately assigns that status for failed full13 replay gates after convergence. The current closed PK failure audit confirms the former path for all7 retained failures, with native/domain Newton-fraction refusal, orientation/tensile invalid-trial evidence and missing replay roles. No endpoint, nonexistence or stale-Jacobian claim is justified.
- The exact saved B/PK inputs are section-compatible and logical allflight. The old decimal energy clause18.270771186300038 is not the literal native target18.270771186300045. A caller-source correction of that exact literal is distinct from relaxing energy accuracy or changing an orbit/mode.
- Every saved FG212/FE228/HG538/HE180 template column matches F=fore-spread/hind-sync and H=hind-spread/fore-sync at registered raw-angle/rate/same-kind circular event1e-8 tolerances. This is initial/scheduled template evidence only; G/E posture and autonomous full-cycle semantics remain separate.
- V3 QuadrupedAdmissibility_v3 defines theta_i=phi+alpha_i and requires cos(theta_i)-MinimumDownwardCosine>0 for every leg by default, including swing. The inspected v2 scheduled force formulas use the same h/cos(theta) geometry without that all-leg orientation rejection or equivalent tensile/positive-length checks. This is a material difference in admissible domain. The observed current PK failures do not show that all higher-energy native roots violate it; complete inheritance of P1 ranges/structure remains an experimental expectation, not an established theorem. Current physical gates are preserved.

Essential native authorities: `Root_Closed_PK_Current_Failure_Facts_20261025.json`, `Root_Closed_Primary_B_PK_Source_Facts_20261025.json`, and `Root_Closed_P1_Half_Bound_Template_Semantics_20261025.json` in this Audits folder. Exact source-theory correction and original peer metadata are preserved in the implementation custody record and working-source archive plan.


### 2026-10-25: conditional PK-to-B transverse quotient

This is a source-backed mathematical reduction proposal; no quotient matrix or multiplier has been calculated in the current run. The retained diagnostic uses the LR-even orthonormal basis in coordinate order `(dx,y,phi,Omega,aH,wH,aF,wF)`. Define the four departure rows

`D = [e3'; e4'; (e5-e7)'/sqrt(2); (e6-e8)'/sqrt(2)]`,

and intrinsic pronk basis `S = [e1,e2,(e5+e7)/sqrt(2),(e6+e8)/sqrt(2)]`. Then `DD'=I4`, `DS=0` and `Q=D'` is an explicit right inverse. If an actual common first return derivative M preserves the physical pronk tangent, equivalently `DMS=0`, the induced quotient `A=DMQ` is independent of complementary representatives. The chosen complement need not be invariant: in basis `[S,Q]`, M may have the triangular form `[PK,C;0,A]` with nonzero coupling C. This quotient isolates departures from pronk inside LR-even, without asserting a same-base fore/hind spatial symmetry.

For principal matched leg parameters and centered body, exact allflight pronk flow has zero pitch/rate, identical leg dynamics and cancelling pitch torques. In allstance mode, equal stored rates alone are insufficient: the physical no-slip rate constraint must also hold. On that manifold the native back/front rate formulas reduce to the same expressions. Identical guards and complete atomic four-leg resets preserve the pronk right limit in exact arithmetic. The marked apex and BL1 identity, transverse guards/section, compatible simultaneous-contact limits and physical-chart hypotheses are still required. The distinct floating-point implementations can introduce numerical defects; these are to be measured, not declared zero by symmetry.

On the allflight principal apex, the energy covector is `(dx,1,0,...,0)`. It annihilates Q and is nonzero on S. Thus the regular energy leaf has dimension7 and its intrinsic pronk subspace dimension3; their induced quotient is the same4-dimensional quotient. Conservation yields a LEFT unit covector, not a uniquely identifiable right energy eigenvector. Deleting the multiplier closest to1 is not justified.

Any future numerical screen must retain separately the existing derivative/base/LR-even leakage/common-first qualification and a new pronk-kernel defect `DMS`, energy-invariance residual, refinement evidence and actual lift residual. A small floating defect supports only approximate complement independence. A quotient unit eigenvalue increases transverse algebraic multiplicity, but a resonant intrinsic unit block can yield a Jordan extension rather than another independent full eigenvector. Canonical B identity, a simple crossing, C2 regularity, pitchfork nondegeneracy and actual signed daughter attachment remain separate requirements.

Source basis/departure definitions are in `DiagnoseC1ShortPKTransverse_v3`; native flow/stance/reset/guard conditions are in `ContinuousDynamics_v3`, `GuardFunctions_v3`, `ResetMap_v3` and `Quadrupedal_Dynamics_v3`; energy-leaf restriction is in `FloquetAnalysis_v3`. This proposal changes no core code, numerical derivative, root algorithm, physical law or current evidence status.


2026-10-25 22:35 UTC additions: actual saved PK import2 now has reliable central LR8/common-first evidence under the original declared chart. The conditional pronk quotient includes a numerical multiplier1.0000001958153937, with raw DMS infinity defect1.0714597400586856e-8 and gM-g infinity defect7.3934638966655086e-9. No exact quotient-invariance, simple unit, crossing or daughter theorem follows. Both current energy-control blocks were budget-censored; their absent matrices must not become a spectral bracket.

The refined saved PK stationary audit distinguishes internal observer restarts by literal is_stop/name/metadata/no-reset/sample bindings; numeric stop guard_id1 alone is not BL touchdown. Physical/unknown/return/failed-binding rows remain barriers. Actual indices33/34/35 support the local analytic stationary roots before their first physical event, with full saved-prefix coordinate errors retained. This repairs the conservative audit interpretation, not the physical event law. Positive local gap samples and their decrease do not certify a global minimum, threshold, continuous first hit or branch endpoint.

Final visual reporting must distinguish the existing pooled saved-flag comparison from a strict latest-predicate/certain-C1 snapshot. Existing native solid segments are explicit same-file owned edges; P1 dashed segments are the original stored-column template sequence. Native IDs and plotted extents are not counts of distinct physical cycles or complete continua.


2026-10-25 23:09 UTC source-only checks: the possible missing-apex-offset hypothesis was independently rejected against v2 ZeroFun and the P1/critical-domain readers. Literal X is initialized at time0; E9 is the terminal period, contact1:8 wrap modulo it, and the first positive interval and old-to-native leg ordering agree. No mode rewrite or phase change is warranted. Exact-zero scheduled boundaries retain the documented pre-reset-state/right-limit-mode caveat; the positive-time critical case is not that boundary.

The existing parent odd-unit operator intentionally covers only selected-synchronized-pair flight at the marked apex. Canonical FG1/HE1 classifiers can also accept grounded marked apices. In the selected-pair stance chart the odd physical direction has dimension1 because rates are constrained; parent Family n=9−nnz(other-pair stance), versus10−nnz(other-pair stance) in selected flight. A distinct LO-before-TD cyclic-factor extension is being source-reviewed, without changing the actual apex state/mode/BL1 map. Conditional BA scalar and AB rank1 nonzero spectra agree; this is not similarity through an inverse touchdown reset. Nonclosed Root trials require an explicit endpoint coordinate identification, and only a fully closed physical parent supports a Floquet interpretation. No actual excluded bifurcation site or new unit root has yet been established.

### 2026-10-26 00:21 UTC: two-sided PK quotient evidence

The closed Long control/quotient runs returned eligible central/common-first numerical matrices for the baseline and both admitted, fine-qualified PK1 energy controls. At nativeH18.26077118630004 the nonzero near-unit quotient multiplier is0.999890800122323 (h1e-5) and0.99989076860593507 (h3e-6). At nativeH18.280771186300051 it is1.0001094727005275 and1.0001094642067239, respectively. The baseline remains1.0000001958153937/1.0000001627827082. This is a numerical two-sided unit-crossing bracket in the declared common-first chart. It is not an exact critical root, simple-eigenvalue/nondegeneracy proof, classical pitchfork theorem or branch attachment. The B-family approach calculation remains necessary. All quotient eigenvalues, both step matrices, raw leakage/energy defects and direct-lift residuals are retained without closest-unit deletion or a new success tolerance.

### 2026-10-26T00:51:21.999678+00:00: first-eligible unit roots approach PK geometry

The recovered saved-only facts preserve the original failed16M publication attempt separately from the successful stage recovery. Original facts values, run name, clocks and savedfalse flags are unchanged; the complete recovered JSON contains19296121 characters. The exact original stage was moved byte-identically to Archive only after recovery exit0 and poststdout guards.

For requests F6/F7/H5/H6, the final OTHER full angle gaps are8.3170339161678624e-7,1.9578155895595398e-7,1.4104619666175808e-6,7.8366535392799575e-8 radians. All fall below the pre-existing1e-4 capture floor. Their stored nativeH values are18.270733887836375,18.270748927267153,18.270753206980963,18.270758758939362. The actual classifier reason is initial synchronized leg pattern does not persist over the complete saved cycle; all are current-certain one-flight cycles but UNDETERMINED, including both physical fines. These are finite observations of collapse toward the pronk geometry, not a new PK label, a limiting theorem, or an FG/HE-to-gallop attachment.

A distinct fixed-sign log-gap coordinate experiment is being prepared for the existing endpoint sources F23/H31. It restricts the OTHER full initial angle gap to magnitude strictly above1e-4 radians and retains the same physical family equations plus one unit row and free energy. The domain is open; no clamping, extra equation, optimization objective, physical/contact-law change, or global absence conclusion is allowed. Root coordinates and journals are encoded; Base latest/refusal evidence remains physical. The source and actual decoded predictor are recorded separately.


## Exact secondary v2 critical-state domain check, 2026-10-26 03:05 UTC

The selected-field native audit P1SecondaryScoped25_01 closed at original session97335/PID17537 actual exit0, with poststdout guards. The exact targeted refinement artifacts are historically accepted/valid for fg_to_gg and he_to_ge. Selected z22/X13/E9/p7/status/adjacent-bracket roles were independently loaded twice and matched. Unused historical function-handle/Floquet graphs remain in immutable input MATs; no equality of those opaque graphs is claimed. No legacy refinement, integration, RHS, Root or classifier was invoked.

Both literal critical states map losslessly to the declared principal native p10. Their supplied timing modes are all flight, without any exact-zero contact event. Initial native constraint results are:

| Expected transition | Actual adjacent v2 parent columns | Failed native swing leg | Rest-length guard clearance | Accepted tolerance |
|---|---|---|---:|---:|
| FG -> GG |145,146|FL|-0.036764624220924524|1e-8|
| HE -> GE |129,130|BR|-0.0724858435323038|1e-8|

Both fail swing nonpenetration and contact complementarity. Both physical apex charts nevertheless construct with dimension12; chart construction is not unilateral physical admissibility. Literal E9 is the terminal period, X is the time-zero state, and no rephase, reset, state projection or geometric mode substitution was applied. The audit preserves the exact input/final signed brackets and all source parameters.

These literal accepted v2 critical states are outside the unchanged native initial domain. Consequently they cannot be inherited as native periodic orbits by copying the fixture or declaring its v2 label. This is an established incompatibility for these two exact states; it does not prove global absence of distinct admissible native FG/HE-to-GG/GE bifurcations or their complete graph. That remaining hypothesis is being investigated using native solutions.

Retained evidence: P1_Secondary_Critical_Domain_P1SecondaryScoped25_01_20261024.mat/.json, and Root_Closed_P1_Secondary_Critical_Domain_References_20261026.json (SHA2564f1a193efd5d24f7326e28140b6abd5d94d054bacc074a353dcf3bee17fbe3f2). The failed first whole-plain reader remains explicitly failed; its selected-field successor does not upgrade that failure or weaken physical checks.

The smaller primary experiment has also closed: its +/-1e-5 all-nine periodic roots have current ordinary label UNDETERMINED, not BG/BE. Full13 distance to same-chosen-E PK is about5e-6 and period differences about6.76e-8, but positive-ray physical fine support is false and both same-label flags are false. Those records remain isolated nonedges and do not extend the qualified BG/BE approach beyond the earlier1e-4 and3e-5 points. Recorded fine causes will be inspected separately; no failure cause is inferred from a flag alone.


### 2026-10-26 04:18 UTC: exact middle states and the smaller positive fine

All four exact P1/v2 refined middle critical states (BG-to-HG, BG-to-FG, BE-to-FE, BE-to-HE) pass the unchanged native initial accepted-state domain test at the principal parameters. Every initial mode is allflight and no exact zero-time contact event is ambiguous. Their respective minimum initial swing clearances are positive (the complete four-vectors remain in P1_Middle_Critical_Domain_P1MiddleDomain25_01_20261025.mat/.json). Thus the two secondary critical-state failures cannot be generalized to these middle states. This initial algebraic check does not verify their scheduled trajectories, native first-contact order, periodicity or bifurcations. A separate literal-state native first-flight comparison is being prepared; it has no executed result yet. Actual Root closure23beeb28c5d072532d45d9b81d8ea5d5b3aedadab3006f11de7eb06320063404.

The saved smaller-B fine fact audit closed original14078/PID19838 exit0. For positivebeta1e-5, MaxStep.0005 passed plain physical-fine checks with full13 closure norm7.3753781978469577e-14. MaxStep.00025 completed its map and classification and had full13 norm9.29486056603702e-14, but stopped in the scalar audit at35712/42905 samples with C1PlainFine:BudgetRefusal. The missing final energy/stance scalar maxima are unavailable, not observed physical violations. Both fine classifications are literal borderline/UNDETERMINED because the initial comparison lies near a declared angle/rate threshold. Therefore combined physical fine support remains uncertified and same-B label support remains false; neither is a nonexistence claim or license to relabel the root. Full saved receipts and explicit unstored map-info-flag limitations remain in Smaller_Primary_B_Fine_Facts_SmallerBFineFacts25_01_20261025.mat/.json. Actual Root closurebf996bb8d6f8df0efd4f58dbc86592867311b395a54b502d9c2d124ae5fe465a.

The HE31 stationary experiment HInteriorGrazing25_02 closed with one all-nine HE1 baseline, two scan invocations and no offset/fine/end-point calls. The second600-second scan exhausted its local budget before measurement qualification. That resource censoring is not an endpoint, contact failure or absence observation. A separately reviewed resource-only1200-second-scan successor preserves the equations, integration tolerances, physical gates and stationary-root bisection.

### 2026-10-26 04:52 UTC: positive PK saved clearance at the new tail

Fresh5 continuation on the original owned store closed with three new accepted points/owned edges,38 total saved points, and terminal status attempt_cap. Last nativeH31.124238271405904 does not establish the P1 range or a physical endpoint. Two failed_full_closure statuses are not assigned a root/replay cause without current saved evidence. Current correction MaxStep.0005 and its internal replay MaxStep.00025 are declared acquisition settings, not an independent fine certificate.

Separate saved-only stationary-root audits at actual indices37 and38 closed original92530/PID25257 and35974/PID25020, respectively, with actual exit0/poststdout guards. The registered scalar equation gdot=0 yields local positive-curvature candidates at0.72691127381257647/0.72690984284317106 with all-four clearances8.0372415643292783e-5/3.4983150890344206e-5. Both candidates precede the first saved physical boundary1.1930422993017638/1.1930364501101662; full physical-history joins and ignored internal-observer bindings hold. Native algebraic guard/Lie/flow checks and full per-row saved-prefix errors are retained. These are finite local-clearance observations, not global stationary isolation, continuous event-order exclusion, a grazing endpoint theorem, or a bifurcation. No optimizer was used: the local stationary equation was solved by registered bisection.

The first three-point audit preserved its full installed native/JSON pair but refused its1,574,515-character marker against the registered1,000,000 limit. That run remains failed. Two one-point runs use the identical frozen source and retain complete untruncated reports; they do not retroactively qualify the failed run. Qualified evidence pairs are Saved_PK_Selected_Stationary_Gap_PKSelectedStationary26_02_20261026.mat/.json and Saved_PK_Selected_Stationary_Gap_PKSelectedStationary26_03_20261026.mat/.json. Actual Root closures3b02558c5029e2a153f81d0f74d0e8cfff7d3710297e49cf3dd9c23dc8e041f9/4e03ec7e71189132ebe4285d35e26d23dff56f5b562ea180e036df505fcf4ddf are preserved in implementation custody.

### 2026-10-26 05:10 UTC: middle-reference native first contacts

P1MiddleFirstFlight25_01 closed original53130/PID26418 with actual exit0 and poststdout guards. Eight native full14-state ode45 flight prefixes used the literal four initial states, modes and parameters, without rephase/projection or a harmonic replacement of general allflight dynamics. Each stops at its first reported enabled downward TD or the supplied earliest v2 scheduled TD. No reset/full hybrid map/Root/classifier/admission was invoked.

| Reference transition | First reported native TD time, profile1 | Supplied earliest v2 TD | Native leg |
|---|---:|---:|---|
| BG -> HG |0.047658618271746868|0.43279170783712|FR|
| BG -> FG |0.0581319701746512|0.41719053636313114|FL|
| BE -> FE |0.028623884385192352|0.45432060238382072|BR|
| BE -> HE |0.0367388484372702|0.44112429715527812|BR|

All four independent profile comparisons passed the preregistered1e-8 time/state/surface tests, exact reported surface-set agreement, downward finite guard slopes and sampled-prefix accepted-state checks. Maximum-step1e-4 versus5e-5 profile times differ by less than3e-16 and event-state infinity differences by less than2.4e-14. Full event guard/Lie observations, native source pins and every returned sample remain in P1_Middle_First_Flight_P1MiddleFirstFlight25_01_20261025.mat/.json; retained actual Root authority is Root_Closed_P1_Middle_First_Flight_References_20261026.json, SHAae1205360f9093c45d772495e3e22e77eb03e25e95aaf332eb35fe0799eeea74.

Thus initial admissibility of these four exact states does not establish compatibility with their v2 scheduled trajectories: native enabled contact is reported substantially before every intended first scheduled contact. Existence of an earlier detected native contact already obstructs direct trajectory transfer; this does not require claiming a globally unique/earliest continuous root. These finite results do not establish absence of a distinct admissible native middle critical orbit, its full map or its bifurcation. No contact law, physical gate or classifier was altered to force P1 inheritance.


## 2026-10-26: positive PK clearance roots and P1 event semantics

The closed `PKPositiveClearance26_01` experiment solves six root equations in `(dx, y, alpha, omega, E, tau)`: four native family equations (including the mechanical energy equation), `g(tau)-epsilon=0`, and `gdot(tau)=0`. The two registered positive targets, `epsilon=1e-5` and `1e-6`, are independent starts from the same recaptured original PK point38. Both pass all nine gates, current PK classification, complete six-coordinate binding, full13 correction closure, and both timely independent physical/current-PK/positive-clearance fine replays. Their free energies are `31.126545776180627` and `31.127377027197014`; the actual six-equation residual infinity norms are `2.1955770534987096e-12` and `5.5351279115711804e-12`. Whole native returns, empirical prefix error margins and each actual fine invocation are retained in `PK_Positive_Stationary_Clearance_PKPositiveClearance26_01_20261026.mat/.json`.

These are two isolated roots plus one repeated baseline occurrence, with zero new edges. All comparisons concern the registered local stationary point before the retained first physical boundary. Finite saved prefix sampling and positive empirical margins do not prove global stationary-root isolation, continuous first-hit exclusion, existence at zero clearance, an endpoint, or a bifurcation. No optimizer or objective minimization was used.

An independent source cross-check found no state/parameter/leg-order/time-origin repair for the four exact P1 middle critical states. The source reader preserves `[0;X]`, maps legs BL/FL/BR/FR to native BL/BR/FL/FR by names, and uses `v2-exact` parameters. In `Quadrupedal_ZeroFun_v2.m:114`, the saved state starts at time0; `E(9)` is the supplied terminal time for that integration call, while the outer solve may vary it jointly with state. It is not an apex phase offset to subtract.

The substantive difference is the contact law. Legacy v2 selects contact modes using scheduled-interval midpoints (`Quadrupedal_ZeroFun_v2.m:130`), integrates to prescribed contact times with RelTol/AbsTol options and no Events callback (`:169`), and imposes ground equality only at those scheduled events (`:288`). It does not impose earlier-root exclusion or a downward TD condition in those residual rows. Native v3 selects enabled directed physical roots and checks compressive stance and swing nonpenetration. Thus the four closed first-flight observations of earlier native downward contacts are compatible with correct transfer of a scheduled v2 root; they obstruct direct trajectory inheritance. They do not establish global absence of corresponding native branches.

Before the first transition, the two allflight continuous flows agree after the existing parameter/state mapping. All contact forces and body torque vanish, giving `ddx=0`, `ddy=-1`, and `ddphi=0`; the swing law retains `(s/l)*Omega^2*cos(alpha) - (ks/l^2)*alpha` under `v2-exact`. The first-flight experiment integrates all14 literal native coordinates; it does not silently replace nonzero pitch or pitch rate with the exact-pronk harmonic specialization. Full P1 range and bifurcation inheritance therefore remain unverified scientific requirements, rather than imposed classification or event rules.
