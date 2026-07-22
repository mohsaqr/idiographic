# Real-20 mlVAR equivalence result

All 20 copied real ESM panels pass the committed cross-platform `1e-6`
tolerance for the validated fixed/fixed lag-1 configuration. The oracle was
generated directly with mlVAR 0.7.3; the package test refits every raw CSV with
native `fit_mlvar()` and compares every estimable network cell. The tolerance
allows for BLAS/LAPACK and mixed-model optimizer differences across operating
systems; it is not a rounding tolerance applied to package output.

Observed differences in the 2026-07-22 audit:

| Layer | Maximum | Median | 95th percentile | Maximum case |
|---|---:|---:|---:|---|
| Temporal | `0` | `0` | `0` | all exact |
| Contemporaneous | `1.23e-15` | `8.05e-16` | `1.15e-15` | 0003 |
| Between | `1.53e-10` | `0` | `2.91e-11` | 0036 |

The Ubuntu R 4.6.1 CI runner produced the same pass/fail conclusions and
sub-micro numerical differences, with the largest displayed discrepancy below
`2.7e-7` in the between layer. The committed `1e-6` bound therefore provides a
small portability margin while remaining materially stricter than reported
coefficient precision.

Datasets 0003 and 0022 are excluded only from the between-cell error summary:
upstream mlVAR returns non-estimable (`NA`) off-diagonal cells, while
idiographic applies its documented zero-network convention. Their temporal and
contemporaneous layers remain part of the numerical comparison.
