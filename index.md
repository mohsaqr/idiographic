# idiographic

> **Person-specific statistics and dynamic networks for intensive
> longitudinal data** — from raw repeated observations to within-person
> conclusions.

`idiographic` describes, prepares, models, validates, compares, and
explains person-specific processes in ESM, EMA, diary, and other panel
data. It combines person-level descriptions, LM/GLM and machine-learning
prediction, within-between decomposition, coefficient pooling and
shrinkage, subgroup discovery, treatment effects, and heterogeneity
analysis with the package’s established VAR, graphical VAR, mlVAR,
Bayesian DSEM, uSEM, and GIMME methods.

People and time order are first-class throughout: lags and validation
splits do not cross person boundaries, future observations are kept out
of training, and within-person quantities are not silently substituted
for between-person ones. Pooled and subgroup models are available for
comparison and stabilization of individual results.

## Clean-room by design

The core estimators are native R implementations of the published
modelling targets, with a consistent interface and validation against
reference outputs where a reference implementation is available:

| Estimator | Method | Validated against | Agreement |
|----|----|----|----|
| [`fit_graphical_var()`](https://pak.dynasite.org/idiographic/reference/fit_graphical_var.md) | Regularized graphical VAR (graphical lasso + EBIC) | `graphicalVAR` | committed tolerance 1e-6 across the supported lag-1 beta/kappa option matrix |
| [`fit_mlvar()`](https://pak.dynasite.org/idiographic/reference/fit_mlvar.md) | Multilevel and person-specific VAR | `mlVAR` 0.7.3 | committed tolerance 1e-8 across 20 real ESM panels plus fixed `lmer` lag 1/1+2, preprocessing, and lag-1 `lm`/unique oracle slices |
| [`fit_gimme()`](https://pak.dynasite.org/idiographic/reference/fit_gimme.md) | Group and individual uSEM path search | `gimme` 10.0 | exact search/matrix agreement on bivariate and three-variable standard/hybrid/VAR panels, including exogenous and uneven-panel structures; fit tables within 5e-5 |
| [`fit_mlvar_bayes()`](https://pak.dynasite.org/idiographic/reference/fit_mlvar_bayes.md) | Native Bayesian multilevel VAR / **DSEM** | real **Mplus DSEM** + Stan/JAGS | Monte-Carlo error |
| [`fit_var_bayes()`](https://pak.dynasite.org/idiographic/reference/fit_var_bayes.md) | Native Bayesian VAR(1) | real **Mplus** `ESTIMATOR = BAYES` | committed statistical bounds 0.02-0.03 |

The CRAN package is offline-first: its imports are standard R packages
that ship with R. It has **no mandatory third-party package
dependency**. `lme4` and `lavaan` are optional engines for multilevel
frequentist VAR and SEM/GIMME respectively; plotting and the licensed
Mplus bridge are optional too. Competitor packages and the 20-panel
oracle corpus live in the repository’s separate `validation/` lane and
are not shipped in the CRAN tarball.

The Bayesian DSEM sampler is a particular highlight:
[`fit_mlvar_bayes()`](https://pak.dynasite.org/idiographic/reference/fit_mlvar_bayes.md)
targets the output of `mlVAR::mlVAR(estimator = "Mplus")` — Mplus’s
two-level Bayesian VAR with latent mean centring — **without Mplus
installed**, using a pure-R conjugate Gibbs sampler with hand-rolled
inverse-Wishart draws (no `MCMCpack`/`rstan`). The committed evidence
consists of fixed bivariate Mplus fixtures, one univariate random-AR
fixture, and parameter-recovery tests; use `equivalence(fit)` to inspect
the precise scope rather than assuming blanket DSEM equivalence.

## Installation

The core can be installed from a downloaded source tarball without
network access; optional engines are only checked when their
corresponding methods are called.

From CRAN:

``` r

install.packages("idiographic")
```

From the author’s r-universe (recommended — no compilation, binaries
included):

``` r

install.packages("idiographic",
                 repos = c("https://mohsaqr.r-universe.dev",
                           "https://cloud.r-project.org"))
```

Or from GitHub:

``` r

# install.packages("pak")
pak::pak("mohsaqr/idiographic")
```

Plotting uses the [`cograph`](https://github.com/mohsaqr/cograph)
package; it stays optional and is offered for on-demand install the
first time you call
[`plot()`](https://rdrr.io/r/graphics/plot.default.html).

## Quick start: one idiographic workflow

``` r

library(idiographic)

## simulate an ESM panel: 30 people, 40 occasions, 3 predictors
set.seed(1)
panel <- do.call(rbind, lapply(1:30, function(id) {
  x <- matrix(rnorm(120), 40, 3)
  data.frame(id = id, time = 1:40, A = x[, 1], B = x[, 2], C = x[, 3])
}))
panel$Y <- 0.7 * panel$A - 0.3 * panel$B +
  rep(rnorm(30, sd = 0.5), each = 40) + rnorm(nrow(panel), sd = 0.4)

## 1. inspect variation and dependence person by person
describe_persons(panel, id = "id", vars = c("A", "B", "Y"), time = "time")
correlate_persons(panel, id = "id", vars = c("A", "B", "Y"))
variance_components(panel, id = "id", vars = c("A", "B", "Y"))

## 2. prepare within-person predictors and honest lags
prepared <- preprocess_panel(
  panel, id = "id", time = "time", vars = c("A", "B"),
  decompose = TRUE, lag = 1
)

## 3. compare pooled and person-specific regression on later observations
reg <- fit_lm(prepared, y = "Y", x = c("A", "B"), id = "id",
              time = "time", scope = "both")
metrics(reg, overall = TRUE)
coefs(reg, scope = "individual")

## 4. separate within-person and between-person effects directly
wb <- fit_within_between(panel, y = "Y", x = c("A", "B"), id = "id",
                         time = "time")
contextual(wb)

## 5. stabilize noisy individual coefficients
pool_coefs(reg)
shrink_coefs(reg)

## 6. fit and tune scoped machine-learning models
ml <- fit_ml(panel, y = "Y", x = c("A", "B", "C"), id = "id",
             time = "time", scope = "both",
             model = c("ridge", "knn"), tune = TRUE)
best_model(ml)
predictions(ml, scope = "individual")
```

## Dynamic-network workflow

The statistical workflow and network estimators live in the same package
and operate on the same person-by-time panels.

``` r

## multilevel VAR: temporal, contemporaneous, and between networks
net <- fit_mlvar(panel, vars = c("A", "B", "C"),
                 id = "id", beep = "time")

net                 # tidy printout of all three networks
edges(net)          # one row per edge (network, from, to, weight)
coefs(net)          # fixed-effect estimates with SE / p / CI
plot(net, layer = "temporal")

## the same call through the registry-driven front door
fit2 <- fit_idiographic(
  panel, method = "mlvar",
  params = list(vars = c("A", "B", "C"), id = "id", beep = "time")
)
equivalence(fit2)  # exact validation scope and tolerance declaration

## inspect the complete package and argument-by-argument evidence ledgers
equivalence_table()
argument_coverage("mlvar")
```

All fitting functions use named, readable arguments.
[`list_estimators()`](https://pak.dynasite.org/idiographic/reference/list_estimators.md),
[`estimator_info()`](https://pak.dynasite.org/idiographic/reference/estimator_info.md),
and
[`get_estimator()`](https://pak.dynasite.org/idiographic/reference/get_estimator.md)
expose the dynamic-network and legacy ML registry; custom methods can be
added with
[`register_estimator()`](https://pak.dynasite.org/idiographic/reference/register_estimator.md).
[`models()`](https://pak.dynasite.org/idiographic/reference/models.md)
is the separate algorithm/backend registry used by the consolidated ML
engine. Classical scoped fitters
([`fit_lm()`](https://pak.dynasite.org/idiographic/reference/fit_lm.md),
[`fit_glm()`](https://pak.dynasite.org/idiographic/reference/fit_glm.md),
effects, within-between, and subgroup methods) remain explicit verbs
because their results and inferential contracts are not interchangeable
with network estimators.
[`equivalence_table()`](https://pak.dynasite.org/idiographic/reference/equivalence_table.md)
and
[`argument_coverage()`](https://pak.dynasite.org/idiographic/reference/argument_coverage.md)
report evidence for the methods in the dynamic estimator registry.

Together these ledgers provide complete evidence closure for registered
methods: there are no unassessed registered methods or arguments.
Numerical equivalence remains method- and configuration-specific rather
than a blanket package claim.

### Native Bayesian DSEM (no Mplus needed)

``` r

bayes <- fit_mlvar_bayes(panel, vars = c("A", "B", "C"),
                         id = "id", beep = "time",
                         n_iter = 4000, n_chains = 2)
bayes               # posterior medians, SDs, 95% CIs, convergence (max PSR)
coefs(bayes)

## full DSEM with person-specific slopes, random residuals, and
## within-model imputation of missing observations (needs enough subjects to
## identify the random-effect covariance: at least 2 * (p + p^2) + 1):
fit_mlvar_bayes(panel, vars = c("A", "B", "C"), id = "id", beep = "time",
                temporal = "random", residual = "random", impute = TRUE)
```

## What’s included

**Descriptions, regression, and explanation**

- [`describe_persons()`](https://pak.dynasite.org/idiographic/reference/describe_persons.md)
  /
  [`correlate_persons()`](https://pak.dynasite.org/idiographic/reference/correlate_persons.md)
  /
  [`variance_components()`](https://pak.dynasite.org/idiographic/reference/variance_components.md)
  — person-level distributions, dependence, and variance allocation
- [`fit_lm()`](https://pak.dynasite.org/idiographic/reference/fit_lm.md)
  /
  [`fit_glm()`](https://pak.dynasite.org/idiographic/reference/fit_glm.md)
  — pooled, subgroup, and person-specific models
- [`fit_ml()`](https://pak.dynasite.org/idiographic/reference/fit_ml.md)
  — native and optional-backend machine learning with ordered hold-out
  validation and tuning
- [`fit_rolling()`](https://pak.dynasite.org/idiographic/reference/fit_rolling.md)
  — rolling-origin validation for LM, GLM, and ML
- [`fit_within_between()`](https://pak.dynasite.org/idiographic/reference/fit_within_between.md)
  /
  [`contextual()`](https://pak.dynasite.org/idiographic/reference/contextual.md)
  — explicit within-person and between-person effects
- [`pool_coefs()`](https://pak.dynasite.org/idiographic/reference/pool_coefs.md)
  /
  [`shrink_coefs()`](https://pak.dynasite.org/idiographic/reference/shrink_coefs.md)
  — heterogeneity-aware pooling and empirical Bayes stabilization
- [`test_subgroups()`](https://pak.dynasite.org/idiographic/reference/test_subgroups.md)
  /
  [`find_subgroups()`](https://pak.dynasite.org/idiographic/reference/find_subgroups.md)
  /
  [`fit_subgroups()`](https://pak.dynasite.org/idiographic/reference/fit_subgroups.md)
  — subgroup existence, discovery, and modelling
- [`fit_effects()`](https://pak.dynasite.org/idiographic/reference/fit_effects.md)
  /
  [`fit_heterogeneity()`](https://pak.dynasite.org/idiographic/reference/fit_heterogeneity.md)
  — treatment effects and general heterogeneity analysis

**Dynamic-network estimators**

- [`fit_var()`](https://pak.dynasite.org/idiographic/reference/fit_var.md)
  /
  [`fit_var_each()`](https://pak.dynasite.org/idiographic/reference/fit_var_each.md)
  — ordinary VAR(1) (OLS), pooled or per subject
- [`fit_graphical_var()`](https://pak.dynasite.org/idiographic/reference/fit_graphical_var.md)
  /
  [`fit_graphical_var_each()`](https://pak.dynasite.org/idiographic/reference/fit_graphical_var_each.md)
  — regularized graphical VAR (GLASSO + EBIC), including explicit
  multi-lag layers
- [`fit_mlvar()`](https://pak.dynasite.org/idiographic/reference/fit_mlvar.md)
  — frequentist multilevel VAR with fixed, correlated, orthogonal, or
  unique person-specific temporal/contemporaneous structures
- [`fit_mlvar_bayes()`](https://pak.dynasite.org/idiographic/reference/fit_mlvar_bayes.md)
  — native Bayesian multilevel VAR / DSEM (fixed or random slopes, fixed
  or random residual covariance, optional within-model imputation)
- [`fit_var_bayes()`](https://pak.dynasite.org/idiographic/reference/fit_var_bayes.md)
  — native Bayesian VAR(1)
- [`fit_mlvar_mplus()`](https://pak.dynasite.org/idiographic/reference/fit_mlvar_mplus.md)
  — true-Mplus backend (wraps `mlVAR(estimator = "Mplus")`)
- [`fit_usem()`](https://pak.dynasite.org/idiographic/reference/fit_usem.md)
  — unified Structural Equation Modeling (lavaan)
- [`fit_gimme()`](https://pak.dynasite.org/idiographic/reference/fit_gimme.md)
  — Group Iterative Multiple Model Estimation with explicit
  Bonferroni/FDR corrections, alpha, and stopping criteria

**Workflow & diagnostics**

- [`preprocess()`](https://pak.dynasite.org/idiographic/reference/preprocess.md)
  — network-oriented ILD audit (compliance, variance, stationarity)
- [`preprocess_panel()`](https://pak.dynasite.org/idiographic/reference/preprocess_panel.md)
  — centring, scaling, detrending, decomposition, and within-person lag
  construction
- [`estimate_stability()`](https://pak.dynasite.org/idiographic/reference/estimate_stability.md)
  — bootstrap edge-stability diagnostics (*experimental*)
- [`fit_rolling_var()`](https://pak.dynasite.org/idiographic/reference/fit_rolling_var.md)
  /
  [`fit_rolling_graphical_var()`](https://pak.dynasite.org/idiographic/reference/fit_rolling_graphical_var.md)
  — rolling-window (time-varying) networks
- [`validate_forecast()`](https://pak.dynasite.org/idiographic/reference/validate_forecast.md)
  — rolling out-of-sample forecast validation (*experimental*)
- [`compare_idiographic()`](https://pak.dynasite.org/idiographic/reference/compare_idiographic.md)
  — model-comparison reports

**Tidy contract**

Scoped statistical results:
[`metrics()`](https://pak.dynasite.org/idiographic/reference/metrics.md)
·
[`predictions()`](https://pak.dynasite.org/idiographic/reference/predictions.md)
· [`coefs()`](https://pak.dynasite.org/idiographic/reference/coefs.md) ·
[`diagnostics()`](https://pak.dynasite.org/idiographic/reference/diagnostics.md)
·
[`importance()`](https://pak.dynasite.org/idiographic/reference/importance.md)
· [`tuning()`](https://pak.dynasite.org/idiographic/reference/tuning.md)
· [`person()`](https://pak.dynasite.org/idiographic/reference/person.md)
·
[`individuals()`](https://pak.dynasite.org/idiographic/reference/individuals.md)
· [`pooled()`](https://pak.dynasite.org/idiographic/reference/pooled.md)
·
[`subgroups()`](https://pak.dynasite.org/idiographic/reference/subgroups.md)
·
[`overall()`](https://pak.dynasite.org/idiographic/reference/overall.md)

Every result:
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) ·
[`summary()`](https://rdrr.io/r/base/summary.html) ·
[`print()`](https://rdrr.io/r/base/print.html) where meaningful

Network results:
[`edges()`](https://pak.dynasite.org/idiographic/reference/edges.md) ·
[`nodes()`](https://pak.dynasite.org/idiographic/reference/nodes.md) ·
[`coefs()`](https://pak.dynasite.org/idiographic/reference/coefs.md) ·
[`matrices()`](https://pak.dynasite.org/idiographic/reference/matrices.md)
· [`plot()`](https://rdrr.io/r/graphics/plot.default.html) /
[`plot_gimme()`](https://pak.dynasite.org/idiographic/reference/plot_gimme.md)
·
[`as_netobject()`](https://pak.dynasite.org/idiographic/reference/as_netobject.md)

### Idiographic machine learning

``` r

ml <- fit_ml(
  panel,
  y = "Y",
  x = c("A", "B", "C"),
  id = "id",
  time = "time",
  scope = "both",
  model = c("linear", "ridge", "knn"),
  tune = TRUE
)

ml                 # per-person and pooled held-out performance
metrics(ml)        # MAE / RMSE / bias / R-squared by subject and overall
coefs(ml)          # coefficients for each individualized and pooled model
predictions(ml)    # row-level held-out predictions
```

Use `model = "all"` to run all native models for the selected task. For
regression this includes mean baseline, OLS (`linear`), ridge, lasso,
elastic net, PCR, kNN, and a one-split tree. For binary classification
this includes majority baseline, logistic regression,
ridge/lasso/elastic-net logistic, LDA, Gaussian naive Bayes, kNN, and a
one-split tree. Use `estimator = "native"` explicitly only when you want
to pin the implementation; optional package backends live behind the
same model name. Historical calls using `outcome`, `predictors`, `day`,
and `beep` remain supported.

## Migrating from idiostats

Use [`library(idiographic)`](https://pak.dynasite.org/idiographic/) in
place of [`library(idiostats)`](https://rdrr.io/r/base/library.html).
Almost all public analysis verbs retain their names. Two collision
bridges are explicit:

- Use
  [`preprocess_panel()`](https://pak.dynasite.org/idiographic/reference/preprocess_panel.md)
  for the former `idiostats::preprocess()` transforms;
  [`preprocess()`](https://pak.dynasite.org/idiographic/reference/preprocess.md)
  remains the established network-readiness audit.
- Named `fit_ml(y = ..., x = ...)` calls use the consolidated scoped
  engine. Use `fit_ml_panel(data, y, x, id, ...)` when retaining the
  former positional calling style. Positional
  `fit_ml(data, outcome, predictors, id)` remains the historical
  `idiographic` interface for backward compatibility.

Consolidated results report `idiographic_*` as their primary class and
retain the former `idiostats_*` class as a compatibility bridge.

## Bundled data

- `srl` — a self-regulated-learning ESM dataset (`data(srl)`)
- `inst/extdata/esm_demo.tsv` — a small synthetic demo panel

## Documentation

Package page and binaries:
**<https://mohsaqr.r-universe.dev/idiographic>**.

Start with the [statistical workflow
guide](https://pak.dynasite.org/idiographic/vignettes/statistical-workflows.Rmd),
which maps research questions to the 16 major non-network functions.
Each function then has a detailed worked vignette:

| Analysis | Function-specific vignette |
|----|----|
| Person-level description | [`describe_persons()`](https://pak.dynasite.org/idiographic/vignettes/describe-persons.Rmd) |
| Within-person correlation | [`correlate_persons()`](https://pak.dynasite.org/idiographic/vignettes/correlate-persons.Rmd) |
| Variance decomposition | [`variance_components()`](https://pak.dynasite.org/idiographic/vignettes/variance-components.Rmd) |
| Panel preparation | [`preprocess_panel()`](https://pak.dynasite.org/idiographic/vignettes/preprocess-panel.Rmd) |
| Linear modelling | [`fit_lm()`](https://pak.dynasite.org/idiographic/vignettes/fit-lm.Rmd) |
| Generalized linear modelling | [`fit_glm()`](https://pak.dynasite.org/idiographic/vignettes/fit-glm.Rmd) |
| Machine learning | [`fit_ml()`](https://pak.dynasite.org/idiographic/vignettes/fit-ml.Rmd) |
| Rolling-origin validation | [`fit_rolling()`](https://pak.dynasite.org/idiographic/vignettes/fit-rolling.Rmd) |
| Within-between modelling | [`fit_within_between()`](https://pak.dynasite.org/idiographic/vignettes/fit-within-between.Rmd) |
| Coefficient pooling | [`pool_coefs()`](https://pak.dynasite.org/idiographic/vignettes/pool-coefs.Rmd) |
| Coefficient shrinkage | [`shrink_coefs()`](https://pak.dynasite.org/idiographic/vignettes/shrink-coefs.Rmd) |
| Subgroup-existence testing | [`test_subgroups()`](https://pak.dynasite.org/idiographic/vignettes/test-subgroups.Rmd) |
| Subgroup discovery | [`find_subgroups()`](https://pak.dynasite.org/idiographic/vignettes/find-subgroups.Rmd) |
| Subgroup modelling | [`fit_subgroups()`](https://pak.dynasite.org/idiographic/vignettes/fit-subgroups.Rmd) |
| Treatment-effect estimation | [`fit_effects()`](https://pak.dynasite.org/idiographic/vignettes/fit-effects.Rmd) |
| General heterogeneity analysis | [`fit_heterogeneity()`](https://pak.dynasite.org/idiographic/vignettes/fit-heterogeneity.Rmd) |

## Citation

Saqr, M., & López-Pernas, S. (2026). *idiographic: Person-Specific
Statistics and Heterogeneous Dynamic Networks*. R package.
<https://github.com/mohsaqr/idiographic>

## License

GPL-3.
