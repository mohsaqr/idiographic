# idiographic 0.3.4

## New features

* The pure-R graphical-lasso kernel that powers `fit_graphical_var()` is now a
  supported public API: `glasso_fit()`, `glasso_path()`, and `glasso_kkt()`.
  `glasso_fit()` returns a `glasso_result` whose `$wi` and `$w` elements are
  named exactly as `glasso::glasso()`'s, so existing call sites port unchanged,
  and it supports element-wise penalty matrices and hard zero constraints in
  addition to a scalar penalty. `glasso_kkt()` certifies a solution from the
  graphical-lasso stationarity conditions rather than against another solver.
  Both results have `print()` and tidy `as.data.frame()` methods. This exists so
  sibling packages can drop their own copies of the same kernel and depend on
  this one; see `OFFLOAD.md` in the repository.

* `matrices()` gains a `print` argument. The default (`print = TRUE`) is
  unchanged: it prints each matrix and returns the list invisibly. With
  `print = FALSE` the function prints nothing and returns the list visibly,
  which is the form dependent packages and resampling loops need. Threaded
  through every `matrices()` method, including those that delegate to another
  method. `print` follows `...` in every method, so it must be named in full
  and can never be matched positionally or by partial name.

## Bug fixes

* `glasso_kkt()` no longer reports optimal zero-constrained fits as
  non-optimal. At an entry hard-constrained by `zero`, the inactive-edge
  condition `|W_ij - S_ij| <= rho_ij` does not apply: the equality constraint
  carries its own Lagrange multiplier, which absorbs the residual. Constrained
  pairs are now excluded from the check. A fit matching `glasso`'s Fortran
  kernel to 2e-12 previously certified as violating optimality by 0.028.

* `glasso_fit()` now rejects a covariance matrix that is not positive
  semi-definite (classed condition `idiographic_not_psd`). A negative
  eigenvalue produced a precision matrix with a negative diagonal, from which
  every partial correlation was `NaN`. Singular but positive semi-definite
  covariances remain valid input. The tidy accessor also refuses a precision
  matrix with a non-positive diagonal (`idiographic_bad_precision`) rather than
  letting `stats::cov2cor()` warn and emit `NaN` weights.

* An asymmetric element-wise penalty matrix is now rejected by `glasso_fit()`
  and by `fit_graphical_var()`'s `regularize_mat_kappa`. The penalty on edge
  `(i, j)` is a single scalar over a symmetric `Theta`, so an asymmetric
  penalty is ill-posed rather than stricter; previously it was accepted and
  produced a fit that failed the package's own optimality check.

* `glasso_kkt()` validates `penalize_diagonal` instead of letting `isTRUE()`
  silently map `NA` and other invalid values to `FALSE`, and warns
  (`idiographic_glasso_kkt_override`) when a supplied `rho` or
  `penalize_diagonal` differs from the one the fit was made with, since the
  returned violation then certifies a different problem.

* The internal graphical-lasso optimality checker used to measure the
  *unpenalised* diagonal stationarity condition (`W_ii = S_ii`) even for fits
  made with `penalize.diagonal = TRUE`, whose condition is `W_ii - S_ii = rho`.
  It therefore reported a spurious violation of exactly `rho` for every such
  fit — including `glasso`'s own Fortran output, which is how this was found.
  It now takes the diagonal-penalty flag into account. No estimator result and
  no previously published number changes; only the diagnostic was wrong.

## Documentation

* `matrices()` now documents that it is a display verb by default, and points
  at `print = FALSE` for programmatic extraction.

* The three most computationally expensive vignettes -- Graphical VAR,
  Bayesian VAR/DSEM, and GIMME -- are now pkgdown articles rather than
  installed vignettes. Their content is unchanged and they remain published at
  <https://pak.dynasite.org/idiographic/>, but they are no longer rebuilt
  during `R CMD check`. Rebuilding all ten vignettes took 574 seconds on
  Windows R-devel (68% of the total check time, against CRAN's 10-minute
  guideline); these three accounted for the large majority of it. The
  remaining seven vignettes are renumbered 1-7.

# idiographic 0.3.2

* New package Title — "Idiographic Person-Specific and Heterogeneous Complex
  Networks" — and a rewritten Description with method references
  <doi:10.1007/978-3-031-95365-1_20> and <doi:10.1080/00273171.2018.1454823>.
* Added Sonsoles López-Pernas as package author.
* Documentation language standardized to British English (`Language: en-GB`),
  with dialect fixes across the documentation prose and a new `inst/WORDLIST`
  so the package spell check runs clean.
* Slimmer CRAN footprint: all competitor-equivalence tests now live only in
  the repository's opt-in validation lane and are excluded from the CRAN
  tarball. Suggests trimmed from 16 to 8 packages — removed `gimme`,
  `graphicalVAR`, `glasso`, `corpcor`, `data.table`, `qgraph`, `rio`, and
  `jsonlite`, none of which the shipped package uses.

# idiographic 0.2.0

* Made the CRAN package offline-first: the only mandatory imports are standard
  R packages, while `lme4`, `lavaan`, plotting, and external backends are
  optional. Competitor-oracle tests and the real-panel corpus now run in a
  separate opt-in `validation/` lane and are excluded from the CRAN tarball.
* Added a registry-backed `fit_idiographic()` front door, estimator discovery,
  method-specific `equivalence()` declarations, package-wide
  `equivalence_table()` and argument-by-argument `argument_coverage()` ledgers,
  and common tidy accessors. All 17 registered methods and 315 current public
  formals now have an executable evidence classification; new unassessed
  arguments fail the closure test.
* Expanded direct-oracle testing across graphicalVAR option combinations,
  mlVAR multi-lag/preprocessing/unique-model configurations, and bivariate plus
  three-variable GIMME standard, hybrid, and VAR searches. GIMME evidence now
  also covers fit statistics, uneven panels, exogenous-variable dimensions,
  and interacting correction/standardization controls. Tightened public argument
  validation so engine-specific controls cannot be silently ignored.
* Closed the remaining executable evidence cells: all 12 supported lag-1 lmer
  mlVAR structure combinations, per-subject/missing-data graphicalVAR fits,
  GIMME 10.0 correction/stopping/standardization/cutoff/forced-path controls,
  standardized ML/MLR uSEM fits, Mplus wrapper forwarding/conversion, Bayesian
  burn-in/thinning, positive random-residual recovery, parallel mlVAR, and
  base-R linear/logistic idiographic-ML engine equality.
* Migrated the 20-panel real ESM mlVAR validation corpus from the
  Dynalytics/psychaj work into the CRAN-excluded `validation/` lane, with
  self-contained raw inputs, mlVAR 0.7.3 frozen
  oracles, provenance hashes, and explicit regression coverage for missing IDs,
  irregular occasion gaps, and degenerate between-person networks. Duplicate
  observation keys now fail clearly instead of producing row-order-dependent
  preprocessing.

* **Uniform `fit_*` naming for all estimators (breaking).** Every model-fitting
  verb now uses a single `fit_` prefix: `fit_var()`,
  `fit_graphical_var()`, `fit_mlvar()`, `fit_rolling_var()`, and so on for all
  estimators. Short model nicknames passed to `compare_idiographic()`,
  `estimate_stability()`, and `validate_forecast()` (for example, `"var"` and
  `"graphical_var"`) are unchanged.
* New native Bayesian estimators that statistically reproduce Mplus DSEM output
  without requiring Mplus:
  * `fit_mlvar_bayes()` — two-level Bayesian VAR(1) with latent mean centring.
    `temporal = "fixed"` is statistically validated against frozen Mplus DSEM
    fixed-temporal + random-intercept fixtures;
    `temporal = "random"` fits the full DSEM with person-specific temporal
    matrices and a random-effect covariance (reports random-slope SDs).
  * `fit_var_bayes()` — single-level Bayesian VAR(1), the unregularized
    Bayesian analogue of `fit_graphical_var()`.
* Pure-R conjugate Gibbs sampler (hand-rolled inverse-Wishart draws; no new
  dependencies). Posterior median / SD / 95% CI / one-tailed p, three networks
  (temporal, contemporaneous, between), and a Gelman-Rubin PSR diagnostic.
* Validated to statistical (Monte-Carlo-error) equivalence against real Mplus 9
  output with frozen ground-truth fixtures and parity tests.
* Added `fit_ml()` for idiographic supervised machine-learning: ordered
  within-person train/test splits, person-specific models, pooled baselines on
  the same held-out rows, regression/classification metrics, row-level
  predictions, and coefficient extraction via `coefs()`. `model` names the
  statistical/ML model (for example, `"ridge"`), while `estimator`
  names the implementation/backend (default `"native"`). No new dependencies:
  native models include mean/majority baselines, OLS/logistic, ridge, lasso,
  elastic net, PCR, LDA, Gaussian naive Bayes, kNN, and one-split trees.
  `fit_idiographic_ml()` and `fit_individualized_ml()` remain aliases.

# idiographic 0.1.0

* Initial CRAN submission.
* Provides idiographic network estimators for intensive longitudinal data,
  including ordinary VAR, graphical VAR, mlVAR, uSEM, and GIMME-style models.
* Includes preprocessing audits, rolling-window estimation, forecast validation,
  edge stability diagnostics, model comparison, tidy accessors, and cograph
  plotting support.
