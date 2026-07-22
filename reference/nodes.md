# Tidy per-node strength table for any idiographic result

One row per node per network with `strength` (sum of absolute incident
edge weights) and, for directed networks, `out_strength` / `in_strength`
(`NA` for undirected). Self-loops are excluded.

## Usage

``` r
# S3 method for class 'net_usem'
nodes(x, ...)

# S3 method for class 'var_result'
nodes(x, ...)

nodes(x, ...)

# S3 method for class 'netobject'
nodes(x, ...)

# S3 method for class 'netobject_group'
nodes(x, ...)

# S3 method for class 'gvar_result'
nodes(x, ...)

# S3 method for class 'net_mlvar'
nodes(x, ...)

# S3 method for class 'net_gimme'
nodes(x, ...)

# S3 method for class 'var_list'
nodes(x, ...)

# S3 method for class 'gvar_list'
nodes(x, ...)
```

## Arguments

- x:

  A `gvar_result`, `net_mlvar`, `net_gimme`, `netobject`, or
  `netobject_group`.

- ...:

  Passed to methods.

## Value

A tidy `data.frame`.

## Examples

``` r
W <- matrix(c(0, 0.3, -0.2, 0), 2, 2,
            dimnames = list(c("A", "B"), c("A", "B")))
x <- structure(list(weights = W, method = "relative", directed = TRUE),
               class = "cograph_network")
nodes(as_netobject(x))
#>    network node strength out_strength in_strength self
#> A relative    A      0.5          0.2         0.3    0
#> B relative    B      0.5          0.3         0.2    0
```
