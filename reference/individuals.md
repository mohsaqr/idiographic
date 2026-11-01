# Focus an idiographic fit on all individual models

Focus an idiographic fit on all individual models

## Usage

``` r
individuals(x)
```

## Arguments

- x:

  An idiographic fit.

## Value

An `idiographic_fit` of the same structure as `x` whose metric,
prediction, coefficient and tuning tables are restricted to the
person-specific (`"individual"`) scope, so that
[`metrics()`](https://pak.dynasite.org/idiographic/reference/metrics.md),
[`predictions()`](https://pak.dynasite.org/idiographic/reference/predictions.md)
and [`coefs()`](https://pak.dynasite.org/idiographic/reference/coefs.md)
report only those rows.

## Examples

``` r
fit <- fit_lm(srl, y = "effort", x = "efficacy", id = "name", time = "day")
individuals(fit) |> coefs(term = "efficacy", n = 5)
#>        scope model estimator subject subgroup     term  estimate  std_error
#> 1 individual    lm    native   Aisha    .none efficacy 0.3010538 0.07459288
#> 2 individual    lm    native   Alice    .none efficacy 0.5300123 0.07899578
#> 3 individual    lm    native   Anika    .none efficacy 0.4859371 0.09748183
#> 4 individual    lm    native  Astrid    .none efficacy 0.1569693 0.08423382
#> 5 individual    lm    native   Bjorn    .none efficacy 0.3222659 0.07711780
#>   statistic      p_value
#> 1  4.035959 9.529560e-05
#> 2  6.709375 6.505636e-10
#> 3  4.984899 2.073252e-06
#> 4  1.863495 6.479704e-02
#> 5  4.178879 5.536425e-05
```
