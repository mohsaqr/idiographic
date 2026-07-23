# Changelog

## idiographic 0.3.1

- New package Title — “Idiographic Person-Specific and Heterogeneous
  Complex Networks” — and a rewritten Description with method references
  <doi:10.1007/978-3-031-95365-1_20> and
  <doi:10.1080/00273171.2018.1454823>.
- Added Sonsoles López-Pernas as package author.
- Documentation language standardized to British English
  (`Language: en-GB`), with dialect fixes across the documentation prose
  and a new `inst/WORDLIST` so the package spell check runs clean.

## idiographic 0.2.0

- Made the CRAN package offline-first: the only mandatory imports are
  standard R packages, while `lme4`, `lavaan`, plotting, and external
  backends are optional. Competitor-oracle tests and the real-panel
  corpus now run in a separate opt-in `validation/` lane and are
  excluded from the CRAN tarball.

- Added a registry-backed
  [`fit_idiographic()`](https://mohsaqr.github.io/idiographic/reference/fit_idiographic.md)
  front door, estimator discovery, method-specific
  [`equivalence()`](https://mohsaqr.github.io/idiographic/reference/equivalence.md)
  declarations, package-wide
  [`equivalence_table()`](https://mohsaqr.github.io/idiographic/reference/equivalence_table.md)
  and argument-by-argument
  [`argument_coverage()`](https://mohsaqr.github.io/idiographic/reference/argument_coverage.md)
  ledgers, and common tidy accessors. All 17 registered methods and 315
  current public formals now have an executable evidence classification;
  new unassessed arguments fail the closure test.

- Expanded direct-oracle testing across graphicalVAR option
  combinations, mlVAR multi-lag/preprocessing/unique-model
  configurations, and bivariate plus three-variable GIMME standard,
  hybrid, and VAR searches. GIMME evidence now also covers fit
  statistics, uneven panels, exogenous-variable dimensions, and
  interacting correction/standardization controls. Tightened public
  argument validation so engine-specific controls cannot be silently
  ignored.

- Closed the remaining executable evidence cells: all 12 supported lag-1
  lmer mlVAR structure combinations, per-subject/missing-data
  graphicalVAR fits, GIMME 10.0
  correction/stopping/standardization/cutoff/forced-path controls,
  standardized ML/MLR uSEM fits, Mplus wrapper forwarding/conversion,
  Bayesian burn-in/thinning, positive random-residual recovery, parallel
  mlVAR, and base-R linear/logistic idiographic-ML engine equality.

- Migrated the 20-panel real ESM mlVAR validation corpus from the
  Dynalytics/psychaj work into the CRAN-excluded `validation/` lane,
  with self-contained raw inputs, mlVAR 0.7.3 frozen oracles, provenance
  hashes, and explicit regression coverage for missing IDs, irregular
  occasion gaps, and degenerate between-person networks. Duplicate
  observation keys now fail clearly instead of producing
  row-order-dependent preprocessing.

- **Uniform `fit_*` naming for all estimators (breaking).** Every
  model-fitting verb now uses a single `fit_` prefix:
  [`fit_var()`](https://mohsaqr.github.io/idiographic/reference/fit_var.md),
  [`fit_graphical_var()`](https://mohsaqr.github.io/idiographic/reference/fit_graphical_var.md),
  [`fit_mlvar()`](https://mohsaqr.github.io/idiographic/reference/fit_mlvar.md),
  [`fit_rolling_var()`](https://mohsaqr.github.io/idiographic/reference/fit_rolling_var.md),
  and so on for all estimators. Short model nicknames passed to
  [`compare_idiographic()`](https://mohsaqr.github.io/idiographic/reference/compare_idiographic.md),
  [`estimate_stability()`](https://mohsaqr.github.io/idiographic/reference/estimate_stability.md),
  and
  [`validate_forecast()`](https://mohsaqr.github.io/idiographic/reference/validate_forecast.md)
  (for example, `"var"` and `"graphical_var"`) are unchanged.

- New native Bayesian estimators that statistically reproduce Mplus DSEM
  output without requiring Mplus:

  - [`fit_mlvar_bayes()`](https://mohsaqr.github.io/idiographic/reference/fit_mlvar_bayes.md)
    — two-level Bayesian VAR(1) with latent mean centring.
    `temporal = "fixed"` is statistically validated against frozen Mplus
    DSEM fixed-temporal + random-intercept fixtures;
    `temporal = "random"` fits the full DSEM with person-specific
    temporal matrices and a random-effect covariance (reports
    random-slope SDs).
  - [`fit_var_bayes()`](https://mohsaqr.github.io/idiographic/reference/fit_var_bayes.md)
    — single-level Bayesian VAR(1), the unregularized Bayesian analogue
    of
    [`fit_graphical_var()`](https://mohsaqr.github.io/idiographic/reference/fit_graphical_var.md).

- Pure-R conjugate Gibbs sampler (hand-rolled inverse-Wishart draws; no
  new dependencies). Posterior median / SD / 95% CI / one-tailed p,
  three networks (temporal, contemporaneous, between), and a
  Gelman-Rubin PSR diagnostic.

- Validated to statistical (Monte-Carlo-error) equivalence against real
  Mplus 9 output with frozen ground-truth fixtures and parity tests.

- Added
  [`fit_ml()`](https://mohsaqr.github.io/idiographic/reference/fit_ml.md)
  for idiographic supervised machine-learning: ordered within-person
  train/test splits, person-specific models, pooled baselines on the
  same held-out rows, regression/classification metrics, row-level
  predictions, and coefficient extraction via
  [`coefs()`](https://mohsaqr.github.io/idiographic/reference/coefs.md).
  `model` names the statistical/ML model (for example, `"ridge"`), while
  `estimator` names the implementation/backend (default `"native"`). No
  new dependencies: native models include mean/majority baselines,
  OLS/logistic, ridge, lasso, elastic net, PCR, LDA, Gaussian naive
  Bayes, kNN, and one-split trees.
  [`fit_idiographic_ml()`](https://mohsaqr.github.io/idiographic/reference/fit_ml.md)
  and
  [`fit_individualized_ml()`](https://mohsaqr.github.io/idiographic/reference/fit_ml.md)
  remain aliases.

## idiographic 0.1.0

- Initial CRAN submission.
- Provides idiographic network estimators for intensive longitudinal
  data, including ordinary VAR, graphical VAR, mlVAR, uSEM, and
  GIMME-style models.
- Includes preprocessing audits, rolling-window estimation, forecast
  validation, edge stability diagnostics, model comparison, tidy
  accessors, and cograph plotting support.
