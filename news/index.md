# Changelog

## idiographic (development version)

- New native Bayesian estimators that statistically reproduce Mplus DSEM
  output without requiring Mplus:
  - [`build_mlvar_bayes()`](https://saqr.me/idiographic/reference/build_mlvar_bayes.md)
    — two-level Bayesian VAR(1) with latent mean centering.
    `temporal = "fixed"` matches Mplus DSEM fixed temporal + random
    intercepts; `temporal = "random"` fits the full DSEM with
    person-specific temporal matrices and a random-effect covariance
    (reports random-slope SDs).
  - [`build_var_bayes()`](https://saqr.me/idiographic/reference/build_var_bayes.md)
    — single-level Bayesian VAR(1), the unregularized Bayesian analogue
    of
    [`graphical_var()`](https://saqr.me/idiographic/reference/graphical_var.md).
- Pure-R conjugate Gibbs sampler (hand-rolled inverse-Wishart draws; no
  new dependencies). Posterior median / SD / 95% CI / one-tailed p,
  three networks (temporal, contemporaneous, between), and a
  Gelman-Rubin PSR diagnostic.
- Validated to statistical (Monte-Carlo-error) equivalence against real
  Mplus 9 output; frozen ground-truth fixtures and parity tests under
  `tests/testthat/fixtures/mplus/`. See `MPLUS-EQUIVALENCE.md`.

## idiographic 0.1.0

- Initial CRAN submission.
- Provides idiographic network estimators for intensive longitudinal
  data, including ordinary VAR, graphical VAR, mlVAR, uSEM, and
  GIMME-style models.
- Includes preprocessing audits, rolling-window estimation, forecast
  validation, edge stability diagnostics, model comparison, tidy
  accessors, and cograph plotting support.
