# Roadmap secondary-bifurcation robustness report

Generated: `20260805T114508`  
Status: **validated**

Parent-only 6/6; held-out 6/6; 6 targeted transitions; robustness status: validated.

This is a retrospective, targeted-window robustness experiment. Window locations were calibrated from the historical roadmap. For each transition, its designated daughter data were excluded from that transition's Stage-A Floquet, refinement, and correction calculation, then consulted in Stage B after that parent prediction was frozen. FG and HE also serve as parents in separate later transitions. This is not an exhaustive blind scan.

| transition | refined dx | lambda residual | SVD nullity | max FD error | max timing residual | pair | odd residual | corrections | daughter alignment | status |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---|
| bg_to_hg | 4.50616189521 | -6.957e-08 | 2 | 1.062e-07 | 2.792e-12 | hind | 7.119e-06 | 4 | 0.999918 | validated |
| bg_to_fg | 5.64566295496 | -2.856e-09 | 2 | 3.150e-08 | 3.431e-11 | front | 1.010e-07 | 4 | 0.999063 | validated |
| be_to_fe | 4.83363821441 | -1.718e-08 | 2 | 5.770e-08 | 2.822e-12 | front | 6.897e-06 | 4 | 1.000000 | validated |
| be_to_he | 6.04807025559 | 4.812e-09 | 2 | 2.966e-08 | 2.451e-12 | hind | 1.624e-07 | 4 | 0.999257 | validated |
| fg_to_gg | 5.91164917105 | -5.671e-09 | 2 | 3.613e-09 | 1.690e-12 | hind | 2.768e-07 | 4 | 0.999791 | validated |
| he_to_ge | 6.13622289546 | 2.970e-09 | 2 | 1.889e-07 | 5.369e-13 | front | 1.214e-05 | 4 | 0.999819 | validated |

## Interpretation

Each accepted multiplier is from the 12-state reduced apex return map. Event times were solved for every perturbation and lifted into branch predictors, but were not Floquet coordinates. The exact refined SVD nullity—not the detector's loose candidate multiplicity—verifies one tangent plus one additional mode.

The two corrected signs persist at multiple radii, pass the canonical residual and an independent Poincare-map check, have the expected gait label, and map into one another under the broken front/hind leg swap. Daughter alignment is evaluated separately for both signs at the smallest persistent accepted radius.

## Limitation: folded parent coordinates

BG, BE, FG, and HE fold in `dx`. The selected adjacent brackets were verified to be locally monotone before `RefineCriticalOrbit` fixed `X(1)=dx`. Branch-wide discovery requires a pseudo-arclength critical-orbit refiner and is not claimed here.
