# Additional invariant-sector proposals from the actual G/P2 obstruction

Status: derived from the native equations and actual Round A derivative diagnostics; no corresponding production chart or numerical acquisition has been implemented here. This document does not assert an unrestricted symmetry theorem or a bifurcation. All claims below are conditional on finite regular physical states, the stated exact parameter equalities, compatible mode equalities, and the existing atomic independent-leg reset semantics.

The actual G initial derivative loses reliability in pitch and leg directions; two angle probes also fail with TensileStance. The P2 opposed derivative loses dx, pitch and pitch-rate columns, whereas its leg columns are central reliable. The P2 standing derivative loses pitch and pitch-rate columns, while dx and all leg columns are central reliable. These are recorded domain/topology obstructions, not demonstrated rank deficiency or absence of periodic points.

## Equal fore/hind leg pairs with zero pitch

Assume matched fore/hind linear stiffness, torsional stiffness, rest length and swing rest angle, centered COM, and exactly zero phi and pitch rate. Impose BL=FL and BR=FR in raw angle, physical angular rate and contact mode. This restriction permits nonzero horizontal velocity and different left/right leg states.

At phi=0 the paired hip heights both equal y and their absolute leg angles coincide. The paired leg lengths/compressions and axial forces therefore coincide. Native pitch torque is `sum(s_i*f_i*cos(alpha_i))`; centered offsets are `-1/2` and `+1/2`, so each equal fore/hind pair cancels its torque. Thus pitch acceleration is zero and the zero-pitch conditions persist. The swing equation's hip-offset terms multiply pitch acceleration or squared pitch rate and vanish. Matching remaining parameters gives identical paired swing flow. The fixed-foot stance-rate and acceleration equations likewise coincide when pitch, pitch rate and pitch acceleration vanish.

The guard `g_i=y+s_i*sin(phi)-l0_i*cos(phi+alpha_i)` and its Lie derivative coincide within each pair. The reset projection depends on identical hip height and hip velocity and gives identical paired post-reset rates. Atomic paired resets preserve equal modes. These direct native cancellations establish invariance of the stated sector; no global fore/hind exchange action outside this sector is assumed.

An all-swing apex chart would have six independent coordinates `[dx,y,alphaBL,dalphaBL,alphaBR,dalphaBR]`. The lift fixes pitch and pitch rate to zero and copies hind coordinates to their fore counterparts. The energy pullback adds the corresponding fore derivatives into their hind representatives, then removes the fixed pitch coordinates. A native G predictor may average each nearly equal pair and set its tiny pitch/rate to zero, but that is a new explicitly recorded predictor. Its original bytes and admission remain intact; only a fresh independent nine-gate admission qualifies the projected result.

This sector alone need not repair P2 opposed: a nonzero dx perturbation can break the zero-drift mirror relation and split a contact cohort even when fore/hind pairs remain equal. Its actual dx topology obstruction must not be assumed removed by the six-coordinate restriction.

## Zero-drift longitudinal mirror pairs

Additionally require zero swing rest angles and impose `dx=phi=dphi=0`, `alphaBL=-alphaFR`, `alphaBR=-alphaFL`, the corresponding opposite physical rates, and equal contact modes within these two mirror pairs. Fore/hind stiffnesses and rest lengths still match and COM is centered. The two independent hind angles/rates may differ.

At zero pitch, mirror-paired lengths and compressions agree because cosine is even. Their horizontal force contributions cancel because sine is odd. Their fore/hind pitch torques cancel because their hip offsets are opposite and `cos(alpha)` is even. Thus horizontal and pitch accelerations remain zero. With zero swing rest angles, the remaining swing acceleration is odd in alpha. The native fixed-foot stance projection at zero horizontal and pitch velocity is `dalpha=-dy*tan(alpha)/y`, also odd; differentiating its regular constraint gives the corresponding odd stance acceleration. Mirror-paired guards and guard Lie derivatives agree, and their reset projections preserve opposite rates and equal modes.

An all-swing apex chart would have five coordinates `[y,alphaBL,dalphaBL,alphaBR,dalphaBR]`; the fore coordinates are the negatives of the opposite hind coordinates. Its energy pullback subtracts the appropriate fore ambient derivative from each hind representative. This is a proposed zero-drift acquisition sector. It does not supply traveling daughters or a transverse derivative in dx or pitch.

The retained P2 standing seed nearly satisfies these diagonal mirror constraints; the tiny discrepancies must be explicitly projected only as a new predictor and independently admitted. The P2 opposed seed lies in their intersection with equal fore/hind pairs. In that further intersection, `alphaBR=-alphaBL` and the corresponding rates are opposite; all four modes agree and the chart reduces to `[y,alphaBL,dalphaBL]`. This smaller sector preserves fully simultaneous contact cohorts while retaining the nonzero leg oscillation.

A physical two-flight P2 solution in these sectors can have repeating half-period contact timings while its exact leg-labeled angles/rates differ after one flight. The primitive check must compare full states and keep the declared BL occurrence; it cannot infer a multiple cover from event timing or an iterated-return multiplier. At zero oscillation the BL2 PIP predictor may become a true doubled cover and must fail the unchanged primitive admission gate.

## Gates before implementation or use

Before either extension, retain native controls for flow tangency, exact mode constraints, guard equality/Lie derivatives, TD/LO atomic reset closure and mechanical-energy pullback on admissible regular states. Explicitly test mismatched parameters, nonzero forbidden body coordinates and raw-angle differences. Then separately qualify each projected source through the shared periodic service, preserving its declared return occurrence. Any new matrix is restricted-sector numerical evidence. Accepted roots, local selector/PAL adjacency, and family attachment remain distinct outcomes.
