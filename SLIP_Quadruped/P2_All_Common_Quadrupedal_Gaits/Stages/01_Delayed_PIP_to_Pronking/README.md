# Delayed PIP to traveling pronking

**BP1 is verified:** delayed-liftoff PIP bifurcates to traveling `PK_B2_Parent`. The parent critical state has initial horizontal velocity 0, initial height 1.045694946314, and full period 2.440936446440. It is column 132 of [PK_B2_Parent](../../PK_B2_Parent.mat), corresponding to column 432 of the [delayed analytic family](../../PIP_Delayed_Analytic_10_20_2.mat).

After removing the neutral parent-family direction, the extra Floquet multiplier is `0.9970990097 → 1.0000000676 → 1.0029817283`. Daughter directions converge to the additional critical subspace. The nonlinear check gives `y−yc = 0.2311546965 u² + O(u⁴)`, supporting the reflected traveling pitchfork.

- [Conclusion and Floquet audit](Audit/FLOQUET_REPORT.md).
- [Coarse full matrices and perturbations](Bifurcation_Analysis/coarse/pip_to_pk_floquet.mat) and [fine full matrices and perturbations](Bifurcation_Analysis/fine/pip_to_pk_floquet.mat).
- [Variant selection and numerical convergence](Bifurcation_Analysis/preferred.json), [summary](Bifurcation_Analysis/summary.json), and variant spectra CSVs.
- [Critical parent](Audit/Orbits/PIP_delayed_critical.mat), [local parents](Audit/Orbits/PIP_delayed_local.mat), and [traveling daughters](Audit/Orbits/PK_local_daughters.mat).
- [Nonlinear check](Bifurcation_Analysis/Normal_Form/normal_form_probe.json) and [independent common-leg variational check](Bifurcation_Analysis/Common_Block/common_map_summary.json).

[Next verified stage: pronking to B2](../02_Pronking_to_B2/README.md).
