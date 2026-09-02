# idiographic: Person-Specific Statistics and Dynamic Networks

Person-specific and within-person analysis of intensive longitudinal and
ESM panel data. The statistical workflow includes person-level
descriptions
([`describe_persons()`](https://pak.dynasite.org/idiographic/reference/describe_persons.md)),
centring, decomposition, and lagging
([`preprocess_panel()`](https://pak.dynasite.org/idiographic/reference/preprocess_panel.md)),
scoped regression
([`fit_lm()`](https://pak.dynasite.org/idiographic/reference/fit_lm.md),
[`fit_glm()`](https://pak.dynasite.org/idiographic/reference/fit_glm.md)),
machine learning
([`fit_ml()`](https://pak.dynasite.org/idiographic/reference/fit_ml.md)),
within-between effects
([`fit_within_between()`](https://pak.dynasite.org/idiographic/reference/fit_within_between.md)),
coefficient pooling
([`pool_coefs()`](https://pak.dynasite.org/idiographic/reference/pool_coefs.md)),
subgroup analysis
([`test_subgroups()`](https://pak.dynasite.org/idiographic/reference/test_subgroups.md),
[`find_subgroups()`](https://pak.dynasite.org/idiographic/reference/find_subgroups.md)),
treatment effects
([`fit_effects()`](https://pak.dynasite.org/idiographic/reference/fit_effects.md)),
and heterogeneity
([`fit_heterogeneity()`](https://pak.dynasite.org/idiographic/reference/fit_heterogeneity.md)).

## Details

Dynamic-network methods include network preprocessing audits
([`preprocess()`](https://pak.dynasite.org/idiographic/reference/preprocess.md)),
edge-stability diagnostics
([`estimate_stability()`](https://pak.dynasite.org/idiographic/reference/estimate_stability.md)),
rolling forecast validation
([`validate_forecast()`](https://pak.dynasite.org/idiographic/reference/validate_forecast.md)),
ordinary and graphical vector autoregression
([`fit_var()`](https://pak.dynasite.org/idiographic/reference/fit_var.md),
[`fit_graphical_var()`](https://pak.dynasite.org/idiographic/reference/fit_graphical_var.md)),
multilevel and Bayesian VAR
([`fit_mlvar()`](https://pak.dynasite.org/idiographic/reference/fit_mlvar.md),
[`fit_mlvar_bayes()`](https://pak.dynasite.org/idiographic/reference/fit_mlvar_bayes.md)),
unified SEM
([`fit_usem()`](https://pak.dynasite.org/idiographic/reference/fit_usem.md)),
and GIMME
([`fit_gimme()`](https://pak.dynasite.org/idiographic/reference/fit_gimme.md)).
Use
[`fit_idiographic()`](https://pak.dynasite.org/idiographic/reference/fit_idiographic.md)
for registry-driven dispatch or the direct `fit_*()` functions. Results
provide tidy accessors, readable print methods, diagnostics, and plots
appropriate to their analytical level.
[`equivalence()`](https://pak.dynasite.org/idiographic/reference/equivalence.md)
reports the exact validation scope attached to registered network
methods.

## See also

Useful links:

- <https://pak.dynasite.org/idiographic/>

- <https://github.com/mohsaqr/idiographic>

- Report bugs at <https://github.com/mohsaqr/idiographic/issues>

## Author

**Maintainer**: Mohammed Saqr <saqr@saqr.me> \[copyright holder\]

Authors:

- Sonsoles López-Pernas <sonsoles.lopez@uef.fi>
