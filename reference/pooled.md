# Focus an idiographic fit on pooled models

Focus an idiographic fit on pooled models

## Usage

``` r
pooled(x)
```

## Arguments

- x:

  An idiographic fit.

## Value

An `idiographic_fit` of the same structure as `x` whose metric,
prediction, coefficient and tuning tables are restricted to the pooled
scope, so that
[`metrics()`](https://pak.dynasite.org/idiographic/reference/metrics.md),
[`predictions()`](https://pak.dynasite.org/idiographic/reference/predictions.md)
and [`coefs()`](https://pak.dynasite.org/idiographic/reference/coefs.md)
report only those rows.

## Examples

``` r
fit <- fit_lm(srl, y = "effort", x = "efficacy", id = "name", time = "day")
pooled(fit) |> coefs()
#>    scope model estimator subject subgroup        term   estimate  std_error
#> 1 pooled    lm    native    .all     .all (Intercept) 32.5060708 4.52339554
#> 2 pooled    lm    native    .all     .all    efficacy  0.4878091 0.06319256
#>   statistic      p_value
#> 1  7.186210 2.200421e-08
#> 2  7.719407 4.617938e-09
```
