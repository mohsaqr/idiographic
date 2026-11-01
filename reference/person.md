# Focus an idiographic fit on one person

Focus an idiographic fit on one person

## Usage

``` r
person(x, id, ...)
```

## Arguments

- x:

  An idiographic fit.

- id:

  Person ID.

- ...:

  Ignored.

## Value

An `idiographic_fit` of the same structure as `x` whose metric,
prediction, coefficient and tuning tables are restricted to the
person-specific models of `id`, so that
[`metrics()`](https://pak.dynasite.org/idiographic/reference/metrics.md),
[`predictions()`](https://pak.dynasite.org/idiographic/reference/predictions.md)
and [`coefs()`](https://pak.dynasite.org/idiographic/reference/coefs.md)
report only those rows.

## Examples

``` r
fit <- fit_lm(srl, y = "effort", x = "efficacy", id = "name", time = "day")
person(fit, "Aisha") |> coefs()
#>        scope model estimator subject subgroup        term   estimate  std_error
#> 1 individual    lm    native   Aisha    .none (Intercept) 60.2330643 4.54319490
#> 2 individual    lm    native   Aisha    .none    efficacy  0.3010538 0.07459288
#>   statistic      p_value
#> 1 13.257865 2.143208e-25
#> 2  4.035959 9.529560e-05
```
