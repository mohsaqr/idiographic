# idiographic

Idiographic analysis studies one person at a time. Each person
contributes a time series of repeated observations, and a model fitted
to that series estimates the effects within that person, for example how
a learner’s effort on a day depends on the learner’s self-efficacy on
that day. Nomothetic analysis estimates effects averaged over a
population of persons. The average describes an individual only when all
persons share the same process. Intensive longitudinal data, such as
experience sampling (ESM), ecological momentary assessment (EMA) and
daily diaries, contain enough observations per person to estimate the
process of each person and to examine this assumption.

The package covers two families of idiographic methods. Person-specific
statistical models describe the series of each person, regress an
outcome on predictors within each person, predict later observations
from earlier ones, and separate within-person from between-person
effects. Dynamic network models estimate the temporal and
contemporaneous relations among several variables, for one person, for
each person in a sample, or for the average person in a multilevel
model. In both families the person-specific estimates are compared with
a pooled model of all persons and with models of subgroups of persons.

## Installation

The released version is on CRAN.

``` r

install.packages("idiographic")
```

The development version contains the person-specific statistical models.
It is available as a binary from the r-universe of the author and as
source from GitHub.

``` r

install.packages("idiographic",
                 repos = c("https://mohsaqr.r-universe.dev",
                           "https://cloud.r-project.org"))

pak::pak("mohsaqr/idiographic")
```

## Data

The examples use `srl`, a data frame in long format with one row per
student and day. Thirty-six students rated nine indicators of
self-regulated learning, among them self-efficacy, planning, monitoring
and effort, on each of 156 days. The column `name` identifies the
student and `day` orders the observations. The package also contains
`esm_srl`, momentary ratings from 41 students with several occasions per
day, and `submissions`, a simulated daily binary outcome for 40 learners
of two latent types.

## Person-specific models

A person-specific regression fits one model to the series of each
person, and a pooled regression fits one model to the observations of
all persons. With `scope = "both"`,
[`fit_lm()`](https://pak.dynasite.org/idiographic/reference/fit_lm.md)
estimates both, and
[`metrics()`](https://pak.dynasite.org/idiographic/reference/metrics.md)
reports their prediction error on the last observations of each person,
which are held out from estimation.

``` r

library(idiographic)

fit <- fit_lm(srl, y = "effort", x = "efficacy", id = "name", time = "day",
              scope = "both")
metrics(fit, overall = TRUE)
coefs(fit, scope = "individual")
```

A coefficient estimated from a short or noisy series is uncertain.
Empirical-Bayes shrinkage moves each person’s coefficient toward the
pooled coefficient, and it moves an uncertain coefficient further than a
precise one.

``` r

shrink_coefs(fit, term = "efficacy")
```

A predictor varies within persons, from day to day around the mean of
the person, and between persons, in the means themselves. The
within-person effect and the between-person effect are estimated in one
model, and their difference is the contextual effect.

``` r

wb <- fit_within_between(srl, y = "effort", x = "efficacy", id = "name",
                         time = "day")
contextual(wb)
```

Prediction models from machine learning are evaluated in the same way,
on observations later than those used for estimation, and
[`fit_rolling()`](https://pak.dynasite.org/idiographic/reference/fit_rolling.md)
repeats the evaluation at successive time points.

``` r

ml <- fit_ml(srl, y = "effort", x = c("efficacy", "planning", "monitoring"),
             id = "name", time = "day", scope = "both",
             model = c("ridge", "knn"), tune = TRUE)
metrics(ml, overall = TRUE)
```

## Dynamic networks

A dynamic network of several variables has two layers. A temporal edge
from one variable to another is the effect of the first variable on one
occasion on the second variable on the next occasion. A contemporaneous
edge is the partial correlation of two variables on the same occasion
after the temporal effects are removed. The multilevel vector
autoregression (mlVAR) estimates both layers for the average person,
together with a between-person network of the person means.

``` r

net <- fit_mlvar(srl, vars = c("efficacy", "planning", "monitoring", "effort"),
                 id = "name", beep = "day")
net
edges(net)
plot(net, layer = "temporal")
```

## Functions

| Task | Functions |
|----|----|
| Description of each person | [`describe_persons()`](https://pak.dynasite.org/idiographic/reference/describe_persons.md), [`correlate_persons()`](https://pak.dynasite.org/idiographic/reference/correlate_persons.md), [`variance_components()`](https://pak.dynasite.org/idiographic/reference/variance_components.md) |
| Preparation of the panel | [`preprocess_panel()`](https://pak.dynasite.org/idiographic/reference/preprocess_panel.md), [`split_levels()`](https://pak.dynasite.org/idiographic/reference/split_levels.md), [`preprocess()`](https://pak.dynasite.org/idiographic/reference/preprocess.md) |
| Regression | [`fit_lm()`](https://pak.dynasite.org/idiographic/reference/fit_lm.md), [`fit_glm()`](https://pak.dynasite.org/idiographic/reference/fit_glm.md) |
| Within-person and between-person effects | [`fit_within_between()`](https://pak.dynasite.org/idiographic/reference/fit_within_between.md), [`contextual()`](https://pak.dynasite.org/idiographic/reference/contextual.md), [`correlate_levels()`](https://pak.dynasite.org/idiographic/reference/correlate_levels.md) |
| Prediction and temporal validation | [`fit_ml()`](https://pak.dynasite.org/idiographic/reference/fit_ml.md), [`fit_rolling()`](https://pak.dynasite.org/idiographic/reference/fit_rolling.md), [`compare_predictions()`](https://pak.dynasite.org/idiographic/reference/compare_predictions.md) |
| Pooling and shrinkage | [`pool_coefs()`](https://pak.dynasite.org/idiographic/reference/pool_coefs.md), [`shrink_coefs()`](https://pak.dynasite.org/idiographic/reference/shrink_coefs.md) |
| Subgroups of persons | [`test_subgroups()`](https://pak.dynasite.org/idiographic/reference/test_subgroups.md), [`find_subgroups()`](https://pak.dynasite.org/idiographic/reference/find_subgroups.md), [`fit_subgroups()`](https://pak.dynasite.org/idiographic/reference/fit_subgroups.md) |
| Treatment effects and heterogeneity | [`fit_effects()`](https://pak.dynasite.org/idiographic/reference/fit_effects.md), [`fit_heterogeneity()`](https://pak.dynasite.org/idiographic/reference/fit_heterogeneity.md) |
| Vector autoregression for one person or each person | [`fit_var()`](https://pak.dynasite.org/idiographic/reference/fit_var.md), [`fit_var_each()`](https://pak.dynasite.org/idiographic/reference/fit_var_each.md), [`fit_graphical_var()`](https://pak.dynasite.org/idiographic/reference/fit_graphical_var.md), [`fit_graphical_var_each()`](https://pak.dynasite.org/idiographic/reference/fit_graphical_var_each.md) |
| Multilevel vector autoregression | [`fit_mlvar()`](https://pak.dynasite.org/idiographic/reference/fit_mlvar.md), [`fit_mlvar_mplus()`](https://pak.dynasite.org/idiographic/reference/fit_mlvar_mplus.md) |
| Bayesian vector autoregression and DSEM | [`fit_var_bayes()`](https://pak.dynasite.org/idiographic/reference/fit_var_bayes.md), [`fit_mlvar_bayes()`](https://pak.dynasite.org/idiographic/reference/fit_mlvar_bayes.md) |
| Structural equation models of the series | [`fit_usem()`](https://pak.dynasite.org/idiographic/reference/fit_usem.md), [`fit_gimme()`](https://pak.dynasite.org/idiographic/reference/fit_gimme.md) |
| Time-varying networks | [`fit_rolling_var()`](https://pak.dynasite.org/idiographic/reference/fit_rolling_var.md), [`fit_rolling_graphical_var()`](https://pak.dynasite.org/idiographic/reference/fit_rolling_graphical_var.md) |
| Stability and forecast validation | [`estimate_stability()`](https://pak.dynasite.org/idiographic/reference/estimate_stability.md), [`validate_forecast()`](https://pak.dynasite.org/idiographic/reference/validate_forecast.md), [`compare_idiographic()`](https://pak.dynasite.org/idiographic/reference/compare_idiographic.md) |

Each result is returned as a data frame by
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html). The
accessors
[`metrics()`](https://pak.dynasite.org/idiographic/reference/metrics.md),
[`predictions()`](https://pak.dynasite.org/idiographic/reference/predictions.md),
[`coefs()`](https://pak.dynasite.org/idiographic/reference/coefs.md),
[`importance()`](https://pak.dynasite.org/idiographic/reference/importance.md)
and
[`diagnostics()`](https://pak.dynasite.org/idiographic/reference/diagnostics.md)
return the parts of a statistical model, and
[`edges()`](https://pak.dynasite.org/idiographic/reference/edges.md),
[`nodes()`](https://pak.dynasite.org/idiographic/reference/nodes.md) and
[`matrices()`](https://pak.dynasite.org/idiographic/reference/matrices.md)
the parts of a network.

## Validation

The estimators are implemented in R and are tested against reference
implementations. The table lists the reference for each estimator and
the largest difference allowed in the tests.

| Estimator | Method | Reference | Agreement |
|----|----|----|----|
| [`fit_graphical_var()`](https://pak.dynasite.org/idiographic/reference/fit_graphical_var.md) | Graphical VAR with graphical lasso and EBIC | `graphicalVAR` | within 1e-6 over the supported lag-1 options |
| [`fit_mlvar()`](https://pak.dynasite.org/idiographic/reference/fit_mlvar.md) | Multilevel and person-specific VAR | `mlVAR` 0.7.3 | within 1e-8 on 20 ESM panels |
| [`fit_gimme()`](https://pak.dynasite.org/idiographic/reference/fit_gimme.md) | Group and individual uSEM path search | `gimme` 10.0 | identical paths and matrices on panels of two and three variables, fit indices within 5e-5 |
| [`fit_mlvar_bayes()`](https://pak.dynasite.org/idiographic/reference/fit_mlvar_bayes.md) | Bayesian multilevel VAR (DSEM) | Mplus DSEM, Stan, JAGS | within Monte Carlo error |
| [`fit_var_bayes()`](https://pak.dynasite.org/idiographic/reference/fit_var_bayes.md) | Bayesian VAR(1) | Mplus with `ESTIMATOR = BAYES` | within 0.02 to 0.03 |

[`fit_mlvar_bayes()`](https://pak.dynasite.org/idiographic/reference/fit_mlvar_bayes.md)
estimates the two-level Bayesian VAR of Mplus, with latent centring of
the person means, by a Gibbs sampler written in R. Its comparison with
Mplus covers bivariate models with fixed effects, a univariate model
with a random autoregression, and simulations of parameter recovery.
[`equivalence()`](https://pak.dynasite.org/idiographic/reference/equivalence.md)
returns the tested configurations for a fitted model, and
[`equivalence_table()`](https://pak.dynasite.org/idiographic/reference/equivalence_table.md)
and
[`argument_coverage()`](https://pak.dynasite.org/idiographic/reference/argument_coverage.md)
return them for all methods.

## Dependencies

The package imports only packages distributed with R. The suggested
packages `lme4` and `lavaan` estimate the frequentist multilevel VAR and
the uSEM and GIMME models, `cograph` plots the networks, and
`MplusAutomation` connects to a licensed installation of Mplus. Each
suggested package is loaded when a function that needs it is called.

## Documentation

The articles at <https://pak.dynasite.org/idiographic/articles/> work
through each method on the bundled data.

| Topic | Article |
|----|----|
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

Saqr, M., & López-Pernas, S. (2026). *idiographic: Person-Specific
Statistics and Heterogeneous Dynamic Networks*. R package.
<https://github.com/mohsaqr/idiographic>

## License

GPL-3.
