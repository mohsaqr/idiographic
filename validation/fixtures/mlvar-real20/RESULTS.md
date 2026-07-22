# Real-20 mlVAR equivalence result

All 20 copied real ESM panels pass the committed `1e-8` tolerance for the
validated fixed/fixed lag-1 configuration. The oracle was generated directly
with mlVAR 0.7.3; the package test refits every raw CSV with native
`fit_mlvar()` and compares every estimable network cell.

Observed differences in the 2026-07-22 audit:

| Layer | Maximum | Median | 95th percentile | Maximum case |
|---|---:|---:|---:|---|
| Temporal | `0` | `0` | `0` | all exact |
| Contemporaneous | `1.23e-15` | `8.05e-16` | `1.15e-15` | 0003 |
| Between | `1.53e-10` | `0` | `2.91e-11` | 0036 |

Datasets 0003 and 0022 are excluded only from the between-cell error summary:
upstream mlVAR returns non-estimable (`NA`) off-diagonal cells, while
idiographic applies its documented zero-network convention. Their temporal and
contemporaneous layers remain part of the numerical comparison.
