# Physical branch and trajectory comparisons

This MATLAB snapshot reads all accepted points in the available full-task branches, corrected daughters and labeled historical/validation references. No new shooting or closure certification is performed. Endpoints are finite checkpoints. [Versioned numerical evidence](../Research_v3/next_round/theory/branch_comparison_20261007T170815170.json).

At the exact baseline parameters, horizontal reflection changes `(x,dx,phi,dphi,alpha,beta)` signs and exchanges hind/front legs `[3,4,1,2]`. In the synchronized-pronk restriction the leg exchange is redundant; common guards remain common. With pitch zero, compression depends on `y/cos(alpha)`, horizontal force is odd, vertical force even, and common stance rate `−(v*cos(alpha)^2+dy*sin(alpha)*cos(alpha))/y` is odd. Swing rate/acceleration are odd at zero rest angle. Thus flow, guard/reset maps and energy commute with the reflection; `dy=0` and its crossing direction are unchanged. The common BL occurrence is preserved after whole-orbit reflection because all TDs coincide. This does not authorize arbitrary leg permutations or comparison at different physical parameters. [Flow](../1_Dynamic_Frameworks/Dynamics_v3/ContinuousDynamics_v3.m), [guards](../1_Dynamic_Frameworks/Dynamics_v3/GuardFunctions_v3.m), [reset](../1_Dynamic_Frameworks/Dynamics_v3/ResetMap_v3.m), [restricted analytic chart](Restricted_Odd_Quarter_PIP_Existence_v3.md).

Saved finite synchronization residuals determine numerical eligibility; they do not prove exact isotropy. The reflection model check evaluated 234 saved states: flow, guard, reset and energy errors 2.91e-13, 0, 0 and 0.

| First group | Second group | Closest apex distance | Energy gap | Period gap | Reflected drift gap | Interior trajectory mismatch | Matched post-event mismatch |
|---|---|---:|---:|---:|---:|---:|---:|
| `full_PK_continuation_m1` | `full_PK_continuation_p1` | 0 | 0 | 0 | 0 | 0 | 0 |
| `full_PK_continuation_m1` | `full_restricted_daughter_1_m1` | 0.43805 | 0.438072 | 1.08675 | 0.0190735 | 0.675912 | 0.569752 |
| `full_PK_continuation_m1` | `full_restricted_daughter_1_p1` | 0.438039 | 0.438235 | 1.08673 | 0.0501873 | 0.675916 | 0.569752 |
| `full_PK_continuation_m1` | `full_restricted_daughter_2_m1` | 0.578836 | 0.578854 | 1.33391 | 0.0191482 | 0.823368 | 0.695819 |
| `full_PK_continuation_m1` | `full_restricted_daughter_2_p1` | 0.578829 | 0.578994 | 1.3339 | 0.0503912 | 0.823374 | 0.69582 |
| `full_PK_continuation_m1` | `full_PIP_PK_low_energy_neighborhood_daughter_continuation_1` | 0.000261463 | 5.91041e-07 | 1.25747e-07 | 0.00026119 | 0.000261581 | 0.000179058 |
| `full_PK_continuation_m1` | `full_PIP_candidate_1_daughter_continuation_1` | 0.0553893 | 0.0560246 | 0.231428 | 0.0524572 | 0.1462 | 0.132755 |
| `full_PK_continuation_m1` | `full_PIP_PK_low_energy_neighborhood_amplitude_samples` | 0.00037342 | 1.26525e-06 | 2.70175e-07 | 0.000373031 | 0.00037342 | 0.000255731 |
| `full_PK_continuation_m1` | `full_PIP_candidate_1_amplitude_samples` | 0.0553891 | 0.0560262 | 0.231428 | 0.054856 | 0.146201 | 0.132755 |
| `full_PK_continuation_m1` | `full_PIP_candidate_2_amplitude_samples` | 1.42501 | 1.42501 | 2.47301 | 0.00136495 | 1.47948 | 1.27223 |
| `full_PK_continuation_m1` | `full_PIP_candidate_3_amplitude_samples` | 1.62546 | 1.62546 | 2.69264 | 0.00136733 | 1.62546 | 1.38289 |
| `full_PK_continuation_m1` | `full_opposed_spread_n0_negative_A1e-3_campaign` | 0.0554001 | 0.0558652 | 1.10151 | 0.0469384 | 0.655394 | NaN |
| `full_PK_continuation_m1` | `full_opposed_spread_n0_positive_A1e-3_campaign` | 0.0553999 | 0.055865 | 1.10151 | 0.0469384 | 0.655394 | NaN |
| `full_PK_continuation_m1` | `full_imported_PK_to_low_PIP_daughter_negative_0p01` | 3.59927e-16 | 2.22045e-16 | 6.44999e-10 | 2.74691e-12 | 2.72731e-05 | 6.82602e-10 |
| `full_PK_continuation_m1` | `full_PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0.00037342 | 1.26525e-06 | 2.70175e-07 | 0.000373031 | 0.00037342 | 0.000255731 |
| `full_PK_continuation_m1` | `full_PIP_candidate_1_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0.0553891 | 0.0560262 | 0.231428 | 0.0547017 | 0.1462 | 0.132755 |
| `full_PK_continuation_m1` | `theory_opposed_spread_n0` | 0.0554003 | 0.0558654 | 1.10151 | 0.0469384 | 0.655394 | NaN |
| `full_PK_continuation_m1` | `theory_opposed_spread_n1` | 0.438051 | 0.438051 | 3.73802 | 0.00163797 | 1.47206 | NaN |
| `full_PK_continuation_m1` | `historical_restricted_daughter_1` | 0.43805 | 0.438071 | 1.08675 | 0.0155568 | 0.675912 | 0.569752 |
| `full_PK_continuation_m1` | `historical_restricted_daughter_2` | 0.578836 | 0.578854 | 1.33391 | 0.0156214 | 0.823373 | 0.695819 |
| `full_PK_continuation_m1` | `validation_imported_PK_m1` | 0 | 0 | 0 | 0 | 0 | 0 |
| `full_PK_continuation_p1` | `full_restricted_daughter_1_m1` | 0.438052 | 0.438047 | 1.08675 | 0.0287271 | 0.675903 | 0.569751 |
| `full_PK_continuation_p1` | `full_restricted_daughter_1_p1` | 0.438041 | 0.43821 | 1.08673 | 0.0405337 | 0.675906 | 0.569751 |
| `full_PK_continuation_p1` | `full_restricted_daughter_2_m1` | 0.578838 | 0.57883 | 1.33392 | 0.0288018 | 0.823366 | 0.695817 |
| `full_PK_continuation_p1` | `full_restricted_daughter_2_p1` | 0.57883 | 0.578969 | 1.33391 | 0.0407376 | 0.823372 | 0.695819 |
| `full_PK_continuation_p1` | `full_PIP_PK_low_energy_neighborhood_daughter_continuation_1` | 0.0029153 | 1.1341e-05 | 2.42025e-06 | 0.00291228 | 0.0029153 | 0.0019965 |
| `full_PK_continuation_p1` | `full_PIP_candidate_1_daughter_continuation_1` | 0.0553854 | 0.0560841 | 0.231416 | 0.0551287 | 0.146204 | 0.132758 |
| `full_PK_continuation_p1` | `full_PIP_PK_low_energy_neighborhood_amplitude_samples` | 0.0029153 | 1.1341e-05 | 2.42046e-06 | 0.00291228 | 0.0029153 | 0.00199651 |
| `full_PK_continuation_p1` | `full_PIP_candidate_1_amplitude_samples` | 0.0553853 | 0.0560843 | 0.231416 | 0.0552905 | 0.146204 | 0.132758 |
| `full_PK_continuation_p1` | `full_PIP_candidate_2_amplitude_samples` | 1.42501 | 1.42499 | 2.47301 | 0.0110186 | 1.47948 | 1.27223 |
| `full_PK_continuation_p1` | `full_PIP_candidate_3_amplitude_samples` | 1.62546 | 1.62544 | 2.69264 | 0.0110209 | 1.62546 | 1.38288 |
| `full_PK_continuation_p1` | `full_opposed_spread_n0_negative_A1e-3_campaign` | 0.0553977 | 0.0559016 | 1.10152 | 0.0488578 | 0.655389 | NaN |
| `full_PK_continuation_p1` | `full_opposed_spread_n0_positive_A1e-3_campaign` | 0.0553975 | 0.0559014 | 1.10152 | 0.0488578 | 0.655389 | NaN |
| `full_PK_continuation_p1` | `full_imported_PK_to_low_PIP_daughter_negative_0p01` | 0.00254189 | 1.00757e-05 | 2.15093e-06 | 0.00253925 | 0.00254189 | 0.00174078 |
| `full_PK_continuation_p1` | `full_PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0.0029153 | 1.1341e-05 | 2.42046e-06 | 0.00291228 | 0.0029153 | 0.00199651 |
| `full_PK_continuation_p1` | `full_PIP_candidate_1_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0.0553853 | 0.0560843 | 0.231416 | 0.0552905 | 0.146204 | 0.132758 |
| `full_PK_continuation_p1` | `theory_opposed_spread_n0` | 0.0553979 | 0.0559018 | 1.10152 | 0.0488578 | 0.655389 | NaN |
| `full_PK_continuation_p1` | `theory_opposed_spread_n1` | 0.438053 | 0.438026 | 3.73803 | 0.0112916 | 1.47206 | NaN |
| `full_PK_continuation_p1` | `historical_restricted_daughter_1` | 0.438052 | 0.438047 | 1.08675 | 0.00590317 | 0.675902 | 0.569751 |
| `full_PK_continuation_p1` | `historical_restricted_daughter_2` | 0.578838 | 0.578829 | 1.33392 | 0.00596781 | 0.823371 | 0.695817 |
| `full_PK_continuation_p1` | `validation_imported_PK_m1` | 0 | 0 | 0 | 0 | 0 | 0 |
| `full_restricted_daughter_1_m1` | `full_restricted_daughter_1_p1` | 0 | 0 | 0 | 0 | 0 | 0 |
| `full_restricted_daughter_1_m1` | `full_restricted_daughter_2_m1` | 0.140786 | 0.140783 | 0.247164 | 0.034705 | 0.161201 | 0.126067 |
| `full_restricted_daughter_1_m1` | `full_restricted_daughter_2_p1` | 0.140779 | 0.140923 | 0.247155 | 0.0348345 | 0.161212 | 0.126068 |
| `full_restricted_daughter_1_m1` | `full_PIP_PK_low_energy_neighborhood_daughter_continuation_1` | 0.43805 | 0.438071 | 1.08675 | 0.0201234 | 0.675905 | 0.569752 |
| `full_restricted_daughter_1_m1` | `full_PIP_candidate_1_daughter_continuation_1` | 0.493479 | 0.493499 | 1.3183 | 0.0199115 | 0.801271 | 0.702481 |
| `full_restricted_daughter_1_m1` | `full_PIP_PK_low_energy_neighborhood_amplitude_samples` | 0.43805 | 0.438072 | 1.08675 | 0.0173517 | 0.675905 | 0.569752 |
| `full_restricted_daughter_1_m1` | `full_PIP_candidate_1_amplitude_samples` | 0.493479 | 0.493501 | 1.3183 | 0.0173584 | 0.801271 | 0.702481 |
| `full_restricted_daughter_1_m1` | `full_PIP_candidate_2_amplitude_samples` | 0.986962 | 0.98694 | 1.38626 | 0.0169217 | 0.986962 | 0.702481 |
| `full_restricted_daughter_1_m1` | `full_PIP_candidate_3_amplitude_samples` | 1.18741 | 1.18739 | 1.60589 | 0.0169241 | 1.18741 | 0.813134 |
| `full_restricted_daughter_1_m1` | `full_opposed_spread_n0_negative_A1e-3_campaign` | 0.493479 | 0.493501 | 0.0146706 | 0.0174355 | 0.706306 | NaN |
| `full_restricted_daughter_1_m1` | `full_opposed_spread_n0_positive_A1e-3_campaign` | 0.493479 | 0.493501 | 0.0146703 | 0.0174355 | 0.706306 | NaN |
| `full_restricted_daughter_1_m1` | `full_imported_PK_to_low_PIP_daughter_negative_0p01` | 0.438051 | 0.438058 | 1.08675 | 0.0258148 | 0.675904 | 0.569751 |
| `full_restricted_daughter_1_m1` | `full_PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0.43805 | 0.438072 | 1.08675 | 0.0171842 | 0.675905 | 0.569752 |
| `full_restricted_daughter_1_m1` | `full_PIP_candidate_1_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0.493479 | 0.493501 | 1.3183 | 0.0172041 | 0.801271 | 0.702481 |
| `full_restricted_daughter_1_m1` | `theory_opposed_spread_n0` | 0.493479 | 0.493502 | 0.014671 | 0.0174355 | 0.706307 | NaN |
| `full_restricted_daughter_1_m1` | `theory_opposed_spread_n1` | 0.0119274 | 2.07389e-05 | 2.65128 | 0.0171947 | 1.32769 | NaN |
| `full_restricted_daughter_1_m1` | `historical_restricted_daughter_1` | 0 | 0 | 6.1755e-12 | 3.08191e-14 | 6.05704e-06 | 6.45461e-12 |
| `full_restricted_daughter_1_m1` | `historical_restricted_daughter_2` | 0.140786 | 0.140783 | 0.247164 | 6.46379e-05 | 0.161204 | 0.126067 |
| `full_restricted_daughter_1_m1` | `validation_imported_PK_m1` | 0.43805 | 0.438072 | 1.08675 | 0.0190735 | 0.675912 | 0.569752 |
| `full_restricted_daughter_1_p1` | `full_restricted_daughter_2_m1` | 0.140786 | 0.140783 | 0.247164 | 0.034705 | 0.161201 | 0.126067 |
| `full_restricted_daughter_1_p1` | `full_restricted_daughter_2_p1` | 0.140779 | 0.140923 | 0.247155 | 0.0348345 | 0.161212 | 0.126068 |
| `full_restricted_daughter_1_p1` | `full_PIP_PK_low_energy_neighborhood_daughter_continuation_1` | 0.438039 | 0.438234 | 1.08673 | 0.0491374 | 0.675908 | 0.569752 |
| `full_restricted_daughter_1_p1` | `full_PIP_candidate_1_daughter_continuation_1` | 0.493468 | 0.493662 | 1.31828 | 0.0493493 | 0.801275 | 0.702481 |
| `full_restricted_daughter_1_p1` | `full_PIP_PK_low_energy_neighborhood_amplitude_samples` | 0.438039 | 0.438235 | 1.08673 | 0.0519091 | 0.675908 | 0.569752 |
| `full_restricted_daughter_1_p1` | `full_PIP_candidate_1_amplitude_samples` | 0.493468 | 0.493664 | 1.31828 | 0.0519024 | 0.801275 | 0.702481 |
| `full_restricted_daughter_1_p1` | `full_PIP_candidate_2_amplitude_samples` | 0.986962 | 0.98694 | 1.38626 | 0.0169217 | 0.986962 | 0.702481 |
| `full_restricted_daughter_1_p1` | `full_PIP_candidate_3_amplitude_samples` | 1.18741 | 1.18739 | 1.60589 | 0.0169241 | 1.18741 | 0.813134 |
| `full_restricted_daughter_1_p1` | `full_opposed_spread_n0_negative_A1e-3_campaign` | 0.493468 | 0.493664 | 0.0146877 | 0.0518253 | 0.706311 | NaN |
| `full_restricted_daughter_1_p1` | `full_opposed_spread_n0_positive_A1e-3_campaign` | 0.493468 | 0.493664 | 0.0146873 | 0.0518253 | 0.706311 | NaN |
| `full_restricted_daughter_1_p1` | `full_imported_PK_to_low_PIP_daughter_negative_0p01` | 0.43804 | 0.438222 | 1.08673 | 0.043446 | 0.675907 | 0.569751 |
| `full_restricted_daughter_1_p1` | `full_PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0.438039 | 0.438235 | 1.08673 | 0.0520767 | 0.675908 | 0.569752 |
| `full_restricted_daughter_1_p1` | `full_PIP_candidate_1_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0.493468 | 0.493664 | 1.31828 | 0.0520567 | 0.801275 | 0.702481 |
| `full_restricted_daughter_1_p1` | `theory_opposed_spread_n0` | 0.493468 | 0.493665 | 0.0146881 | 0.0518253 | 0.706311 | NaN |
| `full_restricted_daughter_1_p1` | `theory_opposed_spread_n1` | 0.0119274 | 2.07389e-05 | 2.65128 | 0.0171947 | 1.32769 | NaN |
| `full_restricted_daughter_1_p1` | `historical_restricted_daughter_1` | 0 | 0 | 6.1755e-12 | 3.08191e-14 | 6.05704e-06 | 6.45461e-12 |
| `full_restricted_daughter_1_p1` | `historical_restricted_daughter_2` | 0.140786 | 0.140783 | 0.247164 | 6.46379e-05 | 0.161204 | 0.126067 |
| `full_restricted_daughter_1_p1` | `validation_imported_PK_m1` | 0.438039 | 0.438235 | 1.08673 | 0.0501873 | 0.675916 | 0.569752 |
| `full_restricted_daughter_2_m1` | `full_restricted_daughter_2_p1` | 0 | 0 | 0 | 0 | 0 | 0 |
| `full_restricted_daughter_2_m1` | `full_PIP_PK_low_energy_neighborhood_daughter_continuation_1` | 0.578836 | 0.578854 | 1.33391 | 0.0201981 | 0.823363 | 0.695818 |
| `full_restricted_daughter_2_m1` | `full_PIP_candidate_1_daughter_continuation_1` | 0.634265 | 0.634282 | 1.56547 | 0.0199862 | 0.943158 | 0.828548 |
| `full_restricted_daughter_2_m1` | `full_PIP_PK_low_energy_neighborhood_amplitude_samples` | 0.578836 | 0.578855 | 1.33391 | 0.0174264 | 0.823363 | 0.695819 |
| `full_restricted_daughter_2_m1` | `full_PIP_candidate_1_amplitude_samples` | 0.634265 | 0.634284 | 1.56546 | 0.0174331 | 0.943158 | 0.828548 |
| `full_restricted_daughter_2_m1` | `full_PIP_candidate_2_amplitude_samples` | 0.846176 | 0.846158 | 1.1391 | 0.0169864 | 0.846176 | 0.576415 |
| `full_restricted_daughter_2_m1` | `full_PIP_candidate_3_amplitude_samples` | 1.04663 | 1.04661 | 1.35873 | 0.0169888 | 1.04663 | 0.687067 |
| `full_restricted_daughter_2_m1` | `full_opposed_spread_n0_negative_A1e-3_campaign` | 0.634265 | 0.634284 | 0.232494 | 0.0175102 | 0.88119 | NaN |
| `full_restricted_daughter_2_m1` | `full_opposed_spread_n0_positive_A1e-3_campaign` | 0.634265 | 0.634284 | 0.232494 | 0.0175102 | 0.88119 | NaN |
| `full_restricted_daughter_2_m1` | `full_imported_PK_to_low_PIP_daughter_negative_0p01` | 0.578837 | 0.578841 | 1.33391 | 0.0258895 | 0.823362 | 0.695818 |
| `full_restricted_daughter_2_m1` | `full_PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0.578836 | 0.578855 | 1.33391 | 0.0172588 | 0.823363 | 0.695819 |
| `full_restricted_daughter_2_m1` | `full_PIP_candidate_1_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0.634265 | 0.634284 | 1.56546 | 0.0172788 | 0.943158 | 0.828548 |
| `full_restricted_daughter_2_m1` | `theory_opposed_spread_n0` | 0.634265 | 0.634284 | 0.232493 | 0.0175102 | 0.881191 | NaN |
| `full_restricted_daughter_2_m1` | `theory_opposed_spread_n1` | 0.140785 | 0.140804 | 2.40411 | 0.0175102 | 1.32487 | NaN |
| `full_restricted_daughter_2_m1` | `historical_restricted_daughter_1` | 0.140785 | 0.140803 | 0.247162 | 0.0176822 | 0.1612 | 0.126067 |
| `full_restricted_daughter_2_m1` | `historical_restricted_daughter_2` | 0 | 0 | 7.17026e-12 | 5.1785e-14 | 6.59483e-06 | 6.384e-12 |
| `full_restricted_daughter_2_m1` | `validation_imported_PK_m1` | 0.578836 | 0.578854 | 1.33391 | 0.0191482 | 0.823368 | 0.695819 |
| `full_restricted_daughter_2_p1` | `full_PIP_PK_low_energy_neighborhood_daughter_continuation_1` | 0.578829 | 0.578993 | 1.3339 | 0.0493413 | 0.823371 | 0.69582 |
| `full_restricted_daughter_2_p1` | `full_PIP_candidate_1_daughter_continuation_1` | 0.634258 | 0.634421 | 1.56546 | 0.0495532 | 0.943166 | 0.82855 |
| `full_restricted_daughter_2_p1` | `full_PIP_PK_low_energy_neighborhood_amplitude_samples` | 0.578829 | 0.578994 | 1.3339 | 0.052113 | 0.823371 | 0.69582 |
| `full_restricted_daughter_2_p1` | `full_PIP_candidate_1_amplitude_samples` | 0.634257 | 0.634423 | 1.56546 | 0.0521063 | 0.943166 | 0.82855 |
| `full_restricted_daughter_2_p1` | `full_PIP_candidate_2_amplitude_samples` | 0.846176 | 0.846158 | 1.1391 | 0.0169864 | 0.846176 | 0.576415 |
| `full_restricted_daughter_2_p1` | `full_PIP_candidate_3_amplitude_samples` | 1.04663 | 1.04661 | 1.35873 | 0.0169888 | 1.04663 | 0.687067 |
| `full_restricted_daughter_2_p1` | `full_opposed_spread_n0_negative_A1e-3_campaign` | 0.634258 | 0.634423 | 0.232484 | 0.0520292 | 0.881208 | NaN |
| `full_restricted_daughter_2_p1` | `full_opposed_spread_n0_positive_A1e-3_campaign` | 0.634257 | 0.634423 | 0.232484 | 0.0520292 | 0.881208 | NaN |
| `full_restricted_daughter_2_p1` | `full_imported_PK_to_low_PIP_daughter_negative_0p01` | 0.57883 | 0.57898 | 1.3339 | 0.0436499 | 0.82337 | 0.695819 |
| `full_restricted_daughter_2_p1` | `full_PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0.578829 | 0.578994 | 1.3339 | 0.0522806 | 0.823371 | 0.69582 |
| `full_restricted_daughter_2_p1` | `full_PIP_candidate_1_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0.634257 | 0.634423 | 1.56546 | 0.0522606 | 0.943166 | 0.82855 |
| `full_restricted_daughter_2_p1` | `theory_opposed_spread_n0` | 0.634258 | 0.634424 | 0.232484 | 0.0520292 | 0.881208 | NaN |
| `full_restricted_daughter_2_p1` | `theory_opposed_spread_n1` | 0.140778 | 0.140943 | 2.40412 | 0.0520292 | 1.32486 | NaN |
| `full_restricted_daughter_2_p1` | `historical_restricted_daughter_1` | 0.140777 | 0.140943 | 0.247152 | 0.0518573 | 0.161211 | 0.126068 |
| `full_restricted_daughter_2_p1` | `historical_restricted_daughter_2` | 0 | 0 | 7.17026e-12 | 5.1785e-14 | 6.59483e-06 | 6.384e-12 |
| `full_restricted_daughter_2_p1` | `validation_imported_PK_m1` | 0.578829 | 0.578994 | 1.3339 | 0.0503912 | 0.823374 | 0.69582 |
| `full_PIP_PK_low_energy_neighborhood_daughter_continuation_1` | `full_PIP_candidate_1_daughter_continuation_1` | 0.0554279 | 0.055441 | 0.231553 | 0.00590332 | 0.146174 | 0.13273 |
| `full_PIP_PK_low_energy_neighborhood_daughter_continuation_1` | `full_PIP_PK_low_energy_neighborhood_amplitude_samples` | 0 | 0 | 0 | 0 | 0 | 0 |
| `full_PIP_PK_low_energy_neighborhood_daughter_continuation_1` | `full_PIP_candidate_1_amplitude_samples` | 0.0554278 | 0.0554426 | 0.231552 | 0.00845644 | 0.146174 | 0.13273 |
| `full_PIP_PK_low_energy_neighborhood_daughter_continuation_1` | `full_PIP_candidate_2_amplitude_samples` | 1.42501 | 1.42501 | 2.47301 | 0.00241489 | 1.47948 | 1.27223 |
| `full_PIP_PK_low_energy_neighborhood_daughter_continuation_1` | `full_PIP_candidate_3_amplitude_samples` | 1.62546 | 1.62546 | 2.69264 | 0.00241728 | 1.62546 | 1.38289 |
| `full_PIP_PK_low_energy_neighborhood_daughter_continuation_1` | `full_opposed_spread_n0_negative_A1e-3_campaign` | 0.055428 | 0.0554429 | 1.10142 | 0.0083793 | 0.655456 | NaN |
| `full_PIP_PK_low_energy_neighborhood_daughter_continuation_1` | `full_opposed_spread_n0_positive_A1e-3_campaign` | 0.0554278 | 0.0554426 | 1.10142 | 0.0083793 | 0.655456 | NaN |
| `full_PIP_PK_low_energy_neighborhood_daughter_continuation_1` | `full_imported_PK_to_low_PIP_daughter_negative_0p01` | 6.06204e-12 | 6.05804e-12 | 2.26255e-11 | 1.07978e-12 | 4.50515e-09 | 1.25275e-11 |
| `full_PIP_PK_low_energy_neighborhood_daughter_continuation_1` | `full_PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0 | 0 | 0 | 0 | 0 | 0 |
| `full_PIP_PK_low_energy_neighborhood_daughter_continuation_1` | `full_PIP_candidate_1_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0.0554278 | 0.0554426 | 0.231552 | 0.00861072 | 0.146174 | 0.13273 |
| `full_PIP_PK_low_energy_neighborhood_daughter_continuation_1` | `theory_opposed_spread_n0` | 0.0554283 | 0.0554431 | 1.10142 | 0.0083793 | 0.655456 | NaN |
| `full_PIP_PK_low_energy_neighborhood_daughter_continuation_1` | `theory_opposed_spread_n1` | 0.438051 | 0.43805 | 3.73802 | 0.00268791 | 1.47207 | NaN |
| `full_PIP_PK_low_energy_neighborhood_daughter_continuation_1` | `historical_restricted_daughter_1` | 0.43805 | 0.43807 | 1.08675 | 0.0145068 | 0.675904 | 0.569752 |
| `full_PIP_PK_low_energy_neighborhood_daughter_continuation_1` | `historical_restricted_daughter_2` | 0.578836 | 0.578853 | 1.33391 | 0.0145715 | 0.823368 | 0.695818 |
| `full_PIP_PK_low_energy_neighborhood_daughter_continuation_1` | `validation_imported_PK_m1` | 0.000261463 | 5.91041e-07 | 1.25747e-07 | 0.00026119 | 0.000261581 | 0.000179059 |
| `full_PIP_candidate_1_daughter_continuation_1` | `full_PIP_PK_low_energy_neighborhood_amplitude_samples` | 0.0554279 | 0.055441 | 0.231553 | 0.00590332 | 0.146174 | 0.13273 |
| `full_PIP_candidate_1_daughter_continuation_1` | `full_PIP_candidate_1_amplitude_samples` | 0 | 0 | 0 | 0 | 0 | 0 |
| `full_PIP_candidate_1_daughter_continuation_1` | `full_PIP_candidate_2_amplitude_samples` | 1.48044 | 1.48044 | 2.70456 | 0.00220297 | 1.57578 | 1.40496 |
| `full_PIP_candidate_1_daughter_continuation_1` | `full_PIP_candidate_3_amplitude_samples` | 1.68089 | 1.68089 | 2.92419 | 0.00220535 | 1.69312 | 1.51562 |
| `full_PIP_candidate_1_daughter_continuation_1` | `full_opposed_spread_n0_negative_A1e-3_campaign` | 0.00591982 | 1.90507e-06 | 1.33297 | 0.00247598 | 0.675079 | NaN |
| `full_PIP_candidate_1_daughter_continuation_1` | `full_opposed_spread_n0_positive_A1e-3_campaign` | 0.00424277 | 1.69413e-06 | 1.33297 | 0.00247598 | 0.675079 | NaN |
| `full_PIP_candidate_1_daughter_continuation_1` | `full_imported_PK_to_low_PIP_daughter_negative_0p01` | 0.0554278 | 0.0554422 | 0.231552 | 0.00627635 | 0.146175 | 0.13273 |
| `full_PIP_candidate_1_daughter_continuation_1` | `full_PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0.0554279 | 0.055441 | 0.231553 | 0.00590332 | 0.146174 | 0.13273 |
| `full_PIP_candidate_1_daughter_continuation_1` | `full_PIP_candidate_1_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0 | 0 | 0 | 0 | 0 | 0 |
| `full_PIP_candidate_1_daughter_continuation_1` | `theory_opposed_spread_n0` | 0.00703785 | 2.12382e-06 | 1.33297 | 0.00247598 | 0.675078 | NaN |
| `full_PIP_candidate_1_daughter_continuation_1` | `theory_opposed_spread_n1` | 0.49348 | 0.493478 | 3.96958 | 0.00247598 | 1.41945 | NaN |
| `full_PIP_candidate_1_daughter_continuation_1` | `historical_restricted_daughter_1` | 0.493479 | 0.493499 | 1.3183 | 0.0147188 | 0.801269 | 0.702481 |
| `full_PIP_candidate_1_daughter_continuation_1` | `historical_restricted_daughter_2` | 0.634265 | 0.634281 | 1.56547 | 0.0147834 | 0.943163 | 0.828548 |
| `full_PIP_candidate_1_daughter_continuation_1` | `validation_imported_PK_m1` | 0.0553893 | 0.0560246 | 0.231428 | 0.0524572 | 0.1462 | 0.132755 |
| `full_PIP_PK_low_energy_neighborhood_amplitude_samples` | `full_PIP_candidate_1_amplitude_samples` | 0.0554278 | 0.0554426 | 0.231552 | 0.00845644 | 0.146174 | 0.13273 |
| `full_PIP_PK_low_energy_neighborhood_amplitude_samples` | `full_PIP_candidate_2_amplitude_samples` | 1.42501 | 1.42501 | 2.47301 | 0.000356811 | 1.47948 | 1.27223 |
| `full_PIP_PK_low_energy_neighborhood_amplitude_samples` | `full_PIP_candidate_3_amplitude_samples` | 1.62546 | 1.62546 | 2.69264 | 0.000354423 | 1.62546 | 1.38289 |
| `full_PIP_PK_low_energy_neighborhood_amplitude_samples` | `full_opposed_spread_n0_negative_A1e-3_campaign` | 0.055428 | 0.0554429 | 1.10142 | 0.0083793 | 0.655456 | NaN |
| `full_PIP_PK_low_energy_neighborhood_amplitude_samples` | `full_opposed_spread_n0_positive_A1e-3_campaign` | 0.0554278 | 0.0554426 | 1.10142 | 0.0083793 | 0.655456 | NaN |
| `full_PIP_PK_low_energy_neighborhood_amplitude_samples` | `full_imported_PK_to_low_PIP_daughter_negative_0p01` | 6.06204e-12 | 6.05804e-12 | 2.26255e-11 | 1.07978e-12 | 4.50515e-09 | 1.25275e-11 |
| `full_PIP_PK_low_energy_neighborhood_amplitude_samples` | `full_PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0 | 0 | 0 | 0 | 1.35525e-20 | 0 |
| `full_PIP_PK_low_energy_neighborhood_amplitude_samples` | `full_PIP_candidate_1_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0.0554278 | 0.0554426 | 0.231552 | 0.00861072 | 0.146174 | 0.13273 |
| `full_PIP_PK_low_energy_neighborhood_amplitude_samples` | `theory_opposed_spread_n0` | 0.0554283 | 0.0554431 | 1.10142 | 0.0083793 | 0.655456 | NaN |
| `full_PIP_PK_low_energy_neighborhood_amplitude_samples` | `theory_opposed_spread_n1` | 0.438051 | 0.438051 | 3.73802 | 8.37929e-05 | 1.47207 | NaN |
| `full_PIP_PK_low_energy_neighborhood_amplitude_samples` | `historical_restricted_daughter_1` | 0.43805 | 0.438072 | 1.08675 | 0.0172785 | 0.675904 | 0.569752 |
| `full_PIP_PK_low_energy_neighborhood_amplitude_samples` | `historical_restricted_daughter_2` | 0.578836 | 0.578854 | 1.33391 | 0.0173432 | 0.823368 | 0.695819 |
| `full_PIP_PK_low_energy_neighborhood_amplitude_samples` | `validation_imported_PK_m1` | 0.00037342 | 1.26525e-06 | 2.70175e-07 | 0.000373031 | 0.00037342 | 0.000255731 |
| `full_PIP_candidate_1_amplitude_samples` | `full_PIP_candidate_2_amplitude_samples` | 1.48044 | 1.48044 | 2.70456 | 0.000350158 | 1.57578 | 1.40496 |
| `full_PIP_candidate_1_amplitude_samples` | `full_PIP_candidate_3_amplitude_samples` | 1.68089 | 1.68089 | 2.92419 | 0.00034777 | 1.69312 | 1.51562 |
| `full_PIP_candidate_1_amplitude_samples` | `full_opposed_spread_n0_negative_A1e-3_campaign` | 0.00343404 | 2.77316e-07 | 1.33297 | 7.71396e-05 | 0.675079 | NaN |
| `full_PIP_candidate_1_amplitude_samples` | `full_opposed_spread_n0_positive_A1e-3_campaign` | 0.00175699 | 6.63787e-08 | 1.33297 | 7.71396e-05 | 0.675079 | NaN |
| `full_PIP_candidate_1_amplitude_samples` | `full_imported_PK_to_low_PIP_daughter_negative_0p01` | 0.0554277 | 0.0554438 | 0.231552 | 0.00882947 | 0.146175 | 0.13273 |
| `full_PIP_candidate_1_amplitude_samples` | `full_PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0.0554278 | 0.0554426 | 0.231552 | 0.00845644 | 0.146174 | 0.13273 |
| `full_PIP_candidate_1_amplitude_samples` | `full_PIP_candidate_1_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0 | 0 | 0 | 0 | 3.38813e-21 | 0 |
| `full_PIP_candidate_1_amplitude_samples` | `theory_opposed_spread_n0` | 0.00455207 | 4.96066e-07 | 1.33297 | 7.71396e-05 | 0.675078 | NaN |
| `full_PIP_candidate_1_amplitude_samples` | `theory_opposed_spread_n1` | 0.49348 | 0.49348 | 3.96958 | 7.71396e-05 | 1.41945 | NaN |
| `full_PIP_candidate_1_amplitude_samples` | `historical_restricted_daughter_1` | 0.493479 | 0.4935 | 1.3183 | 0.0172719 | 0.801269 | 0.702481 |
| `full_PIP_candidate_1_amplitude_samples` | `historical_restricted_daughter_2` | 0.634265 | 0.634283 | 1.56546 | 0.0173365 | 0.943163 | 0.828548 |
| `full_PIP_candidate_1_amplitude_samples` | `validation_imported_PK_m1` | 0.0553891 | 0.0560262 | 0.231428 | 0.054856 | 0.146201 | 0.132755 |
| `full_PIP_candidate_2_amplitude_samples` | `full_PIP_candidate_3_amplitude_samples` | 0.20045 | 0.20045 | 0.21963 | 2.38763e-06 | 0.20045 | 0.110652 |
| `full_PIP_candidate_2_amplitude_samples` | `full_opposed_spread_n0_negative_A1e-3_campaign` | 1.48044 | 1.48044 | 1.37159 | 0.000273018 | 1.72704 | NaN |
| `full_PIP_candidate_2_amplitude_samples` | `full_opposed_spread_n0_positive_A1e-3_campaign` | 1.48044 | 1.48044 | 1.37159 | 0.000273018 | 1.72704 | NaN |
| `full_PIP_candidate_2_amplitude_samples` | `full_imported_PK_to_low_PIP_daughter_negative_0p01` | 1.42501 | 1.425 | 2.47301 | 0.00810628 | 1.47948 | 1.27223 |
| `full_PIP_candidate_2_amplitude_samples` | `full_PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 1.42501 | 1.42501 | 2.47301 | 0.000524397 | 1.47948 | 1.27223 |
| `full_PIP_candidate_2_amplitude_samples` | `full_PIP_candidate_1_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 1.48044 | 1.48044 | 2.70456 | 0.000504437 | 1.57578 | 1.40496 |
| `full_PIP_candidate_2_amplitude_samples` | `theory_opposed_spread_n0` | 1.48044 | 1.48044 | 1.37159 | 0.000273018 | 1.72704 | NaN |
| `full_PIP_candidate_2_amplitude_samples` | `theory_opposed_spread_n1` | 0.986961 | 0.986961 | 1.26502 | 0.000273018 | 1.73409 | NaN |
| `full_PIP_candidate_2_amplitude_samples` | `historical_restricted_daughter_1` | 0.98696 | 0.98696 | 1.38626 | 0.000101071 | 0.98696 | 0.702481 |
| `full_PIP_candidate_2_amplitude_samples` | `historical_restricted_daughter_2` | 0.846175 | 0.846175 | 1.13909 | 0.000100424 | 0.846175 | 0.576415 |
| `full_PIP_candidate_2_amplitude_samples` | `validation_imported_PK_m1` | 1.42501 | 1.42501 | 2.47301 | 0.00136495 | 1.47948 | 1.27223 |
| `full_PIP_candidate_3_amplitude_samples` | `full_opposed_spread_n0_negative_A1e-3_campaign` | 1.68089 | 1.68089 | 1.59122 | 0.000270631 | 1.87801 | NaN |
| `full_PIP_candidate_3_amplitude_samples` | `full_opposed_spread_n0_positive_A1e-3_campaign` | 1.68089 | 1.68089 | 1.59122 | 0.000270631 | 1.87801 | NaN |
| `full_PIP_candidate_3_amplitude_samples` | `full_imported_PK_to_low_PIP_daughter_negative_0p01` | 1.62546 | 1.62545 | 2.69264 | 0.00810867 | 1.62546 | 1.38288 |
| `full_PIP_candidate_3_amplitude_samples` | `full_PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 1.62546 | 1.62546 | 2.69264 | 0.000522009 | 1.62546 | 1.38289 |
| `full_PIP_candidate_3_amplitude_samples` | `full_PIP_candidate_1_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 1.68089 | 1.68089 | 2.92419 | 0.000502049 | 1.69312 | 1.51562 |
| `full_PIP_candidate_3_amplitude_samples` | `theory_opposed_spread_n0` | 1.68089 | 1.68089 | 1.59122 | 0.000270631 | 1.87801 | NaN |
| `full_PIP_candidate_3_amplitude_samples` | `theory_opposed_spread_n1` | 1.18741 | 1.18741 | 1.04539 | 0.000270631 | 1.93496 | NaN |
| `full_PIP_candidate_3_amplitude_samples` | `historical_restricted_daughter_1` | 1.18741 | 1.18741 | 1.60589 | 9.86832e-05 | 1.18741 | 0.813134 |
| `full_PIP_candidate_3_amplitude_samples` | `historical_restricted_daughter_2` | 1.04662 | 1.04662 | 1.35872 | 9.80368e-05 | 1.04662 | 0.687067 |
| `full_PIP_candidate_3_amplitude_samples` | `validation_imported_PK_m1` | 1.62546 | 1.62546 | 2.69264 | 0.00136733 | 1.62546 | 1.38289 |
| `full_opposed_spread_n0_negative_A1e-3_campaign` | `full_opposed_spread_n0_positive_A1e-3_campaign` | 0.00503115 | 2.10937e-07 | 3.56055e-07 | 0 | 0.00168203 | 0.000375 |
| `full_opposed_spread_n0_negative_A1e-3_campaign` | `full_imported_PK_to_low_PIP_daughter_negative_0p01` | 0.055428 | 0.0554441 | 1.10142 | 0.00875233 | 0.655292 | NaN |
| `full_opposed_spread_n0_negative_A1e-3_campaign` | `full_PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0.055428 | 0.0554429 | 1.10142 | 0.0083793 | 0.655292 | NaN |
| `full_opposed_spread_n0_negative_A1e-3_campaign` | `full_PIP_candidate_1_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0.00343404 | 2.77316e-07 | 1.33297 | 7.71396e-05 | 0.675134 | NaN |
| `full_opposed_spread_n0_negative_A1e-3_campaign` | `theory_opposed_spread_n0` | 0 | 0 | 2.0326e-12 | 0 | 1.096e-06 | 1.14941e-12 |
| `full_opposed_spread_n0_negative_A1e-3_campaign` | `theory_opposed_spread_n1` | 0.49348 | 0.49348 | 2.63661 | 0 | 0.801272 | 0.702481 |
| `full_opposed_spread_n0_negative_A1e-3_campaign` | `historical_restricted_daughter_1` | 0.493479 | 0.493501 | 0.0146706 | 0.0171947 | 0.706306 | NaN |
| `full_opposed_spread_n0_negative_A1e-3_campaign` | `historical_restricted_daughter_2` | 0.634265 | 0.634283 | 0.232494 | 0.0172594 | 0.88093 | NaN |
| `full_opposed_spread_n0_negative_A1e-3_campaign` | `validation_imported_PK_m1` | 0.0554001 | 0.0558652 | 1.10151 | 0.0469384 | 0.65523 | NaN |
| `full_opposed_spread_n0_positive_A1e-3_campaign` | `full_imported_PK_to_low_PIP_daughter_negative_0p01` | 0.0554277 | 0.0554439 | 1.10142 | 0.00875233 | 0.655292 | NaN |
| `full_opposed_spread_n0_positive_A1e-3_campaign` | `full_PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0.0554278 | 0.0554426 | 1.10142 | 0.0083793 | 0.655292 | NaN |
| `full_opposed_spread_n0_positive_A1e-3_campaign` | `full_PIP_candidate_1_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0.00175699 | 6.63787e-08 | 1.33297 | 7.71396e-05 | 0.675134 | NaN |
| `full_opposed_spread_n0_positive_A1e-3_campaign` | `theory_opposed_spread_n0` | 0 | 0 | 2.0326e-12 | 0 | 1.096e-06 | 1.14941e-12 |
| `full_opposed_spread_n0_positive_A1e-3_campaign` | `theory_opposed_spread_n1` | 0.49348 | 0.49348 | 2.63661 | 0 | 0.801272 | 0.702481 |
| `full_opposed_spread_n0_positive_A1e-3_campaign` | `historical_restricted_daughter_1` | 0.493479 | 0.493501 | 0.0146702 | 0.0171947 | 0.706306 | NaN |
| `full_opposed_spread_n0_positive_A1e-3_campaign` | `historical_restricted_daughter_2` | 0.634265 | 0.634283 | 0.232494 | 0.0172594 | 0.88093 | NaN |
| `full_opposed_spread_n0_positive_A1e-3_campaign` | `validation_imported_PK_m1` | 0.0553999 | 0.055865 | 1.10151 | 0.0469384 | 0.65523 | NaN |
| `full_imported_PK_to_low_PIP_daughter_negative_0p01` | `full_PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 6.06204e-12 | 6.05804e-12 | 2.26255e-11 | 1.07978e-12 | 4.50515e-09 | 1.25275e-11 |
| `full_imported_PK_to_low_PIP_daughter_negative_0p01` | `full_PIP_candidate_1_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0.0554277 | 0.0554438 | 0.231552 | 0.00898375 | 0.146175 | 0.13273 |
| `full_imported_PK_to_low_PIP_daughter_negative_0p01` | `theory_opposed_spread_n0` | 0.0554282 | 0.0554443 | 1.10142 | 0.00875233 | 0.655456 | NaN |
| `full_imported_PK_to_low_PIP_daughter_negative_0p01` | `theory_opposed_spread_n1` | 0.438052 | 0.438037 | 3.73802 | 0.0083793 | 1.47206 | NaN |
| `full_imported_PK_to_low_PIP_daughter_negative_0p01` | `historical_restricted_daughter_1` | 0.438051 | 0.438058 | 1.08675 | 0.00881545 | 0.675903 | 0.569751 |
| `full_imported_PK_to_low_PIP_daughter_negative_0p01` | `historical_restricted_daughter_2` | 0.578837 | 0.578841 | 1.33391 | 0.00888009 | 0.823367 | 0.695818 |
| `full_imported_PK_to_low_PIP_daughter_negative_0p01` | `validation_imported_PK_m1` | 3.59927e-16 | 2.22045e-16 | 6.44999e-10 | 2.74691e-12 | 2.72731e-05 | 6.82602e-10 |
| `full_PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | `full_PIP_candidate_1_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0.0554278 | 0.0554426 | 0.231552 | 0.00861072 | 0.146174 | 0.13273 |
| `full_PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | `theory_opposed_spread_n0` | 0.0554283 | 0.0554431 | 1.10142 | 0.0083793 | 0.655456 | NaN |
| `full_PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | `theory_opposed_spread_n1` | 0.438051 | 0.438051 | 3.73802 | 0.000251379 | 1.47207 | NaN |
| `full_PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | `historical_restricted_daughter_1` | 0.43805 | 0.438072 | 1.08675 | 0.0174461 | 0.675904 | 0.569752 |
| `full_PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | `historical_restricted_daughter_2` | 0.578836 | 0.578854 | 1.33391 | 0.0175108 | 0.823368 | 0.695819 |
| `full_PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | `validation_imported_PK_m1` | 0.00037342 | 1.26525e-06 | 2.70175e-07 | 0.000373031 | 0.00037342 | 0.000255731 |
| `full_PIP_candidate_1_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | `theory_opposed_spread_n0` | 0.00455207 | 4.96066e-07 | 1.33297 | 7.71396e-05 | 0.675078 | NaN |
| `full_PIP_candidate_1_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | `theory_opposed_spread_n1` | 0.49348 | 0.49348 | 3.96958 | 0.000231419 | 1.41945 | NaN |
| `full_PIP_candidate_1_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | `historical_restricted_daughter_1` | 0.493479 | 0.4935 | 1.3183 | 0.0174262 | 0.801269 | 0.702481 |
| `full_PIP_candidate_1_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | `historical_restricted_daughter_2` | 0.634265 | 0.634283 | 1.56546 | 0.0174908 | 0.943163 | 0.828548 |
| `full_PIP_candidate_1_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | `validation_imported_PK_m1` | 0.0553891 | 0.0560262 | 0.231428 | 0.0547017 | 0.1462 | 0.132755 |
| `theory_opposed_spread_n0` | `theory_opposed_spread_n1` | 0.49348 | 0.49348 | 2.63661 | 0 | 0.801272 | 0.702481 |
| `theory_opposed_spread_n0` | `historical_restricted_daughter_1` | 0.493479 | 0.493501 | 0.0146709 | 0.0171947 | 0.706306 | NaN |
| `theory_opposed_spread_n0` | `historical_restricted_daughter_2` | 0.634265 | 0.634284 | 0.232493 | 0.0172594 | 0.880931 | NaN |
| `theory_opposed_spread_n0` | `validation_imported_PK_m1` | 0.0554003 | 0.0558654 | 1.10151 | 0.0469384 | 0.655229 | NaN |
| `theory_opposed_spread_n1` | `historical_restricted_daughter_1` | 0.00454669 | 5.04081e-07 | 2.65127 | 0.000171947 | 1.32681 | NaN |
| `theory_opposed_spread_n1` | `historical_restricted_daughter_2` | 0.140785 | 0.140803 | 2.40411 | 0.0172594 | 1.3242 | NaN |
| `theory_opposed_spread_n1` | `validation_imported_PK_m1` | 0.438051 | 0.438051 | 3.73802 | 0.00163797 | 1.47187 | NaN |
| `historical_restricted_daughter_1` | `historical_restricted_daughter_2` | 0.140785 | 0.140803 | 0.247162 | 0.0170874 | 0.161204 | 0.126067 |
| `historical_restricted_daughter_1` | `validation_imported_PK_m1` | 0.43805 | 0.438071 | 1.08675 | 0.0155568 | 0.675912 | 0.569752 |
| `historical_restricted_daughter_2` | `validation_imported_PK_m1` | 0.578836 | 0.578854 | 1.33391 | 0.0156214 | 0.823373 | 0.695819 |

Opposite signed representatives within a group were also compared after the same allowed reflection. These sampled agreements check actual trajectories; they are not exact isotropy proofs.

| Group | Reflected apex distance | Energy gap | Period gap | Reflected drift gap | Interior mismatch | Matched post-event mismatch |
|---|---:|---:|---:|---:|---:|---:|
| `full_PK_continuation_m1` | 0.000682602 | 2.45506e-06 | 5.23783e-07 | 0.000681891 | 0.000682602 | 0.000467471 |
| `full_restricted_daughter_1_m1` | 0.000104399 | 5.70854e-07 | 5.96015e-08 | 0.000240785 | 0.000240785 | 0.000143737 |
| `full_restricted_daughter_2_m1` | 0.000115848 | 5.06505e-07 | 3.4697e-08 | 0.000250822 | 0.000250822 | 0.000147306 |
| `full_PIP_PK_low_energy_neighborhood_amplitude_samples` | 0 | 0 | 0 | 0 | 1.35525e-20 | 0 |
| `full_PIP_candidate_1_amplitude_samples` | 0 | 0 | 0 | 0 | 3.38813e-21 | 0 |
| `full_PIP_PK_low_energy_neighborhood_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0 | 0 | 0 | 0 | 1.35525e-20 | 0 |
| `full_PIP_candidate_1_attachment_accuracy_repair_plus_0.0003_revision02_copied_amplitude_evidence` | 0 | 0 | 0 | 0 | 3.38813e-21 | 0 |
| `historical_restricted_daughter_1` | 0 | 0 | 0 | 0 | 1.69407e-21 | 0 |
| `historical_restricted_daughter_2` | 0 | 0 | 0 | 0 | 6.77626e-21 | 0 |
| `validation_imported_PK_m1` | 0.000682602 | 2.45506e-06 | 5.23783e-07 | 0.000681891 | 0.000682602 | 0.000467471 |

The nearest search removes only constant horizontal translation and optionally applies the stated reflection. Trajectory phase candidates come from matching physical contact events; interpolation remains on recorded smooth sides and explicitly compares both sides of each matched event. Gaps below the phase resolution are excluded from the interior grid and retained separately as matched-event phase gaps. All states and differences use the model nondimensional coordinates with unit component scales. Sampling/interpolation differences are numerical diagnostics without validated error bounds. Distinct energies exclude identity of individual conservative orbits after reflection/rephasing, but do not establish or exclude a connecting branch. Equal gait names and small sampled distances establish no ancestry.

Opposed-spread signed records are separately checked under their proved half-period time-phase relation with unchanged leg labels. Accuracy-copy groups explicitly resolve original amplitude files under their source task, retaining only the replacement in the accuracy task; copied records are not new families or continuation progress. Bridge groups contain freshly admitted source evidence and actual accepted increments, whose local connection/identity gate remains separate.

| Opposed-spread first group | Second group | Absolute TD angle | Measured phase shift | Energy gap | Period gap | Interior mismatch | Matched post-event mismatch |
|---|---|---:|---:|---:|---:|---:|---:|
| `full_opposed_spread_n0_positive_A1e-3_campaign` | `full_opposed_spread_n0_negative_A1e-3_campaign` | 0.001 | 0.5 | 0 | 0 | 1.22807e-09 | 6.60583e-14 |
| `full_opposed_spread_n0_positive_A1e-3_campaign` | `full_opposed_spread_n0_negative_A1e-3_campaign` | 0.001 | 0.5 | 7.03881e-14 | 7.07878e-13 | 3.91073e-08 | 2.73281e-13 |
| `full_opposed_spread_n0_positive_A1e-3_campaign` | `full_opposed_spread_n0_negative_A1e-3_campaign` | 0.001 | 0.5 | 1.10865e-11 | 1.04987e-10 | 1.82795e-08 | 3.16303e-11 |
| `full_opposed_spread_n0_positive_A1e-3_campaign` | `full_opposed_spread_n0_negative_A1e-3_campaign` | 0.001 | 0.5 | 1.10161e-11 | 1.04279e-10 | 2.20453e-08 | 3.14235e-11 |
| `full_opposed_spread_n0_positive_A1e-3_campaign` | `full_opposed_spread_n0_negative_A1e-3_campaign` | 0.00075 | 0.5 | 0 | 0 | 4.83272e-09 | 6.25611e-14 |
| `full_opposed_spread_n0_positive_A1e-3_campaign` | `full_opposed_spread_n0_negative_A1e-3_campaign` | 0.00125 | 0.5 | 0 | 0 | 1.99794e-08 | 7.15539e-14 |
| `full_opposed_spread_n0_positive_A1e-3_campaign` | `theory_opposed_spread_n0` | 0.001 | 0.5 | 0 | 2.0326e-12 | 1.09598e-06 | 1.21547e-12 |
| `full_opposed_spread_n0_positive_A1e-3_campaign` | `theory_opposed_spread_n0` | 0.001 | 0.5 | 1.10865e-11 | 1.0702e-10 | 1.09537e-06 | 3.27797e-11 |
| `theory_opposed_spread_n0` | `full_opposed_spread_n0_negative_A1e-3_campaign` | 0.001 | 0.5 | 0 | 2.0326e-12 | 1.09598e-06 | 1.21547e-12 |
| `theory_opposed_spread_n0` | `full_opposed_spread_n0_negative_A1e-3_campaign` | 0.001 | 0.5 | 7.03881e-14 | 2.74047e-12 | 1.09569e-06 | 1.4227e-12 |
| `theory_opposed_spread_n0` | `theory_opposed_spread_n0` | 0.001 | 0.5 | 0 | 0 | 1.96965e-08 | 6.50868e-13 |
| `theory_opposed_spread_n1` | `theory_opposed_spread_n1` | 0.001 | 0.5 | 0 | 0 | 2.35128e-10 | 8.68861e-13 |
