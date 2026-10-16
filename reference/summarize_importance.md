# Summarise predictor importance across people

Summaries use equal weight for each person. Top-feature frequency
retains all ties at the requested rank. Pooled and individual means are
returned separately rather than averaged together.

## Usage

``` r
summarize_importance(
  x,
  by = c("mean", "frequency"),
  model = NULL,
  scope = NULL,
  subject = NULL,
  top_n = 5L,
  method = c("coefficient", "permutation"),
  repeats = 5L
)
```

## Arguments

- x:

  An idiographic fit or a table returned by
  [`importance()`](https://pak.dynasite.org/idiographic/reference/importance.md).

- by:

  `"mean"` for mean importance or `"frequency"` for top-feature counts.

- model, scope, subject:

  Optional filters.

- top_n:

  Number of highest-ranked features for frequency summaries.

- method, repeats:

  Passed to
  [`importance()`](https://pak.dynasite.org/idiographic/reference/importance.md)
  when `x` is a fitted object.

## Value

A data frame with one row per scope, model, estimator, subgroup and
predictor. Includes `n_subjects`; frequencies also include `count` and
`percent`.

## Examples

``` r
fit <- fit_ml(srl, y = "effort", x = c("efficacy", "monitoring"),
              id = "name", model = "ridge", scope = "individual")
summarize_importance(fit, by = "frequency", top_n = 1)
#>        scope model estimator subgroup   variable n_subjects count  percent
#> 1 individual ridge    native    .none   efficacy         36    19 52.77778
#> 2 individual ridge    native    .none monitoring         36    17 47.22222
```
