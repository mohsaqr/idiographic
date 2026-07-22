# Coerce to a netobject

Returns netobjects unchanged; promotes a bare `cograph_network`.

## Usage

``` r
as_netobject(x, ...)
```

## Arguments

- x:

  A `netobject` or `cograph_network`.

- ...:

  Passed to methods.

## Value

A `c("netobject", "cograph_network")` object.

## Examples

``` r
W <- matrix(c(0, 0.3, -0.2, 0), 2, 2,
            dimnames = list(c("A", "B"), c("A", "B")))
x <- structure(list(weights = W, method = "relative", directed = TRUE),
               class = "cograph_network")
as_netobject(x)
#> $data
#> NULL
#> 
#> $weights
#>     A    B
#> A 0.0 -0.2
#> B 0.3  0.0
#> 
#> $nodes
#>   id label name  x  y
#> 1  1     A    A NA NA
#> 2  2     B    B NA NA
#> 
#> $edges
#>   from to weight
#> 1    2  1    0.3
#> 2    1  2   -0.2
#> 
#> $directed
#> [1] TRUE
#> 
#> $method
#> [1] "relative"
#> 
#> $params
#> list()
#> 
#> $scaling
#> NULL
#> 
#> $threshold
#> [1] 0
#> 
#> $n_nodes
#> [1] 2
#> 
#> $n_edges
#> [1] 2
#> 
#> $level
#> NULL
#> 
#> $meta
#> $meta$source
#> [1] "idiographic"
#> 
#> $meta$layout
#> NULL
#> 
#> $meta$tna
#> $meta$tna$method
#> [1] "relative"
#> 
#> 
#> 
#> $node_groups
#> NULL
#> 
#> attr(,"class")
#> [1] "cograph_network" "netobject"       "list"           
```
