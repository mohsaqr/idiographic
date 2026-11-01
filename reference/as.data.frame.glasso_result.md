# Tidy a graphical-lasso fit

Tidy a graphical-lasso fit

## Usage

``` r
# S3 method for class 'glasso_result'
as.data.frame(x, row.names = NULL, optional = FALSE, ...)
```

## Arguments

- x:

  A `glasso_result` from
  [`glasso_fit()`](https://pak.dynasite.org/idiographic/reference/glasso_fit.md).

- row.names, optional:

  Ignored; present for S3 consistency.

- ...:

  Ignored.

## Value

A `data.frame` with one row per unique variable pair and columns `from`,
`to`, `precision` (the \\\Theta\\ entry) and `weight` (the partial
correlation implied by \\\Theta\\).

## Examples

``` r
set.seed(1)
x <- matrix(rnorm(200 * 3), ncol = 3, dimnames = list(NULL, c("A", "B", "C")))
as.data.frame(glasso_fit(cov(x), rho = 0.05))
#>   from to   precision     weight
#> 1    A  C -0.01798606 0.01787542
#> 2    A  B  0.00000000 0.00000000
#> 3    B  C  0.00000000 0.00000000
```
