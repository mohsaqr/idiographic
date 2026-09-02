# Tidy treatment effects

A method on the
[`stats::effects()`](https://rdrr.io/r/stats/effects.html) generic, so
it does not mask anything.

## Usage

``` r
# S3 method for class 'idiostats_effects'
effects(
  object,
  effect = NULL,
  contrast = NULL,
  scope = NULL,
  subject = NULL,
  subgroup = NULL,
  sort_by = NULL,
  decreasing = FALSE,
  n = NULL,
  ...
)
```

## Arguments

- object:

  An
  [`fit_effects()`](https://pak.dynasite.org/idiographic/reference/fit_effects.md)
  result.

- effect:

  Optional filter on the effect label, e.g. `"ATE"`.

- contrast:

  Optional filter on the contrast, e.g. `"b vs a"`.

- scope, subject, subgroup:

  Optional filters.

- sort_by:

  Optional column to sort by.

- decreasing:

  Sort order when `sort_by` is supplied.

- n:

  Optional number of rows.

- ...:

  Ignored.

## Value

A data frame of effects with confidence intervals.

## Examples

``` r
set.seed(1)
d <- data.frame(id = rep(1:6, each = 40), day = rep(1:40, 6),
                x1 = rnorm(240), x2 = rnorm(240))
d$drug <- rbinom(240, 1, 0.5)
d$mood <- 2 * d$drug * (d$x1 > 0) + 0.5 * d$x1 + rnorm(240, sd = 0.5)
fit <- fit_effects(d, "mood", "drug", c("x1", "x2"), "id", scope = "pooled")
effects(fit, effect = "ATE")
#>    scope  model estimator subject subgroup effect contrast  n n_people
#> 1 pooled linear    native    .all     .all    ATE   1 vs 0 72        6
#>    estimate std_error  conf_low conf_high statistic    p_value
#> 1 0.8440564 0.2754044 0.1361068  1.552006  3.064789 0.02794912
```
