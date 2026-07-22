# Inspect a registered estimator

Inspect a registered estimator

## Usage

``` r
estimator_info(method)
```

## Arguments

- method:

  A registered method name or alias. Names are case-insensitive; spaces,
  hyphens, and periods are normalized to underscores.

## Value

`estimator_info()` returns the complete registration as a list.

## Examples

``` r
estimator_info("var")
#> $name
#> [1] "var"
#> 
#> $fit
#> [1] "fit_var"
#> 
#> $aliases
#> [1] "fit_var" "ols"     "ols_var"
#> 
#> $kind
#> [1] "estimator"
#> 
#> $description
#> [1] "Ordinary least-squares VAR(1)"
#> 
#> $result_class
#> [1] "var_result"
#> 
#> $equivalence
#> $equivalence$status
#> [1] "validated"
#> 
#> $equivalence$reference
#> [1] "stats::lm.fit"
#> 
#> $equivalence$scope
#> [1] "OLS coefficient engine and package-defined VAR(1) preprocessing."
#> 
#> $equivalence$tolerance
#> [1] 1e-10
#> 
#> $equivalence$notes
#> [1] "This is engine equivalence, not blanket equivalence to another VAR package."
#> 
#> 
```
