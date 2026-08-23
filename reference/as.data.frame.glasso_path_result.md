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
