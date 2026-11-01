# Fit pooled, subgroup and person-specific generalized linear models

Fit pooled, subgroup and person-specific generalized linear models

## Usage

``` r
fit_glm(
  data,
  y,
  x,
  id,
  family = "binomial",
  time = NULL,
  scope = "both",
  subgroup = NULL,
  weights = NULL,
  test_prop = 0.2,
  min_train = 10L,
  min_test = 1L,
  ...
)
```

## Arguments

- data:

  Data frame.

- y:

  Outcome column name.

- x:

  Predictors: names, numeric positions, `a:b` range, formula, or data
  frame.

- id:

  Person/unit ID column.

- family:

  GLM family name or family object. Native support covers `"gaussian"`,
  `"binomial"`, and `"poisson"`. `"negbin"` fits a negative binomial via
  [`MASS::glm.nb()`](https://rdrr.io/pkg/MASS/man/glm.nb.html), which is
  what overdispersed counts need – Poisson would report standard errors
  that are too small.

- time:

  Optional ordering column.

- scope:

  Level(s) at which models are fitted: any of `"pooled"`, `"subgroup"`,
  and `"individual"`, alone or as a vector such as
  `c("pooled", "individual")`. `"both"` is shorthand for pooled and
  individual, `"all"` for all three.

- subgroup:

  Optional subgroup mapping: an
  [`find_subgroups()`](https://pak.dynasite.org/idiographic/reference/find_subgroups.md)
  result, a grouping column in `data`, or a named vector of labels per
  person.

- weights:

  Optional column name in `data` holding case weights.

- test_prop:

  Proportion of each person's ordered rows held out.

- min_train:

  Minimum complete training rows per person.

- min_test:

  Minimum complete held-out rows per person.

- ...:

  Passed to the underlying fitter.

## Value

An `idiographic_fit` (also of class `idiostats_fit`). Read it with
[`coefs()`](https://pak.dynasite.org/idiographic/reference/coefs.md)
(one row per scope, model, person and term: `estimate`, `std_error`,
`statistic`, `p_value`),
[`metrics()`](https://pak.dynasite.org/idiographic/reference/metrics.md)
(held-out prediction error, one row per scope, model and person plus
`.overall` rows),
[`predictions()`](https://pak.dynasite.org/idiographic/reference/predictions.md)
(one row per held-out occasion) and
[`failures()`](https://pak.dynasite.org/idiographic/reference/failures.md)
(persons or scopes that could not be fitted).

## Details

Pooled and subgroup models combine many occasions of each person. Their
standard errors, test statistics, and p-values are cluster-robust,
clustered on `id` (CR1 sandwich estimator), so that repeated occasions
of the same person are not treated as independent observations. With few
persons, cluster-robust inference is imprecise. Person-specific models
report the model-based standard errors of the fitted model.

## Examples

``` r
# Daily submission (0/1) of 40 simulated learners, predicted by motivation.
fit <- fit_glm(submissions, y = "submitted", x = "motivation",
               id = "learner", family = "binomial", time = "day")
coefs(fit, scope = "pooled")
#>    scope    model estimator subject subgroup        term   estimate  std_error
#> 1 pooled binomial    native    .all     .all (Intercept) -0.1210932 0.08797027
#> 2 pooled binomial    native    .all     .all  motivation  0.2297620 0.12060291
#>   statistic    p_value
#> 1 -1.376524 0.16865944
#> 2  1.905111 0.05676559
metrics(fit, overall = TRUE)
#>        scope    model estimator  subject subgroup   n accuracy     brier
#> 1     pooled binomial    native .overall     .all 640 0.565625 0.2432327
#> 2 individual binomial    native .overall     .all 640 0.659375 0.2098596
#>    log_loss
#> 1 0.6794943
#> 2 0.6062158
```
