# idiographic: Idiographic Network Estimation from Intensive Longitudinal Data

Person-specific and within-person network estimation from intensive
longitudinal / ESM panel data: preprocessing audits
([`audit_preprocess()`](https://saqr.me/idiographic/reference/audit_preprocess.md)),
edge-stability diagnostics
([`estimate_stability()`](https://saqr.me/idiographic/reference/estimate_stability.md)),
model-comparison reports
([`compare_idiographic()`](https://saqr.me/idiographic/reference/compare_idiographic.md)),
rolling forecast validation
([`validate_forecast()`](https://saqr.me/idiographic/reference/validate_forecast.md)),
rolling ordinary vector autoregression
([`rolling_var()`](https://saqr.me/idiographic/reference/rolling_var.md)),
rolling graphical vector autoregression
([`rolling_graphical_var()`](https://saqr.me/idiographic/reference/rolling_graphical_var.md)),
ordinary vector autoregression
([`build_var()`](https://saqr.me/idiographic/reference/build_var.md)),
graphical vector autoregression
([`graphical_var()`](https://saqr.me/idiographic/reference/graphical_var.md)),
multilevel vector autoregression
([`build_mlvar()`](https://saqr.me/idiographic/reference/build_mlvar.md)),
unified SEM
([`build_usem()`](https://saqr.me/idiographic/reference/build_usem.md)),
and Group Iterative Multiple Model Estimation
([`build_gimme()`](https://saqr.me/idiographic/reference/build_gimme.md)).
Each estimator is implemented clean-room and returns tidy access through
[`edges()`](https://saqr.me/idiographic/reference/edges.md),
[`coefs()`](https://saqr.me/idiographic/reference/coefs.md),
[`nodes()`](https://saqr.me/idiographic/reference/nodes.md), and
[`summary()`](https://rdrr.io/r/base/summary.html).

## Author

**Maintainer**: Mohammed Saqr <mohammed.saqr@uef.fi>
