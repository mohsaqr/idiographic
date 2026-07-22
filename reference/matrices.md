# Print model matrices for idiographic results

`matrices()` is the matrix-oriented companion to
[`summary()`](https://rdrr.io/r/base/summary.html) and
[`edges()`](https://mohsaqr.github.io/idiographic/reference/edges.md).
It returns the core estimated matrices invisibly and prints each matrix
compactly with rounding, so users can inspect coefficients without
digging through object internals.

## Usage

``` r
matrices(x, ...)

# Default S3 method
matrices(x, digits = 3, ...)

# S3 method for class 'cograph_network'
matrices(x, digits = 3, ...)

# S3 method for class 'netobject'
matrices(x, digits = 3, ...)

# S3 method for class 'netobject_group'
matrices(x, digits = 3, ...)

# S3 method for class 'gvar_result'
matrices(x, digits = 3, ...)

# S3 method for class 'var_result'
matrices(x, digits = 3, ...)

# S3 method for class 'net_mlvar'
matrices(x, digits = 3, ...)

# S3 method for class 'net_usem'
matrices(x, digits = 3, ...)

# S3 method for class 'net_gimme'
matrices(x, digits = 3, ...)

# S3 method for class 'preprocess_result'
matrices(x, digits = 3, ...)

# S3 method for class 'rolling_var_result'
matrices(x, fit = 1L, digits = 3, ...)

# S3 method for class 'rolling_gvar_result'
matrices(x, fit = 1L, digits = 3, ...)

# S3 method for class 'stability_result'
matrices(x, digits = 3, ...)

# S3 method for class 'model_comparison'
matrices(x, fit = 1L, digits = 3, ...)

# S3 method for class 'var_list'
matrices(x, subject = 1L, digits = 3, ...)

# S3 method for class 'gvar_list'
matrices(x, subject = 1L, digits = 3, ...)
```

## Arguments

- x:

  An idiographic result or cograph network/group.

- ...:

  Passed to methods.

- digits:

  Number of digits used for printing. Default `3`.

- fit:

  Stored fit name or index for result containers that optionally keep
  fitted models, such as rolling results and model comparisons.

- subject:

  Subject name or index for per-subject VAR/GVAR result lists.

## Value

Invisibly, a named list of matrices.

## Examples

``` r
W <- matrix(c(0, 0.3, -0.2, 0), 2, 2,
            dimnames = list(c("A", "B"), c("A", "B")))
x <- structure(list(weights = W, method = "relative", directed = TRUE),
               class = "cograph_network")
matrices(as_netobject(x))
#> 
#> $weights
#>     A    B
#> A 0.0 -0.2
#> B 0.3  0.0
```
