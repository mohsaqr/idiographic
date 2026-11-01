# Summary method for ordinary VAR fits

Summary method for ordinary VAR fits

## Usage

``` r
# S3 method for class 'var_result'
summary(object, ...)
```

## Arguments

- object:

  A `var_result` object.

- ...:

  Ignored.

## Value

A `data.frame` with one row per network layer (`temporal`,
`contemporaneous`): `network`, `n_nodes`, `n_edges`, `density`,
`mean_abs_weight`, `n_positive` and `n_negative`.

## Examples

``` r
set.seed(1)
d <- data.frame(A = rnorm(80), B = rnorm(80), C = rnorm(80))
summary(fit_var(d, vars = c("A", "B", "C")))
#>           network n_nodes n_edges density mean_abs_weight n_positive n_negative
#> 1        temporal       3       6       1      0.04532377          3          3
#> 2 contemporaneous       3       3       1      0.17351661          2          1
```
