# idiographic: Idiographic Network Estimation from Intensive Longitudinal Data

Person-specific and within-person network estimation from intensive
longitudinal / ESM panel data: preprocessing audits
([`preprocess()`](https://mohsaqr.github.io/idiographic/reference/preprocess.md)),
edge-stability diagnostics
([`estimate_stability()`](https://mohsaqr.github.io/idiographic/reference/estimate_stability.md)),
model-comparison reports
([`compare_idiographic()`](https://mohsaqr.github.io/idiographic/reference/compare_idiographic.md)),
rolling forecast validation
([`validate_forecast()`](https://mohsaqr.github.io/idiographic/reference/validate_forecast.md)),
rolling ordinary vector autoregression
([`fit_rolling_var()`](https://mohsaqr.github.io/idiographic/reference/fit_rolling_var.md)),
rolling graphical vector autoregression
([`fit_rolling_graphical_var()`](https://mohsaqr.github.io/idiographic/reference/fit_rolling_graphical_var.md)),
ordinary vector autoregression
([`fit_var()`](https://mohsaqr.github.io/idiographic/reference/fit_var.md)),
graphical vector autoregression
([`fit_graphical_var()`](https://mohsaqr.github.io/idiographic/reference/fit_graphical_var.md)),
multilevel vector autoregression
([`fit_mlvar()`](https://mohsaqr.github.io/idiographic/reference/fit_mlvar.md)),
unified SEM
([`fit_usem()`](https://mohsaqr.github.io/idiographic/reference/fit_usem.md)),
Group Iterative Multiple Model Estimation
([`fit_gimme()`](https://mohsaqr.github.io/idiographic/reference/fit_gimme.md)),
and idiographic supervised machine-learning models
([`fit_ml()`](https://mohsaqr.github.io/idiographic/reference/fit_ml.md))
for individualized prediction. Use
[`fit_idiographic()`](https://mohsaqr.github.io/idiographic/reference/fit_idiographic.md)
for registry-driven dispatch or the direct `fit_*()` functions. Every
result has tidy
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html),
[`summary()`](https://rdrr.io/r/base/summary.html), and print methods;
network estimators also share
[`edges()`](https://mohsaqr.github.io/idiographic/reference/edges.md),
[`coefs()`](https://mohsaqr.github.io/idiographic/reference/coefs.md),
[`nodes()`](https://mohsaqr.github.io/idiographic/reference/nodes.md),
[`matrices()`](https://mohsaqr.github.io/idiographic/reference/matrices.md),
and plotting methods.
[`equivalence()`](https://mohsaqr.github.io/idiographic/reference/equivalence.md)
reports the exact validation scope attached to each method.

## See also

Useful links:

- <https://github.com/mohsaqr/idiographic>

- Report bugs at <https://github.com/mohsaqr/idiographic/issues>

## Author

**Maintainer**: Mohammed Saqr <mohammed.saqr@uef.fi> \[copyright
holder\]

Authors:

- Sonsoles López-Pernas <sonsoles.lopez@uef.fi>
