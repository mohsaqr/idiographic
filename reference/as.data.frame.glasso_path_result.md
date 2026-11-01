# Tidy a graphical-lasso path

Tidy a graphical-lasso path

## Usage

``` r
# S3 method for class 'glasso_path_result'
as.data.frame(x, row.names = NULL, optional = FALSE, ...)
```

## Arguments

- x:

  A `glasso_path_result` from
  [`glasso_path()`](https://pak.dynasite.org/idiographic/reference/glasso_path.md).

- row.names, optional:

  Ignored; present for S3 consistency.

- ...:

  Ignored.

## Value

A `data.frame` with one row per variable pair per penalty and columns
`rho`, `from`, `to`, `precision` and `weight`.

## Examples

``` r
set.seed(1)
x <- matrix(rnorm(200 * 3), ncol = 3, dimnames = list(NULL, c("A", "B", "C")))
as.data.frame(glasso_path(cov(x), rho = c(0.01, 0.2)))
#>    rho from to   precision       weight
#> 1 0.01    A  C -0.05849016  0.057942086
#> 2 0.01    B  C  0.01521433 -0.016420977
#> 3 0.01    A  B  0.01023722 -0.009594679
#> 4 0.20    A  B  0.00000000  0.000000000
#> 5 0.20    A  C  0.00000000  0.000000000
#> 6 0.20    B  C  0.00000000  0.000000000
```
