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
gm <- build_gimme(panel, vars = c("A","B","C"), id = "id", time = "t")
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
#> Individual-level paths:  mean 0.0, range 0-0
#> 
#> Proportion of subjects with each path:
#> 
#>   Temporal [directed]
#>     weights [1.000, 1.000]  |  +3 / -0 edges
#>       A B C
#>     A 1 0 0
#>     B 0 1 0
#>     C 0 0 1
#> 
#>   Contemporaneous [directed]
#>     no non-zero edges
#>       A B C
#>     A 0 0 0
#>     B 0 0 0
#>     C 0 0 0
#> 
#>   plot(x)  (faithful gimme-style mixed network) | plot(x, layer = "temporal") 
#>   edges(x) | nodes(x) | summary(x) | coefs(x) | matrices(x)
# }
```
