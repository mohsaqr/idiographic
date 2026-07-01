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
```

## Arguments

- x:

  A `gvar_result`, `net_mlvar`, `net_gimme`, `netobject`, or
  `netobject_group`.

- ...:

  Passed to methods.

## Value

A tidy `data.frame`.
