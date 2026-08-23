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
