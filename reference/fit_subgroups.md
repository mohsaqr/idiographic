# Fit subgroup-specific models

Fits pooled, subgroup and person-specific models together so all three
levels can be compared in one table.

## Usage

``` r
fit_subgroups(
  data,
  y,
  x,
  id,
  subgroup,
  method = c("lm", "glm", "ml"),
  scope = "all",
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

- subgroup:

  Subgroup mapping: an
  [`find_subgroups()`](https://pak.dynasite.org/idiographic/reference/find_subgroups.md)
  result, a grouping column in `data`, or a named vector of labels per
  person.

- method:

  Which family to fit: `"lm"`, `"glm"`, or `"ml"`.

- scope:

  Defaults to `"all"` (pooled + subgroup + individual).

- ...:

  Passed to the underlying fitter, e.g. `model` or `family`.

## Value

An `idiographic_fit`.

## Examples

``` r
g <- find_subgroups(srl, y = "effort", x = "efficacy:monitoring",
                    id = "name", k = 2, reps = 10)
fit <- fit_subgroups(srl, y = "effort", x = "efficacy:monitoring",
                     id = "name", subgroup = g, time = "day")
metrics(fit, overall = TRUE)
#>        scope model estimator  subject subgroup    n     rmse      mae      bias
#> 1     pooled    lm    native .overall     .all 1150 20.18702 16.28579 0.7323279
#> 2   subgroup    lm    native .overall     .all 1150 19.61460 15.79144 0.8497595
#> 3 individual    lm    native .overall     .all 1150 17.23228 12.86623 0.7977109
#>   r_squared
#> 1 0.4353275
#> 2 0.4668970
#> 3 0.5885302
```
