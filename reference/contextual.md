# Compare the within-person and between-person effect of each predictor

The point of a within-between model. `within` is the effect of a person
moving away from their own average; `between` is the effect of one
person averaging higher than another. `contextual` is
`between - within`, with a person-clustered test: if its interval
excludes zero, the two processes are genuinely different and pooling
them into one coefficient is a modelling error.

## Usage

``` r
contextual(
  x,
  variable = NULL,
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

- x:

  A
  [`fit_within_between()`](https://pak.dynasite.org/idiographic/reference/fit_within_between.md)
  result.

- variable, scope, subject, subgroup:

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

A data frame with one row per predictor per unit.

## Details

`model = "within"` and `model = "between"` fit only one component, so
their contextual effect is `NA` – there is nothing to compare it
against.

## Examples

``` r
fit <- fit_within_between(srl, y = "effort", x = c("efficacy", "planning"),
                          id = "name", time = "day")
contextual(fit)
#>   variable   within   between   contextual     S.E.            95% CI       p
#> -----------------------------------------------------------------------------
#>   efficacy   0.2681    0.4602       0.1921   0.1361   [-0.084, 0.468]   0.167
#>   planning   0.3319    0.2257      -0.1062   0.1496   [-0.410, 0.197]   0.483
#> 
#> scope = pooled,  model = within_between,  estimator = ols,  subject = .all,  subgroup = .all
```
