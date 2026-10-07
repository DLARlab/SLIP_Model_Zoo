# Separate standing bounding to traveling BIP connection

Standing bounding has a verified local drift bifurcation to traveling BIP. No connection of this component to the certified PIP–pronking–B2 route is established. The requested filename `BS_10_20_2_BIP_Child.mat` is retained, while the local parent/daughter direction is **standing BS → traveling BIP**.

The critical full period is 2.982228115452. The height-minimum representation has initial horizontal velocity −0.020691583208, initial height 0.969089784386, and pitch rate 0.130759126579; its mean horizontal velocity is zero. It is standing-branch column 24. Traveling daughters recover BIP source columns 233–234. For Floquet analysis the same orbit was shifted by one quarter-cycle to a downward apex.

The extra parent-tangent-removed multiplier crosses `0.996933347 → 0.999997153 → 1.003084193`. The critical distance from +1 is within measured finite-difference uncertainty. Independent native double-kernel and daughter checks support the connection.

- [Standing branch, 213 records](../../BS_10_20_2_BIP_Child.mat) and [BIP, 904 records](../../BIP_10_20_2.mat).
- [Floquet conclusion](Audit/FLOQUET_REPORT.md), [full matrices and perturbations](Bifurcation_Analysis/bip_floquet.mat), [critical/local parent and daughters](Bifurcation_Analysis/BIP_Standing_Parent_Local.mat), and [daughter alignment](Bifurcation_Analysis/daughter_alignment.json).
- [Independent BIP origin audit](Audit/BIP_ORIGIN_REPORT.md) and its numerical records under `Audit/Origin_Evidence`.
- [Standing continuation conclusion](Audit/STANDING_BRANCH_REPORT.md), [233 native-passing candidates](Audit/Standing_Branch_Validation/assembled_validation.mat), and [tighter replay acceptance/exclusion](Audit/Standing_Branch_Validation/all_tight_replay.mat).
- [Zero-swing limit](Audit/Limits/zero_swing_summary.json).

The final standing set is the contiguous 213-record prefix passing native and tighter checks. The remaining 20 candidates are evidence of numerical sensitivity, not accepted branch points. The diagnostic `BS_TightCycle_v2.m` changed ODE tolerances for replay only; the code is in the original-layout archive, and its replay records remain here.
