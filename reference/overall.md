# Focus an idiographic fit on overall metric rows

Focus an idiographic fit on overall metric rows

## Usage

``` r
overall(x)
```

## Arguments

- x:

  An idiographic fit.

## Value

An `idiographic_fit` of the same structure as `x` whose metric and
tuning tables keep only the `.overall` rows; predictions and
coefficients are unchanged.

## Examples

``` r
fit <- fit_lm(srl, y = "effort", x = "efficacy", id = "name", time = "day")
overall(fit) |> metrics()
#>        scope model estimator  subject subgroup    n     rmse      mae      bias
#> 1     pooled    lm    native .overall     .all 1150 22.15170 18.16606 0.5861259
#> 2 individual    lm    native .overall     .all 1150 19.22193 14.95209 0.4451146
#>   r_squared
#> 1 0.3200665
#> 2 0.4880281
```
