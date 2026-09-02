# Fit pooled, subgroup and person-specific linear models

Fits a linear model at every requested scope and returns them in one
tidy object, so pooled and person-specific results are directly
comparable.

## Usage

``` r
fit_lm(
  data,
  y,
  x,
  id,
  time = NULL,
  scope = "both",
  subgroup = NULL,
  estimator = "native",
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

- estimator:

  `"native"` for [`stats::lm()`](https://rdrr.io/r/stats/lm.html), or
  `"robust"` for an M-estimator
  ([`MASS::rlm()`](https://rdrr.io/pkg/MASS/man/rlm.html)) that is not
  dragged around by outliers.

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
fit <- fit_lm(srl, y = "effort", x = "efficacy:monitoring", id = "name",
              time = "day")
metrics(fit, overall = TRUE)
#>        scope model estimator  subject subgroup    n     rmse      mae      bias
#> 1     pooled    lm    native .overall     .all 1150 20.18702 16.28579 0.7323279
#> 2 individual    lm    native .overall     .all 1150 17.23228 12.86623 0.7977109
#>   r_squared
#> 1 0.4353275
#> 2 0.5885302

# A few wild days should not decide a person's slope.
robust <- fit_lm(srl, y = "effort", x = "efficacy:monitoring", id = "name",
                 time = "day", estimator = "robust")
metrics(robust, overall = TRUE)
#>        scope model estimator  subject subgroup    n     rmse      mae      bias
#> 1     pooled    lm    robust .overall     .all 1150 20.09225 16.09355 0.2580218
#> 2 individual    lm    robust .overall     .all 1150 17.30642 12.67565 0.5440047
#>   r_squared
#> 1 0.4406164
#> 2 0.5849822
```
