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
