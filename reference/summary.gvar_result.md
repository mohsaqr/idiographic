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
