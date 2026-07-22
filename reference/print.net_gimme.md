# Print Method for net_gimme

Print Method for net_gimme

## Usage

``` r
# S3 method for class 'net_gimme'
print(x, digits = 2, ...)
```

## Arguments

- x:

  A `net_gimme` object.

- digits:

  Number of digits used for printed network matrices.

- ...:

  Additional arguments (ignored).

## Value

The input object, invisibly.

## Examples

``` r
# \donttest{
set.seed(1)
panel <- data.frame(
  id = rep(1:5, each = 20),
  t  = rep(seq_len(20), 5),
  A  = rnorm(100), B = rnorm(100), C = rnorm(100)
)
gm <- fit_gimme(panel, vars = c("A","B","C"), id = "id", time = "t")
print(gm)
#> GIMME Network Analysis
#> ------------------------------ 
#> Subjects:   5 
#> Variables:  3  ( A, B, C )
#> AR paths:   yes 
#> Hybrid:     no 
#> 
#> Group-level paths found: 0 
#> 
#> Individual-level paths:  mean 1.0, range 0-2
#> 
#> Proportion of subjects with each path:
#> 
#>   Temporal [directed]
#>     weights [0.200, 1.000]  |  +6 / -0 edges
#>         A   B C
#>     A 1.0 0.0 0
#>     B 0.2 1.0 0
#>     C 0.2 0.2 1
#> 
#>   Contemporaneous [directed]
#>     weights [0.200, 0.200]  |  +2 / -0 edges
#>       A B   C
#>     A 0 0 0.2
#>     B 0 0 0.2
#>     C 0 0 0.0
#> 
#>   plot(x)  (faithful gimme-style mixed network) | plot(x, layer = "temporal") 
#>   edges(x) | nodes(x) | summary(x) | coefs(x) | matrices(x)
# }
```
