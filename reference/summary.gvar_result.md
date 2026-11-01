# Summary Method for gvar_result

Summary Method for gvar_result

## Usage

``` r
# S3 method for class 'gvar_result'
summary(object, ...)
```

## Arguments

- object:

  A `gvar_result` object.

- ...:

  Additional arguments (ignored).

## Value

A tidy `data.frame` of per-network metrics: one row per network
(`temporal`, `contemporaneous`) with `n_nodes`, `n_edges`, `density`,
`mean_abs_weight`, `n_positive`, `n_negative`. Use `edges(object)` /
`coefs(object)` for the estimates and `nodes(object)` for node
strengths.

## Examples

``` r
fit <- fit_graphical_var(srl, vars = c("efficacy", "planning", "effort"),
                         id = "name", subject = "Aisha", n_lambda = 5)
summary(fit)
#>           network n_nodes n_edges density mean_abs_weight n_positive n_negative
#> 1        temporal       3       0       0       0.0000000          0          0
#> 2 contemporaneous       3       3       1       0.2833404          3          0
```
