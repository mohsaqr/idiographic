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

  `"both"` (pooled + individual), `"pooled"`, `"individual"`,
  `"subgroup"`, or `"all"` (pooled + subgroup + individual).

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

An `idiographic_fit`.

## Examples

``` r
# `srl` carries some missing values, so na.rm is needed to derive an outcome.
srl$high <- ifelse(srl$effort > median(srl$effort, na.rm = TRUE),
                   "yes", "no")
fit <- fit_glm(srl, y = "high", x = c("efficacy", "planning"), id = "name",
               family = "binomial", time = "day")
metrics(fit, overall = TRUE)
#>        scope    model estimator  subject subgroup    n  accuracy     brier
#> 1     pooled binomial    native .overall     .all 1150 0.7165217 0.1869180
#> 2 individual binomial    native .overall     .all 1150 0.7765217 0.1485573
#>    log_loss
#> 1 0.5541527
#> 2 0.4468249
```
