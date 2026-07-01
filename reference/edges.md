# Tidy edge table for any idiographic result

A single tidy verb for every network idiographic produces. Returns one
row per edge with columns `network` (e.g. `"temporal"`,
`"contemporaneous"`, `"between"`), `from`, `to`, `weight` – and, for
GIMME, `level` (`"group"`/`"individual"`). Directed networks (temporal)
keep every edge; undirected networks (contemporaneous, between) report
each pair once.

## Usage

``` r
# S3 method for class 'net_usem'
edges(x, sort_by = "weight", include_self = FALSE, ...)

# S3 method for class 'var_result'
edges(x, sort_by = "weight", include_self = FALSE, ...)

edges(x, ...)

# S3 method for class 'netobject'
edges(x, sort_by = "weight", include_self = FALSE, ...)

# S3 method for class 'netobject_group'
edges(x, sort_by = "weight", include_self = FALSE, ...)

# S3 method for class 'gvar_result'
edges(x, sort_by = "weight", include_self = FALSE, ...)

# S3 method for class 'net_mlvar'
edges(x, sort_by = "weight", include_self = FALSE, ...)

# S3 method for class 'net_gimme'
edges(
  x,
  sort_by = "weight",
  include_self = TRUE,
  weight = c("prop", "coef"),
  ...
)
```

## Arguments

- x:

  A `gvar_result`, `net_mlvar`, `net_gimme`, `netobject`, or
  `netobject_group`.

- sort_by:

  `"weight"` (descending \|weight\|) or `NULL` for natural order.

- include_self:

  Keep autoregressive self-loops? Default `FALSE` (`TRUE` for GIMME,
  where the autoregression is the point).

- ...:

  Passed to methods.

- weight:

  For GIMME only: `"prop"` (proportion of subjects, default) or `"coef"`
  (group-average coefficient) for the edge weight.

## Value

A tidy `data.frame`, one row per edge.

## Examples

``` r
# \donttest{
set.seed(1)
d <- data.frame(id = 1, A = rnorm(80), B = rnorm(80), C = rnorm(80))
fit <- graphical_var(d, vars = c("A", "B", "C"), id = "id", n_lambda = 8)
edges(fit)            # tidy: network / from / to / weight
#> [1] network from    to      weight 
#> <0 rows> (or 0-length row.names)
# }
```
