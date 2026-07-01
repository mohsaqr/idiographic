# Summary Method for net_gimme

Summary Method for net_gimme

## Usage

``` r
# S3 method for class 'net_gimme'
summary(object, ...)
```

## Arguments

- object:

  A `net_gimme` object.

- ...:

  Additional arguments (ignored).

## Value

A tidy `data.frame` of per-network metrics (one row per network:
`temporal`, `contemporaneous`), with `n_edges`/`density`/etc. computed
from the proportion-of-subjects networks. Per-subject fit indices are in
`object$fit`; `coefs(object)` gives the per-person estimates,
`edges(object)` the tidy edge list, and `nodes(object)` node strengths.

## Examples

``` r
# \donttest{
set.seed(1)
panel <- data.frame(
  id = rep(1:5, each = 20),
  t  = rep(seq_len(20), 5),
  A  = rnorm(100), B = rnorm(100), C = rnorm(100)
)
gm <- build_gimme(panel, vars = c("A","B","C"), id = "id", time = "t")
summary(gm)
#>           network n_nodes n_edges density mean_abs_weight n_positive n_negative
#> 1        temporal       3       0       0               0          0          0
#> 2 contemporaneous       3       0       0               0          0          0
# }
```
