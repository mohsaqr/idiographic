# idiographic

<!-- badges: start -->
[![r-universe](https://mohsaqr.r-universe.dev/badges/idiographic)](https://mohsaqr.r-universe.dev/idiographic)
[![pkgdown](https://img.shields.io/badge/docs-pkgdown-blue.svg)](https://saqr.me/idiographic/)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
<!-- badges: end -->

> **Network estimation from intensive longitudinal data** — person-specific and
> within-person temporal, contemporaneous, and between-subject networks from
> ESM / EMA / diary panels, through one tidy verb per method.

`idiographic` estimates dynamic networks from intensive longitudinal data (ILD):
ordinary and regularized vector autoregression, multilevel VAR, native Bayesian
multilevel VAR that matches Mplus DSEM, unified SEM, and GIMME — plus the
supporting workflow (preprocessing audits, edge-stability diagnostics, rolling
windows, forecast validation, and model comparison). Every result is a tidy
object you access with the same handful of verbs: `edges()`, `nodes()`,
`coefs()`, `matrices()`, `summary()`, and `plot()`.

## Clean-room by design

**Every estimator is a clean-room reimplementation**, written from the published
algorithms rather than by wrapping another package — and each is validated for
numerical equivalence against its reference:

| Estimator | Method | Validated against | Agreement |
|---|---|---|---|
| `graphical_var()` | Regularized graphical VAR (graphical lasso + EBIC) | `graphicalVAR` | ~1e-10 |
| `build_mlvar()` | Two-step multilevel VAR (`lmer`, fixed effects) | `mlVAR` (`estimator = "lmer"`) | ~1e-10 (machine precision) |
| `build_mlvar_bayes()` | Native Bayesian multilevel VAR / **DSEM** | real **Mplus DSEM** + Stan/JAGS | Monte-Carlo error |
| `build_var_bayes()` | Native Bayesian VAR(1) | real **Mplus** `ESTIMATOR = BAYES` | ~1e-3 |
| `.glasso_fit()` (internal) | Graphical lasso | `glasso` (KKT-checked) | ~1e-11 |

Because the algorithms are native, the package's runtime footprint is minimal —
**Imports: `stats`, `utils`, `lme4`, `lavaan`** only. `mlVAR`, `graphicalVAR`,
`glasso`, and `MplusAutomation` are *Suggests* used solely to regenerate the
validation fixtures; they are **not needed to run any estimator**.

The Bayesian DSEM sampler is a particular highlight: `build_mlvar_bayes()`
reproduces the output of `mlVAR::mlVAR(estimator = "Mplus")` — Mplus's two-level
Bayesian VAR with latent mean centering — **without Mplus installed**, using a
pure-R conjugate Gibbs sampler with hand-rolled inverse-Wishart draws (no
`MCMCpack`/`rstan`). It was validated against real Mplus 9 output, an independent
Stan/JAGS implementation (Li et al., 2022), real openESM datasets, and the
published network findings of Bringmann et al. (2013).

## Installation

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

Plotting uses the [`cograph`](https://github.com/mohsaqr/snajs) package; it stays
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
fit <- build_mlvar(panel, vars = c("A", "B", "C"), id = "id", beep = "beep")

fit                 # tidy printout of all three networks
edges(fit)          # one row per edge (network, from, to, weight)
coefs(fit)          # fixed-effect estimates with SE / p / CI
plot(fit)           # draw all layers with cograph
plot(fit, layer = "temporal")
```

Everything is a **tidy verb with named arguments returning a tidy `data.frame`** —
you never index into a result object to reach a sub-network or a coefficient.

### Native Bayesian DSEM (no Mplus needed)

```r
bayes <- build_mlvar_bayes(panel, vars = c("A", "B", "C"),
                           id = "id", beep = "beep",
                           n_iter = 4000, n_chains = 2)
bayes               # posterior medians, SDs, 95% CIs, convergence (max PSR)
coefs(bayes)

## full DSEM with person-specific slopes, random residuals, and
## within-model imputation of missing observations (needs enough subjects to
## identify the random-effect covariance: at least 2 * (p + p^2) + 1):
build_mlvar_bayes(panel, vars = c("A", "B", "C"), id = "id", beep = "beep",
                  temporal = "random", residual = "random", impute = TRUE)
```

## What's included

**Estimators**

- `build_var()` / `build_var_each()` — ordinary VAR(1) (OLS), pooled or per subject
- `graphical_var()` / `graphical_var_each()` — regularized graphical VAR (GLASSO + EBIC)
- `build_mlvar()` — two-step multilevel VAR (temporal, contemporaneous, between)
- `build_mlvar_bayes()` — native Bayesian multilevel VAR / DSEM (fixed or random
  slopes, fixed or random residual covariance, optional within-model imputation)
- `build_var_bayes()` — native Bayesian VAR(1)
- `build_mlvar_mplus()` — true-Mplus backend (wraps `mlVAR(estimator = "Mplus")`)
- `build_usem()` — unified Structural Equation Modeling (lavaan)
- `build_gimme()` — Group Iterative Multiple Model Estimation

**Workflow & diagnostics**

- `audit_preprocess()` — preprocessing audit for ILD (compliance, variance, stationarity)
- `estimate_stability()` — bootstrap edge-stability diagnostics
- `rolling_var()` / `rolling_graphical_var()` — rolling-window (time-varying) networks
- `validate_forecast()` — rolling out-of-sample forecast validation
- `compare_idiographic()` — model-comparison reports

**Tidy accessors (work on every result)**

`edges()` · `nodes()` · `coefs()` · `matrices()` · `summary()` · `print()` ·
`plot()` / `plot_gimme()` · `as_netobject()`

## Bundled data

- `srl` — a self-regulated-learning ESM dataset (`data(srl)`)
- `inst/extdata/esm_demo.tsv` — a small synthetic demo panel

## Documentation

Full function reference and articles: **<https://saqr.me/idiographic/>**.

## Citation

Saqr, M. (2026). *idiographic: Network Estimation from Intensive Longitudinal
Data*. R package. <https://github.com/mohsaqr/idiographic>

## License

GPL-3.
