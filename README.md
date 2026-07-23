# idiographic

<!-- badges: start -->
[![r-universe](https://mohsaqr.r-universe.dev/badges/idiographic)](https://mohsaqr.r-universe.dev/idiographic)
[![r-universe docs](https://img.shields.io/badge/docs-r--universe-blue.svg)](https://mohsaqr.r-universe.dev/idiographic)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
<!-- badges: end -->

> **Network estimation from intensive longitudinal data** — person-specific and
> within-person temporal, contemporaneous, and between-subject networks from
> ESM / EMA / diary panels, through one tidy verb per method.

`idiographic` estimates dynamic networks from intensive longitudinal data (ILD):
ordinary and regularized vector autoregression, multilevel VAR, native Bayesian
multilevel VAR validated against selected Mplus DSEM fixtures, unified SEM, and
GIMME — plus the
supporting workflow (preprocessing audits, edge-stability diagnostics, rolling
windows, forecast validation, model comparison, and idiographic supervised
machine-learning models for individualized prediction). Every result has tidy
`as.data.frame()` and `summary()` views. Network estimates additionally share
`edges()`, `nodes()`, `coefs()`, `matrices()`, `plot()`, and `as_netobject()`.

## Clean-room by design

The core estimators are native R implementations of the published modelling
targets, with a consistent interface and validation against reference outputs
where a reference implementation is available:

| Estimator | Method | Validated against | Agreement |
|---|---|---|---|
| `fit_graphical_var()` | Regularized graphical VAR (graphical lasso + EBIC) | `graphicalVAR` | committed tolerance 1e-6 across the supported lag-1 beta/kappa option matrix |
| `fit_mlvar()` | Multilevel and person-specific VAR | `mlVAR` 0.7.3 | committed tolerance 1e-8 across 20 real ESM panels plus fixed `lmer` lag 1/1+2, preprocessing, and lag-1 `lm`/unique oracle slices |
| `fit_gimme()` | Group and individual uSEM path search | `gimme` 10.0 | exact search/matrix agreement on bivariate and three-variable standard/hybrid/VAR panels, including exogenous and uneven-panel structures; fit tables within 5e-5 |
| `fit_mlvar_bayes()` | Native Bayesian multilevel VAR / **DSEM** | real **Mplus DSEM** + Stan/JAGS | Monte-Carlo error |
| `fit_var_bayes()` | Native Bayesian VAR(1) | real **Mplus** `ESTIMATOR = BAYES` | committed statistical bounds 0.02-0.03 |

The CRAN package is offline-first: its only imports are the standard R packages
`stats`, `utils`, and `parallel`, which ship with R. It has **no mandatory
third-party package dependency**. `lme4` and `lavaan` are optional engines for
multilevel frequentist VAR and SEM/GIMME respectively; plotting and the licensed
Mplus bridge are optional too. Competitor packages and the 20-panel oracle
corpus live in the repository's separate `validation/` lane and are not shipped
in the CRAN tarball.

The Bayesian DSEM sampler is a particular highlight: `fit_mlvar_bayes()`
targets the output of `mlVAR::mlVAR(estimator = "Mplus")` — Mplus's two-level
Bayesian VAR with latent mean centring — **without Mplus installed**, using a
pure-R conjugate Gibbs sampler with hand-rolled inverse-Wishart draws (no
`MCMCpack`/`rstan`). The committed evidence consists of fixed bivariate Mplus
fixtures, one univariate random-AR fixture, and parameter-recovery tests; use
`equivalence(fit)` to inspect the precise scope rather than assuming blanket
DSEM equivalence.

## Installation

The core can be installed from a downloaded source tarball without network
access; optional engines are only checked when their corresponding methods are
called.

From CRAN:

```r
install.packages("idiographic")
```

From the author's r-universe (recommended — no compilation, binaries included):

```r
install.packages("idiographic",
                 repos = c("https://mohsaqr.r-universe.dev",
                           "https://cloud.r-project.org"))
```

Or from GitHub:

```r
# install.packages("pak")
pak::pak("mohsaqr/idiographic")
```

Plotting uses the [`cograph`](https://github.com/mohsaqr/cograph) package; it stays
optional and is offered for on-demand install the first time you call `plot()`.

## Quick start

```r
library(idiographic)

## simulate an ESM panel: 30 people, 40 beeps, 3 items
set.seed(1)
panel <- do.call(rbind, lapply(1:30, function(id) {
  y <- matrix(0, 40, 3)
  for (t in 2:40) y[t, ] <- c(0.35, 0.30, 0.25) * y[t - 1, ] + rnorm(3)
  data.frame(id = id, beep = 1:40, A = y[, 1], B = y[, 2], C = y[, 3])
}))

## multilevel VAR: temporal, contemporaneous, and between networks
fit <- fit_mlvar(panel, vars = c("A", "B", "C"), id = "id", beep = "beep")

fit                 # tidy printout of all three networks
edges(fit)          # one row per edge (network, from, to, weight)
coefs(fit)          # fixed-effect estimates with SE / p / CI
plot(fit)           # draw all layers with cograph
plot(fit, layer = "temporal")

## the same call through the registry-driven front door
fit2 <- fit_idiographic(
  panel, method = "mlvar",
  params = list(vars = c("A", "B", "C"), id = "id", beep = "beep")
)
equivalence(fit2)  # exact validation scope and tolerance declaration

## inspect the complete package and argument-by-argument evidence ledgers
equivalence_table()
argument_coverage("mlvar")
```

All fitting functions use named, readable arguments. `list_estimators()`,
`estimator_info()`, and `get_estimator()` expose the registry; custom methods
can be added with `register_estimator()`. `equivalence_table()` reports the
package-wide evidence status, while `argument_coverage()` guarantees every
current public formal is classified as oracle/engine/statistical/internal,
delegated, extension, or an explicit rejection boundary.

Together these ledgers provide complete package-wide evidence closure: there
are no unassessed registered methods or arguments. Numerical equivalence remains
method- and configuration-specific rather than a blanket package claim.

### Native Bayesian DSEM (no Mplus needed)

```r
bayes <- fit_mlvar_bayes(panel, vars = c("A", "B", "C"),
                           id = "id", beep = "beep",
                           n_iter = 4000, n_chains = 2)
bayes               # posterior medians, SDs, 95% CIs, convergence (max PSR)
coefs(bayes)

## full DSEM with person-specific slopes, random residuals, and
## within-model imputation of missing observations (needs enough subjects to
## identify the random-effect covariance: at least 2 * (p + p^2) + 1):
fit_mlvar_bayes(panel, vars = c("A", "B", "C"), id = "id", beep = "beep",
                  temporal = "random", residual = "random", impute = TRUE)
```

## What's included

**Estimators**

- `fit_var()` / `fit_var_each()` — ordinary VAR(1) (OLS), pooled or per subject
- `fit_graphical_var()` / `fit_graphical_var_each()` — regularized graphical VAR
  (GLASSO + EBIC), including explicit multi-lag layers
- `fit_mlvar()` — frequentist multilevel VAR with fixed, correlated,
  orthogonal, or unique person-specific temporal/contemporaneous structures
- `fit_mlvar_bayes()` — native Bayesian multilevel VAR / DSEM (fixed or random
  slopes, fixed or random residual covariance, optional within-model imputation)
- `fit_var_bayes()` — native Bayesian VAR(1)
- `fit_mlvar_mplus()` — true-Mplus backend (wraps `mlVAR(estimator = "Mplus")`)
- `fit_usem()` — unified Structural Equation Modeling (lavaan)
- `fit_gimme()` — Group Iterative Multiple Model Estimation with explicit
  Bonferroni/FDR corrections, alpha, and stopping criteria
- `fit_ml()` — individualized supervised prediction models, comparing
  person-specific models against a pooled baseline on held-out within-person
  rows, with no new dependencies

**Workflow & diagnostics**

- `preprocess()` — preprocessing audit for ILD (compliance, variance, stationarity)
- `estimate_stability()` — bootstrap edge-stability diagnostics (*experimental*)
- `fit_rolling_var()` / `fit_rolling_graphical_var()` — rolling-window (time-varying) networks
- `validate_forecast()` — rolling out-of-sample forecast validation (*experimental*)
- `compare_idiographic()` — model-comparison reports

**Tidy contract**

Every result: `as.data.frame()` · `summary()` · `print()`

Network results: `edges()` · `nodes()` · `coefs()` · `matrices()` · `plot()` /
`plot_gimme()` · `as_netobject()`

### Idiographic machine learning

```r
ml <- fit_ml(
  panel,
  outcome = "A",
  predictors = c("B", "C"),
  id = "id",
  beep = "beep",
  compare = "both",
  model = c("linear", "ridge", "knn")
)

ml                 # per-person and pooled held-out performance
ml$metrics         # MAE / RMSE / bias / R-squared by subject and overall
coefs(ml)          # coefficients for each individualized and pooled model
ml$predictions     # row-level held-out predictions
```

Use `model = "all"` to run all native models for the selected task. For
regression this includes mean baseline, OLS (`linear`), ridge,
lasso, elastic net, PCR, kNN, and a one-split tree. For binary classification
this includes majority baseline, logistic regression, ridge/lasso/elastic-net
logistic, LDA, Gaussian naive Bayes, kNN, and a one-split tree. Use
`estimator = "native"` explicitly only when you want to pin the implementation;
future package backends should live behind the same model name.

## Bundled data

- `srl` — a self-regulated-learning ESM dataset (`data(srl)`)
- `inst/extdata/esm_demo.tsv` — a small synthetic demo panel

## Documentation

Package page and binaries: **<https://mohsaqr.r-universe.dev/idiographic>**.

## Citation

Saqr, M., & López-Pernas, S. (2026). *idiographic: Person-Specific
(Idiographic) and Heterogeneous Complex Networks*. R package.
<https://github.com/mohsaqr/idiographic>

## License

GPL-3.
