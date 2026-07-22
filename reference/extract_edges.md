# Tidy edge table from a network object

Returns a one-row-per-edge `data.frame` with node labels, for any
netobject / cograph_network (or a `gvar_result` constituent).

## Usage

``` r
extract_edges(model, sort_by = "weight", include_self = FALSE)
```

## Arguments

- model:

  A `netobject` or `cograph_network`. Multi-network results (a
  `gvar_result`, `net_mlvar`, or any `netobject_group`) hold more than
  one network, so pass a single constituent — e.g.
  `extract_edges(as_netobject(x)$temporal)`.

- sort_by:

  Either `"weight"` (descending by absolute weight) or `NULL`.

- include_self:

  Keep autoregressive self-loops? Default `FALSE`.

## Value

A `data.frame` with columns `from`, `to`, `weight`.

## Examples

``` r
W <- matrix(c(0, 0.3, -0.2, 0), 2, 2,
            dimnames = list(c("A", "B"), c("A", "B")))
x <- structure(list(weights = W, method = "relative", directed = TRUE),
               class = "cograph_network")
extract_edges(x)
#>   from to weight
#> 1    B  A    0.3
#> 2    A  B   -0.2
```
