# 2. Ordinary VAR

``` r

library(idiographic)
data(srl)
vars <- c("efficacy", "value", "planning", "monitoring", "effort")
has_cograph <- requireNamespace("cograph", quietly = TRUE)
```

[`build_var()`](https://mohsaqr.github.io/idiographic/reference/build_var.md)
is the transparent OLS baseline: current variables are regressed on an
intercept and their lag-1 values. It uses the same lag preparation,
scaling, and within-person centering as
[`graphical_var()`](https://mohsaqr.github.io/idiographic/reference/graphical_var.md),
but applies no regularization or EBIC selection — making it the natural
reference point for the regularized methods.

## Fit one person

Pass `subject` to the estimator instead of slicing the data frame
yourself.

``` r

var_fit <- build_var(srl, vars = vars, id = "name", subject = "Grace",
                     scale = TRUE)

var_fit
#> OLS VAR Result
#>   Variables:      5 (efficacy, value, planning, monitoring, effort)
#>   Observations:   155
#>   Temporal edges: 25 / 25
#>   Contemp edges:  10 / 10
#> 
#>   Temporal [directed]
#>     weights [-0.160, 0.159]  |  +11 / -14 edges
#>                efficacy value planning monitoring effort
#>     efficacy      -0.13  0.04    -0.01      -0.04  -0.09
#>     value         -0.10  0.10     0.09      -0.12   0.13
#>     planning      -0.04 -0.11    -0.01      -0.06   0.16
#>     monitoring     0.05 -0.16    -0.03       0.00   0.00
#>     effort         0.06  0.07     0.11       0.01  -0.02
#> 
#>   Contemporaneous [undirected]
#>     weights [-0.060, 0.467]  |  +6 / -4 edges
#>                efficacy value planning monitoring effort
#>     efficacy       0.00  0.06    -0.06       0.38  -0.03
#>     value          0.06  0.00     0.11       0.10  -0.01
#>     planning      -0.06  0.11     0.00      -0.06   0.33
#>     monitoring     0.38  0.10    -0.06       0.00   0.47
#>     effort        -0.03 -0.01     0.33       0.47   0.00
#> 
#>   plot(x) | plot(x, layer = "temporal") 
#>   edges(x) | nodes(x) | summary(x) | coefs(x) | matrices(x)
```

Printing the fit *shows* both estimated networks — the directed lag-1
temporal network and the undirected contemporaneous partial-correlation
network — with their weight ranges, so you see the model without calling
another function.

## Tidy tables

Each question is one verb returning a tidy `data.frame`. Use
[`head()`](https://rdrr.io/r/utils/head.html) when you only want the
strongest edges; never index the result with brackets.

``` r

head(edges(var_fit))
#>    network       from         to     weight
#> 1 temporal monitoring      value -0.1604470
#> 2 temporal   planning     effort  0.1591502
#> 3 temporal      value     effort  0.1346800
#> 4 temporal      value monitoring -0.1204242
#> 5 temporal   planning      value -0.1098008
#> 6 temporal     effort   planning  0.1080185

nodes(var_fit)
#>            network       node  strength out_strength in_strength         self
#> 1         temporal   efficacy 0.4379985    0.1821870   0.2558116 -0.130248472
#> 2         temporal      value 0.8318268    0.4468467   0.3849801  0.103987599
#> 3         temporal   planning 0.6027558    0.3639382   0.2388176 -0.006545312
#> 4         temporal monitoring 0.4756466    0.2470050   0.2286416  0.004077164
#> 5         temporal     effort 0.6348432    0.2515586   0.3832846 -0.024338368
#> 6  contemporaneous   efficacy 0.5314378           NA          NA  0.000000000
#> 7  contemporaneous      value 0.2755102           NA          NA  0.000000000
#> 8  contemporaneous   planning 0.5548748           NA          NA  0.000000000
#> 9  contemporaneous monitoring 1.0030222           NA          NA  0.000000000
#> 10 contemporaneous     effort 0.8430642           NA          NA  0.000000000

summary(var_fit)
#>           network n_nodes n_edges density mean_abs_weight n_positive n_negative
#> 1        temporal       5      20       1      0.07457677          9         11
#> 2 contemporaneous       5      10       1      0.16039547          6          4
```

[`coefs()`](https://mohsaqr.github.io/idiographic/reference/coefs.md)
returns the full coefficient table (every cell, including zeros), and
[`matrices()`](https://mohsaqr.github.io/idiographic/reference/matrices.md)
prints the raw estimator matrices compactly:

``` r

head(coefs(var_fit))
#>    network       from       to      weight
#> 1 temporal   efficacy efficacy -0.13024847
#> 2 temporal      value efficacy -0.10161078
#> 3 temporal   planning efficacy -0.03801165
#> 4 temporal monitoring efficacy  0.05217654
#> 5 temporal     effort efficacy  0.06401259
#> 6 temporal   efficacy    value  0.04231149

matrices(var_fit)
#> 
#> $beta
#>              [,1]   [,2]   [,3]   [,4]   [,5]   [,6]
#> efficacy   -0.004 -0.130 -0.102 -0.038  0.052  0.064
#> value       0.009  0.042  0.104 -0.110 -0.160  0.072
#> planning   -0.004 -0.009  0.090 -0.007 -0.032  0.108
#> monitoring -0.001 -0.044 -0.120 -0.057  0.004  0.007
#> effort      0.010 -0.087  0.135  0.159 -0.003 -0.024
#> 
#> $temporal
#>            efficacy  value planning monitoring effort
#> efficacy     -0.130 -0.102   -0.038      0.052  0.064
#> value         0.042  0.104   -0.110     -0.160  0.072
#> planning     -0.009  0.090   -0.007     -0.032  0.108
#> monitoring   -0.044 -0.120   -0.057      0.004  0.007
#> effort       -0.087  0.135    0.159     -0.003 -0.024
#> 
#> $residual_cov
#>            efficacy value planning monitoring effort
#> efficacy      0.976 0.110   -0.014      0.407  0.156
#> value         0.110 0.962    0.117      0.151  0.093
#> planning     -0.014 0.117    0.984      0.108  0.330
#> monitoring    0.407 0.151    0.108      0.985  0.479
#> effort        0.156 0.093    0.330      0.479  0.938
#> 
#> $kappa
#>            efficacy  value planning monitoring effort
#> efficacy      1.249 -0.071    0.069     -0.537  0.049
#> value        -0.071  1.081   -0.120     -0.130  0.013
#> planning      0.069 -0.120    1.175      0.082 -0.455
#> monitoring   -0.537 -0.130    0.082      1.613 -0.750
#> effort        0.049  0.013   -0.455     -0.750  1.600
#> 
#> $PCC
#>            efficacy  value planning monitoring effort
#> efficacy      0.000  0.061   -0.057      0.378 -0.035
#> value         0.061  0.000    0.106      0.098 -0.010
#> planning     -0.057  0.106    0.000     -0.060  0.332
#> monitoring    0.378  0.098   -0.060      0.000  0.467
#> effort       -0.035 -0.010    0.332      0.467  0.000
#> 
#> $PDC
#>            efficacy  value planning monitoring effort
#> efficacy     -0.117  0.039   -0.008     -0.040 -0.080
#> value        -0.098  0.101    0.087     -0.116  0.133
#> planning     -0.035 -0.103   -0.006     -0.053  0.150
#> monitoring    0.042 -0.128   -0.025      0.003 -0.002
#> effort        0.051  0.058    0.086      0.006 -0.020
```

## Plot

[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws the whole
result; pass `layer` to draw a single network.

``` r

plot(var_fit)
```

![](ordinary-var_files/figure-html/plot-var-1.png)

``` r

plot(var_fit, layer = "temporal")
```

![](ordinary-var_files/figure-html/plot-var-temporal-1.png)

``` r

plot(var_fit, layer = "contemporaneous")
```

![](ordinary-var_files/figure-html/plot-var-contemp-1.png)
