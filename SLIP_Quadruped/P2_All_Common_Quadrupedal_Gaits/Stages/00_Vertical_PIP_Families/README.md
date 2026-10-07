# Vertical PIP families and the starting boundary

The ordinary saved PIP and delayed-liftoff PIP have different contact histories. At equal energy, delayed PIP remains in stance for one extra oscillator revolution, increasing its period by `2π/√40 = 0.993458826580`. Their shared zero-flight limit is singular and represents one ordinary traversal versus two delayed traversals. A regular bifurcation connecting them has not been verified.

- [Ordinary PIP branch](../../PIP_10_20_2.mat).
- [Delayed analytic family](../../PIP_Delayed_Analytic_10_20_2.mat): `results` is the 29×1586 delayed family. `ordinaryPIPResults` is a distinct equal-energy comparison, not another phase of the delayed orbit.
- [Contact-history and boundary audit](Audit/VERTICAL_TOPOLOGY.md) and [analytic family construction](Audit/VERTICAL_FAMILIES.md).
- [Native replay coverage](Audit/NATIVE_REPLAY.md), [sample records](Audit/native_sample_validation.mat), and [summary](Audit/native_sample_validation.json).

The analytic family occupies `1 < E < 20`. Only 18 delayed samples have native replay results: 16 pass; columns 1487 and 1586 fail near leg collapse. All other delayed samples are untested natively. Column 432 matches the delayed parent at the next stage to about 1.60×10⁻¹⁵ in the native state/event coordinates.

[Next verified stage: delayed PIP to pronking](../01_Delayed_PIP_to_Pronking/README.md).
