# idiographic

<!-- badges: start -->
[![r-universe](https://mohsaqr.r-universe.dev/badges/idiographic)](https://mohsaqr.r-universe.dev/idiographic)
[![r-universe docs](https://img.shields.io/badge/docs-r--universe-blue.svg)](https://mohsaqr.r-universe.dev/idiographic)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
<!-- badges: end -->

Idiographic analysis studies one person at a time. Each person contributes a
time series of repeated observations, and a model fitted to that series
estimates the effects within that person, for example how a learner's effort
on a day depends on the learner's self-efficacy on that day. Nomothetic
analysis estimates effects averaged over a population of persons. The average
describes an individual only when all persons share the same process.
Intensive longitudinal data, such as experience sampling (ESM), ecological
momentary assessment (EMA) and daily diaries, contain enough observations per
person to estimate the process of each person and to examine this assumption.

The package covers two families of idiographic methods. Person-specific
statistical models describe the series of each person, regress an outcome on
predictors within each person, predict later observations from earlier ones,
and separate within-person from between-person effects. Dynamic network models
estimate the temporal and contemporaneous relations among several variables,
for one person, for each person in a sample, or for the average person in a
multilevel model. In both families the person-specific estimates are compared
with a pooled model of all persons and with models of subgroups of persons.

## Installation

The released version is on CRAN.

```r
install.packages("idiographic")
```

The development version contains the person-specific statistical models. It
is available as a binary from the r-universe of the author and as source from
GitHub.

```r
install.packages("idiographic",
                 repos = c("https://mohsaqr.r-universe.dev",
                           "https://cloud.r-project.org"))

pak::pak("mohsaqr/idiographic")
```

## Data

The examples use `srl`, a data frame in long format with one row per student
and day. Thirty-six students rated nine indicators of self-regulated learning,
among them self-efficacy, planning, monitoring and effort, on each of 156 days.
The column `name` identifies the student and `day` orders the observations.
The package also contains `esm_srl`, momentary ratings from 41 students with
several occasions per day, and `submissions`, a simulated daily binary outcome
for 40 learners of two latent types.

## Person-specific models

A person-specific regression fits one model to the series of each person, and
a pooled regression fits one model to the observations of all persons. With
`scope = "both"`, `fit_lm()` estimates both, and `metrics()` reports their
prediction error on the last observations of each person, which are held out
from estimation.

```r
library(idiographic)

fit <- fit_lm(srl, y = "effort", x = "efficacy", id = "name", time = "day",
              scope = "both")
metrics(fit, overall = TRUE)
coefs(fit, scope = "individual")
```

A coefficient estimated from a short or noisy series is uncertain.
Empirical-Bayes shrinkage moves each person's coefficient toward the pooled
coefficient, and it moves an uncertain coefficient further than a precise one.

```r
shrink_coefs(fit, term = "efficacy")
```

A predictor varies within persons, from day to day around the mean of the
person, and between persons, in the means themselves. The within-person effect
and the between-person effect are estimated in one model, and their difference
is the contextual effect.

```r
wb <- fit_within_between(srl, y = "effort", x = "efficacy", id = "name",
                         time = "day")
contextual(wb)
```

Prediction models from machine learning are evaluated in the same way, on
observations later than those used for estimation, and `fit_rolling()` repeats
the evaluation at successive time points.

```r
ml <- fit_ml(srl, y = "effort", x = c("efficacy", "planning", "monitoring"),
             id = "name", time = "day", scope = "both",
             model = c("ridge", "knn"), tune = TRUE)
metrics(ml, overall = TRUE)
```

## Dynamic networks

A dynamic network of several variables has two layers. A temporal edge from
one variable to another is the effect of the first variable on one occasion on
the second variable on the next occasion. A contemporaneous edge is the partial
correlation of two variables on the same occasion after the temporal effects
are removed. The multilevel vector autoregression (mlVAR) estimates both layers
for the average person, together with a between-person network of the person
means.

```r
net <- fit_mlvar(srl, vars = c("efficacy", "planning", "monitoring", "effort"),
                 id = "name", beep = "day")
net
edges(net)
plot(net, layer = "temporal")
```

## Functions

| Task | Functions |
|---|---|
| Description of each person | `describe_persons()`, `correlate_persons()`, `variance_components()` |
| Preparation of the panel | `preprocess_panel()`, `split_levels()`, `preprocess()` |
| Regression | `fit_lm()`, `fit_glm()` |
| Within-person and between-person effects | `fit_within_between()`, `contextual()`, `correlate_levels()` |
| Prediction and temporal validation | `fit_ml()`, `fit_rolling()`, `compare_predictions()` |
| Pooling and shrinkage | `pool_coefs()`, `shrink_coefs()` |
| Subgroups of persons | `test_subgroups()`, `find_subgroups()`, `fit_subgroups()` |
| Treatment effects and heterogeneity | `fit_effects()`, `fit_heterogeneity()` |
| Vector autoregression for one person or each person | `fit_var()`, `fit_var_each()`, `fit_graphical_var()`, `fit_graphical_var_each()` |
| Multilevel vector autoregression | `fit_mlvar()`, `fit_mlvar_mplus()` |
| Bayesian vector autoregression and DSEM | `fit_var_bayes()`, `fit_mlvar_bayes()` |
| Structural equation models of the series | `fit_usem()`, `fit_gimme()` |
| Time-varying networks | `fit_rolling_var()`, `fit_rolling_graphical_var()` |
| Stability and forecast validation | `estimate_stability()`, `validate_forecast()`, `compare_idiographic()` |

Each result is returned as a data frame by `as.data.frame()`. The accessors
`metrics()`, `predictions()`, `coefs()`, `importance()` and `diagnostics()`
return the parts of a statistical model, and `edges()`, `nodes()` and
`matrices()` the parts of a network.

## Validation

The estimators are implemented in R and are tested against reference
implementations. The table lists the reference for each estimator and the
largest difference allowed in the tests.

| Estimator | Method | Reference | Agreement |
|---|---|---|---|
| `fit_graphical_var()` | Graphical VAR with graphical lasso and EBIC | `graphicalVAR` | within 1e-6 over the supported lag-1 options |
| `fit_mlvar()` | Multilevel and person-specific VAR | `mlVAR` 0.7.3 | within 1e-8 on 20 ESM panels |
| `fit_gimme()` | Group and individual uSEM path search | `gimme` 10.0 | identical paths and matrices on panels of two and three variables, fit indices within 5e-5 |
| `fit_mlvar_bayes()` | Bayesian multilevel VAR (DSEM) | Mplus DSEM, Stan, JAGS | within Monte Carlo error |
| `fit_var_bayes()` | Bayesian VAR(1) | Mplus with `ESTIMATOR = BAYES` | within 0.02 to 0.03 |

`fit_mlvar_bayes()` estimates the two-level Bayesian VAR of Mplus, with latent
centring of the person means, by a Gibbs sampler written in R. Its comparison
with Mplus covers bivariate models with fixed effects, a univariate model with
a random autoregression, and simulations of parameter recovery.
`equivalence()` returns the tested configurations for a fitted model, and
`equivalence_table()` and `argument_coverage()` return them for all methods.

## Dependencies

The package imports only packages distributed with R. The suggested packages
`lme4` and `lavaan` estimate the frequentist multilevel VAR and the uSEM and
GIMME models, `cograph` plots the networks, and `MplusAutomation` connects to a
licensed installation of Mplus. Each suggested package is loaded when a
function that needs it is called.

## Documentation

The articles at <https://pak.dynasite.org/idiographic/articles/> work through
each method on the bundled data.

| Topic | Article |
|---|---|
| Choice of a statistical method | [Guide to idiographic statistical workflows](https://pak.dynasite.org/idiographic/articles/statistical-workflows.html) |
| Description of persons | [Describing persons](https://pak.dynasite.org/idiographic/articles/describing-persons.html) |
| Preparation of the panel | [Preparing panel data](https://pak.dynasite.org/idiographic/articles/preprocess-panel.html) |
| Regression | [Regression models](https://pak.dynasite.org/idiographic/articles/regression-models.html) |
| Prediction | [Idiographic prediction and temporal validation](https://pak.dynasite.org/idiographic/articles/prediction.html) |
| Pooling and shrinkage | [Pooling and shrinking person-specific coefficients](https://pak.dynasite.org/idiographic/articles/pooling-shrinkage.html) |
| Subgroups and treatment effects | [Subgroups, treatment effects, and heterogeneity](https://pak.dynasite.org/idiographic/articles/subgroups-effects.html) |
| A complete analysis | [From raw panel data to person-specific conclusions](https://pak.dynasite.org/idiographic/articles/unified-workflow.html) |
| Dynamic networks | [idiographic](https://pak.dynasite.org/idiographic/articles/idiographic.html), [Preprocessing](https://pak.dynasite.org/idiographic/articles/preprocessing.html), [Ordinary VAR](https://pak.dynasite.org/idiographic/articles/ordinary-var.html), [Multilevel VAR](https://pak.dynasite.org/idiographic/articles/mlvar.html), [Unified SEM](https://pak.dynasite.org/idiographic/articles/usem.html), [Rolling networks](https://pak.dynasite.org/idiographic/articles/rolling-networks.html) |
| Implementation | [Clean-room design](https://pak.dynasite.org/idiographic/articles/clean-room-methods.html) |

## Citation

Saqr, M., & López-Pernas, S. (2026). *idiographic: Person-Specific Statistics
and Heterogeneous Dynamic Networks*. R package.
<https://github.com/mohsaqr/idiographic>

## License

GPL-3.
