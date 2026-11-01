# Summary method for var_bayes_result

Summary method for var_bayes_result

## Usage

``` r
# S3 method for class 'var_bayes_result'
summary(object, ...)
```

## Arguments

- object:

  A `var_bayes_result`.

- ...:

  Unused.

## Value

A `data.frame` with one row per network layer (`temporal`,
`contemporaneous`): `network`, `n_nodes`, `n_edges`, `density`,
`mean_abs_weight`, `n_positive` and `n_negative`.
