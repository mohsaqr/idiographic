# Get a registered estimator function

Get a registered estimator function

## Usage

``` r
get_estimator(method)
```

## Arguments

- method:

  A registered method name or alias. Names are case-insensitive; spaces,
  hyphens, and periods are normalized to underscores.

## Value

`get_estimator()` returns the registered fitting function.

## Examples

``` r
var_fitter <- get_estimator("var")
is.function(var_fitter)
#> [1] TRUE
```
