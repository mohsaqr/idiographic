# Print method for net_mlvar

Print method for net_mlvar

## Usage

``` r
# S3 method for class 'net_mlvar'
print(x, digits = 2, ...)
```

## Arguments

- x:

  A `net_mlvar` object returned by
  [`fit_mlvar()`](https://pak.dynasite.org/idiographic/reference/fit_mlvar.md).

- digits:

  Number of digits used for printed network matrices.

- ...:

  Unused; present for S3 consistency.

## Value

Invisibly returns `x`.

## Examples

``` r
# \donttest{
# Temporal, contemporaneous and between-person networks of 36 learners.
fit <- fit_mlvar(srl, vars = c("efficacy", "planning", "effort"),
                 id = "name", beep = "day")
print(fit)
#> mlVAR result: 36 subjects, 5560 observations, 3 variables (lags 1)
#>   Temporal edges significant at p<0.05: 1 / 9
#> 
#>   Temporal [directed]
#>     weights [-0.043, 0.018]  |  +7 / -2 edges
#>              efficacy planning effort
#>     efficacy    -0.04     0.02   0.01
#>     planning     0.00     0.00  -0.01
#>     effort       0.01     0.01   0.02
#> 
#>   Contemporaneous [undirected]
#>     weights [0.276, 0.316]  |  +3 / -0 edges
#>              efficacy planning effort
#>     efficacy     0.00     0.31   0.28
#>     planning     0.31     0.00   0.32
#>     effort       0.28     0.32   0.00
#> 
#>   Between [undirected]
#>     weights [0.242, 0.576]  |  +3 / -0 edges
#>              efficacy planning effort
#>     efficacy     0.00     0.58   0.43
#>     planning     0.58     0.00   0.24
#>     effort       0.43     0.24   0.00
#> 
#>   plot(x) | plot(x, layer = "temporal") | plot(x, layer = "between") 
#>   edges(x) | nodes(x) | summary(x) | coefs(x) | matrices(x)
summary(fit)
#>           network n_nodes n_edges density mean_abs_weight n_positive n_negative
#> 1        temporal       3       6       1      0.01030487          5          1
#> 2 contemporaneous       3       3       1      0.29905010          3          0
#> 3         between       3       3       1      0.41476433          3          0
coefs(fit)
#>    outcome predictor         beta         se           t           p
#> 1 efficacy  efficacy -0.043237380 0.01548000 -2.79311194 0.005220362
#> 2 efficacy  planning  0.002678248 0.01529428  0.17511435 0.860989785
#> 3 efficacy    effort  0.009946583 0.01478094  0.67293285 0.500990009
#> 4 planning  efficacy  0.018342219 0.01589811  1.15373559 0.248608586
#> 5 planning  planning  0.001165663 0.01570737  0.07421122 0.940842318
#> 6 planning    effort  0.007143440 0.01518017  0.47057699 0.637942841
#> 7   effort  efficacy  0.014571162 0.01627931  0.89507225 0.370748466
#> 8   effort  planning -0.009147594 0.01608400 -0.56873867 0.569533499
#> 9   effort    effort  0.017620258 0.01554416  1.13356133 0.256978601
#>      ci_lower    ci_upper significant
#> 1 -0.07357763 -0.01289713        TRUE
#> 2 -0.02729799  0.03265449       FALSE
#> 3 -0.01902354  0.03891670       FALSE
#> 4 -0.01281751  0.04950195       FALSE
#> 5 -0.02962022  0.03195155       FALSE
#> 6 -0.02260915  0.03689603       FALSE
#> 7 -0.01733571  0.04647803       FALSE
#> 8 -0.04067166  0.02237647       FALSE
#> 9 -0.01284573  0.04808625       FALSE
# }
```
