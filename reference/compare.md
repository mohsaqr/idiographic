# Compare idiographic fits

Compare idiographic fits

## Usage

``` r
compare(...)
```

## Arguments

- ...:

  One or more consolidated idiographic fits (from
  [`fit_lm()`](https://pak.dynasite.org/idiographic/reference/fit_lm.md),
  [`fit_glm()`](https://pak.dynasite.org/idiographic/reference/fit_glm.md),
  [`fit_ml()`](https://pak.dynasite.org/idiographic/reference/fit_ml.md),
  [`fit_subgroups()`](https://pak.dynasite.org/idiographic/reference/fit_subgroups.md)
  or
  [`fit_rolling()`](https://pak.dynasite.org/idiographic/reference/fit_rolling.md)).

## Value

A `data.frame` with one row per fit, scope and model: `fit` (the
position of the fit in `...`), `method`, and the `.overall` columns of
[`metrics()`](https://pak.dynasite.org/idiographic/reference/metrics.md).
An empty `data.frame` when no fit is supplied.

## Examples

``` r
linear <- fit_lm(srl, y = "effort", x = "efficacy", id = "name",
                 time = "day")
ridge <- fit_ml(srl, y = "effort", x = "efficacy", id = "name",
                time = "day", model = "ridge")
compare(linear, ridge)
#>   fit method      scope model estimator  subject subgroup    n     rmse
#> 1   1     lm     pooled    lm    native .overall     .all 1150 22.15170
#> 2   1     lm individual    lm    native .overall     .all 1150 19.22193
#> 3   2     ml     pooled ridge    native .overall     .all 1150 22.15203
#> 4   2     ml individual ridge    native .overall     .all 1150 19.22689
#>        mae      bias r_squared
#> 1 18.16606 0.5861259 0.3200665
#> 2 14.95209 0.4451146 0.4880281
#> 3 18.16660 0.5862116 0.3200465
#> 4 14.96088 0.4489865 0.4877635
```
