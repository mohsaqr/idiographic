# Summary method for uSEM fits

Summary method for uSEM fits

## Usage

``` r
# S3 method for class 'net_usem'
summary(object, ...)
```

## Arguments

- object:

  A `net_usem` object.

- ...:

  Ignored.

## Value

A `data.frame` with one row per network layer (`temporal`,
`contemporaneous`): `network`, `n_nodes`, `n_edges`, `density`,
`mean_abs_weight`, `n_positive` and `n_negative`.
