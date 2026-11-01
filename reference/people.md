# Focus an idiographic fit on selected people

Focus an idiographic fit on selected people

## Usage

``` r
people(x, ids)
```

## Arguments

- x:

  An idiographic fit.

- ids:

  Person IDs.

## Value

An `idiographic_fit` of the same structure as `x` whose metric,
prediction, coefficient and tuning tables are restricted to the
person-specific models of `ids`, so that
[`metrics()`](https://pak.dynasite.org/idiographic/reference/metrics.md),
[`predictions()`](https://pak.dynasite.org/idiographic/reference/predictions.md)
and [`coefs()`](https://pak.dynasite.org/idiographic/reference/coefs.md)
report only those rows.

## Examples

``` r
fit <- fit_lm(srl, y = "effort", x = "efficacy", id = "name", time = "day")
people(fit, c("Aisha", "Alice")) |> metrics()
#>        scope model estimator subject subgroup  n     rmse      mae      bias
#> 1 individual    lm    native   Aisha    .none 32 13.76904 10.91345  1.348749
#> 2 individual    lm    native   Alice    .none 32 18.88505 14.75438 -2.125675
#>    r_squared
#> 1 0.15393510
#> 2 0.09420034
```
