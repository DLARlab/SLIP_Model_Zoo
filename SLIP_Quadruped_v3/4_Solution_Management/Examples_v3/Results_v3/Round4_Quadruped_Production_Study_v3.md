# Round 4 actual quadruped production study

This document is a human-readable index of the executed MATLAB artifact
`Round4_Quadruped_Production_Study_v3.mat`. It is not a replacement for the
MAT structure, which retains every accepted point and its diagnostics.

## Execution provenance

- Executed: 2026-08-11 04:00:30 -0400
- MATLAB: 25.2.0.3177638 (R2025b) Update 5
- Platform: MACA64
- Initial production run wall time: 1375.7943515 s
- Bounded physical-search wall time in the final artifact: 187.954 s
- Accumulated recorded wall time: 1614.45 s
- Model: `Quadrupedal_Dynamics_v3`
- Return policy: `EventCycleReturnPolicy_v3`
- Prescribed event times: no
- Prescribed gait label: no

The converted seed has structural left/right simultaneous event pairs. The
validated continuation and Floquet derivatives therefore use the
left/right-invariant section chart. They are not unrestricted Floquet or
unrestricted continuation derivatives.

## Seed preparation and continuation

The nine-point forward-secant homotopy from `k_l_f=10` to `10.16` was used
only to prepare a point away from the front/back cluster boundary. It is
explicitly excluded from the validated continuation count.

| Study | Accepted | Parameter interval | Maximum residual | Minimum physical margin | Map evaluations | Function evaluations | Invalid trials |
|---|---:|---:|---:|---:|---:|---:|---:|
| Fixed-parameter, hybrid FD | 20 | 10.16 to 10.14 | 5.563238016093042e-09 | 9.999991784349618e-09 | 1611 | 1693 | 0 |
| Pseudo-arclength, hybrid FD | 20 | 10.14 to 10.26007718951732 | 4.281344723189306e-10 | 9.999990674126593e-09 | 1501 | 1571 | 0 |

Both branches preserved all three signatures and had no section/cluster
coincidence:

- cyclic: `BL_LO&BR_LO>BL_TD&BR_TD>FL_TD&FR_TD>FL_LO&FR_LO`
- section-relative: `BL_TD&BR_TD>FL_TD&FR_TD>FL_LO&FR_LO>BL_LO&BR_LO`
- event-cluster: `BL_TD&BR_TD>FL_TD&FR_TD>FL_LO&FR_LO>BL_LO&BR_LO`

## Default RootSolver hybrid Jacobian correction

`RootSolver_v3` was constructed without a Jacobian override. Its installed
Jacobian class was `HybridFiniteDifferenceJacobian_v3`.

- Initial residual: 1.074501598183342e-05
- Final residual: 1.999040932787466e-10
- Map evaluations: 435
- Function evaluations: 439
- Cache hits: 4
- Jacobian evaluations: 2
- Accepted Newton corrections: 2
- Invalid trials: 0
- Mode candidates attempted: 1
- All nine columns reliable: yes

Selected coordinate steps:

```text
[0.001028685079114636, 0.001518786162579963, 0.001,
 0.0003002455935233243, 0.00100000006006002,
 0.001004177561772517, 0.001038336980411827,
 0.001004116441331218, 0.001038147327474179]
```

Estimated column errors:

```text
[1.112458258709764e-06, 3.214895737541083e-04, 0,
 1.108954967736343e-06, 2.14905969491316e-06,
 6.02755756344706e-07, 6.066846058503676e-08,
 6.106312373718007e-07, 6.34672354217691e-08]
```

After removal of a redundant fail-open metadata flag, an executed field audit
confirmed that the underlying residual supplies closure, cycle acceptance,
multiplicity, cyclic/section/cluster signatures, guard and section
transversality, and admissibility. A post-removal preflight then passed two
hybrid-FD points and a nontrivial default-root correction from
3.623204115110789e-06 to 3.795700998301954e-09 with one reliable Jacobian and
one accepted correction.

## Symmetry-restricted Floquet convergence

Every grid used an 8-by-8 left/right-invariant reduced section matrix, retained
the same three topology signatures above, return multiplicity one, guard
transversality 0.3944034137465895, section transversality 1, and 97 map
evaluations. ODE tolerances were RelTol 1e-9 and AbsTol 1e-11.

| Grid | Reliable | Difference from next matrix | Matched multiplier difference |
|---|---:|---:|---:|
| [3e-3, 1e-3, 3e-4] | yes | 1.403019109886042e-07 | 4.988706114872343e-10 |
| [1e-3, 3e-4, 1e-4] | yes | 2.173278454024572e-09 | 5.442815223645985e-11 |
| [3e-4, 1e-4, 3e-5] | yes | -- | -- |

Matrix for grid 1:

```text
[ 0.031344602884595285 -0.17231239222935535 -0.14420634069546753  0.035777987373516389  0.04391078217535601   0.66137383510228187 -0.34826157854505979  0.010508274787447348
  0.095161453938292048  1.0578681573447382   0.065620401331907274 0.10862110170010768  -0.13780516247513641  -0.98190278932872188  0.63979866067712976  0.077148980345311605
  0.003397409404828427  0.01452036772622183  1.0018492263279306   0.0038779394127859104 -0.0052388288375529168 -0.050001076379677323 0.019779392626613431 -0.0025395263187770471
 -1.0696708491523454   -4.8628643536157199  -0.15226980926099823 -1.2209652258776267    0.80554833437790752   9.3670775782515125  -0.96552957151849272 -0.16965199544592957
  0.011320261034586087  0.044919029899876756 0.13649390149398419  0.012921400122958367  0.0318940508503446   -0.55994692534860036  0.23174495061116537  0.043853713273620289
  9.3966086875914179e-05 -5.6446945371794129e-06 0.005693858168216462 0.00010725666185924903 9.0470451095943781e-05 -0.68007419177205264 -0.24407631308544034 9.6056947759437367e-05
  0.00051905488891177407 3.6407412059905124e-05 -0.0074535281025029793 0.00059247007587487311 0.00055322774950461505 2.2021052273198536 -0.67983329609958376 0.00060249408082018471
  0.24879539099428863   4.9358879199583461   0.14750431550408519  0.28398504224676491  -1.6916535941637687   -8.8143035046892209   0.70609845893085321 -0.76739217414292138 ]
```

Matrix for grid 2:

```text
[ 0.031344603056734248 -0.17231239266805687 -0.14420636042783433  0.03577798750558802   0.043910782610510769  0.66137383510228187 -0.34826157854505979  0.010508275034452468
  0.095161453986624359  1.0578681575644111   0.065620415181258732 0.10862110166262401  -0.13780516277386148  -0.98190278932872188  0.63979866067712976  0.077148980256642644
  0.0033974093758639416 0.014520367723791672 1.0018492264937484   0.0038779393805030934 -0.0052388288767807973 -0.050001076379677323 0.019779392626613431 -0.0025395263533543266
 -1.0696708507368051   -4.8628643515885051  -0.15226971048507129 -1.2209652261844459    0.80554833472868859   9.3670775782515125  -0.96552957151849272 -0.16965199618021062
  0.011320260862095184  0.044919030315114523 0.13649391922468865  0.012921400004584999  0.031894050449598067 -0.55994692534860036  0.23174495061116537  0.043853713045951037
  9.3966086911229042e-05 -5.6446944798431894e-06 0.005693858255894556 0.00010725666176790502 9.0470450815960632e-05 -0.68007419177205264 -0.24407631308544034 9.605694767971239e-05
  0.0005190548889030727 3.6407412387562946e-05 -0.007453528227526437 0.0005924700760829198 0.00055322774838634562 2.2021052273198536 -0.67983329609958376 0.00060249408092415179
  0.24879539259767378  4.9358879179518134   0.14750422054836929  0.28398504255863027  -1.6916535944375191   -8.8143035046892209   0.70609845893085321 -0.76739217341008681 ]
```

Matrix for grid 3:

```text
[ 0.03134460307760565  -0.17231239270677831 -0.14420636070361939  0.035777987573765539  0.043910782640061409  0.66137383510228187 -0.34826157860910928  0.010508275102529538
  0.095161453944555177  1.0578681575842581   0.065620415361840309 0.10862110163611956  -0.13780516282224597  -0.98190278932872188  0.63979866075119673  0.077148980228493536
  0.0033974094002271697 0.014520367715736386 1.0018492265076142   0.0038779393812185697 -0.0052388288638035236 -0.050001076379677323 0.01977939270283641 -0.0025395263441518111
 -1.0696708504135917   -4.8628643514199181  -0.15226970920361524 -1.2209652263629047    0.80554833514594515   9.3670775782515125  -0.96552957121261951 -0.16965199636212056
  0.011320260849868083  0.044919030348686752 0.13649391947547818  0.012921399939895042  0.031894050433017296 -0.55994692534860036  0.23174495070104592  0.043853712978041838
  9.3966087136502184e-05 -5.64469449669651e-06 0.0056938582569947367 0.00010725666161880917 9.0470447279931632e-05 -0.68007419177205264 -0.24407631308798727 9.6056947707311394e-05
  0.00051905488863081847 3.6407412449303564e-05 -0.0074535282290771375 0.00059247007623594149 0.00055322773930703898 2.2021052273198536 -0.67983329620894806 0.00060249408102035001
  0.24879539221762761  4.9358879177859993   0.14750421931815375  0.2839850427398502   -1.6916535949321077  -8.8143035046892209  0.70609845831003604 -0.76739217323504116 ]
```

Multipliers for grids 1 through 3:

```text
G1 = [-0.93214920677138735; -0.88794089760420547;
      -0.67978898514239883 +/- 0.73339986268331303i;
       0.95435922559392405; 0.99999999848659993;
       1.105659154088954e-12; 9.419151369123374e-11]
G2 = [-0.93214920674845481; -0.88794089752680549;
      -0.67978898514109876 +/- 0.73339986268660573i;
       0.95435922609279467; 0.99999999855521016;
       9.967990606181756e-12; -2.194253467159757e-12]
G3 = [-0.93214920677265922; -0.88794089750284155;
      -0.67978898519538999 +/- 0.73339986269046387i;
       0.95435922610780966; 0.99999999857150856;
       5.256225744613685e-12 +/- 1.076701682972432e-12i]
```

These are multipliers of the supplied symmetry block. They are not claimed as
the unique unrestricted Floquet spectrum of the clustered orbit, and no smooth
bifurcation classification is inferred from the near-unit multiplier here.

## Bounded physical searches

The final search used unrestricted topology-aware HybridFD or rejected the
trial; it did not fall back to an ordinary finite difference.

| Parameter | Requested values | Accepted | Rejected |
|---|---|---:|---:|
| `k_l_f` | [10.14, 6.084, 2.028] | 1 | 2 |
| `l_l_f` | [1, 1.225, 1.45] | 1 | 2 |
| `k_s_f` | [20, 10, 0] | 1 | 2 |

Structured rejection causes were maximum iteration count, FL/FR stance
compression below tolerance, and a section return rejected for FL/FR
swing-foot penetration plus contact-complementarity loss.

No validated grounded apex, multiple-apex cycle, section-mode transition, or
refined section/contact coincidence was found. Consequently no FirstReturn
versus EventCycle comparison could be executed for an actual multiple-apex
quadruped orbit.

The bounded non-simultaneous multistart used two left/right-breaking directions
and amplitudes 1e-3 and 1e-2. Four attempts were made. Both 1e-3 attempts
stopped at the iteration limit. Both 1e-2 attempts converged to residual
2.22872e-09 but returned to a clustered orbit, so the genuinely
non-simultaneous production-orbit requirement remains unresolved.

No physical bifurcation bracket or refined critical point was found; therefore
no physical quadruped branch switch was attempted or claimed.

## Focused artifact tests

`TestProductionQuadrupedContinuation_v3` and
`TestProductionQuadrupedFloquet_v3` load this executed artifact and do not rerun
the long study. The final focused execution on this platform passed 10 of 10
tests, with 0 failures and 0 incomplete tests, in 0.76508 s.
